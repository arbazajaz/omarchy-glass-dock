import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "DockModel.js" as DockModel

// One screen's dock. It stays mapped and only hides its contents, so switching
// to a floating workspace does not wait on a fresh layer surface. While hidden the
// mask is empty and clicks fall through to the windows below.
PanelWindow {
  id: window
  // Right-to-left languages read this window mirrored.
  Binding { target: window.contentItem; property: "LayoutMirroring.enabled"; value: Commons.I18n.rightToLeft }
  Binding { target: window.contentItem; property: "LayoutMirroring.childrenInherit"; value: true }


  property var dock: null

  readonly property string position: dock ? dock.position : "bottom"
  readonly property bool vertical: dock ? dock.vertical : false
  readonly property var monitor: Hyprland.monitorFor(screen)
  readonly property var workspace: monitor ? monitor.activeWorkspace : null
  readonly property int workspaceId: workspace ? workspace.id : -1
  // The most fullscreen window on the workspace, as Hyprland counts it: 1 is
  // maximized, and 2 or 3 fullscreen.
  readonly property int fullscreenMode: {
    var mode = 0
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      if (!toplevel.workspace || toplevel.workspace.id !== workspaceId) continue
      var ipc = toplevel.lastIpcObject
      mode = Math.max(mode, ipc && ipc.fullscreen ? ipc.fullscreen : 0)
    }
    return mode
  }
  readonly property bool shown: !!dock && workspaceId > 0 && (position === "bottom" || dock.isFloating(workspaceId))
  readonly property bool fullscreen: fullscreenMode >= 2
  readonly property bool autohide: !!dock && (fullscreen ? dock.fullscreenAutohide : dock.autohide)
  property bool revealed: false
  readonly property bool menuOpen: menuItem !== null || settingsMenu
  readonly property bool tucked: autohide && !(revealed || menuOpen || dragging || insertIndex >= 0)
  readonly property bool contentShown: shown && !tucked

  readonly property int gap: Style.space(12)
  readonly property int edgePadding: Style.space(8)
  readonly property int sideMargin: Math.max(Style.space(10), Math.min(Style.space(36), Math.round(width * 0.026)))
  readonly property int magnificationRoom: Style.space(16)
  readonly property int slotCount: dock ? dock.itemModel.count + 1 : 1
  readonly property int availableLength: vertical ? height : width
  readonly property int dockDepth: Style.space(dock ? dock.dockHeight : 66)
  readonly property int requestedIcon: Style.space(dock ? dock.iconPixels : 48)
  readonly property int slotSize: Math.min(requestedIcon + Style.space(dock ? dock.iconSpacing : 16),
    Math.max(1, Math.floor((availableLength - 2 * (edgePadding + (vertical ? gap : sideMargin + magnificationRoom))) / slotCount)))
  readonly property int iconSize: Math.max(1, Math.min(requestedIcon, dockDepth - Style.space(10), slotSize - Style.space(3)))
  readonly property int iconInset: Math.round((dockDepth - iconSize) / 2)
  readonly property int hoverRoom: Math.ceil(iconSize * (dock ? dock.hoverScale / 100 : 0.40))
  readonly property real idleOpacity: 0.88
  readonly property string layerNamespace: dock && dock.blur === "off" ? "omarchy-dock-plain" : "omarchy-dock"
  property bool changingNamespace: false
  readonly property var glassPalettes: ({
    liquid: ["#c4e2ff", "#597ca1", "#243552", "#e2f4ff"],
    midnight: ["#343844", "#161820", "#06070b", "#777e90"],
    native: ["#98603b", "#392621", "#181315", "#ffab64"],
    aurora: ["#73efd1", "#655dc3", "#45285f", "#c4fff1"],
    neon: ["#375b81", "#2e2148", "#100e1c", "#8deaff"],
    "frosted-dark": ["#70809b", "#373f55", "#191e2b", "#bccce6"],
    frosted: ["#d2e1f8", "#8598b3", "#536782", "#edf6ff"],
    graphite: ["#545d71", "#303645", "#141824", "#b1bad0"],
    light: ["#f6faff", "#c5d8ee", "#9eafcb", "#ffffff"],
    gradient: ["#a0befe", "#7262a8", "#283e67", "#e0d5ff"],
    minimal: ["#b4c9ec", "#5a6d8a", "#233448", "#b9cee8"],
    clear: ["#d3edff", "#6886a8", "#344d6a", "#eef9ff"]
  })
  readonly property string glassStyle: dock ? dock.dockStyle : "liquid"
  readonly property var glassColors: {
    var palette = glassPalettes[glassStyle] || glassPalettes.native
    if (glassStyle === "wallpaper" && dock && dock.wallpaperColors.length) {
      var colors = dock.wallpaperColors
      var accent = colors[Math.floor(colors.length * 0.75)]
      var mid = colors[Math.floor(colors.length * 0.45)]
      palette = [Qt.lighter(accent, 1.2), Qt.darker(mid, 1.45), Qt.darker(colors[0], 1.28), Qt.lighter(accent, 1.45)]
    }
    if (dock && dock.backgroundColor) {
      var base = dock.backgroundColor
      return [Qt.lighter(base, 1.42), base, Qt.darker(base, 1.65), palette[3]]
    }
    return palette
  }
  readonly property real glassAlpha: (dock ? dock.glassOpacity : 64) / 100
    * (glassStyle === "minimal" ? 0.22 : glassStyle === "clear" ? 0.70 : 1)

  function motion(ms) {
    return Style.duration(Math.round(ms * 100 / (dock ? dock.animationSpeed : 100)))
  }

  function magnification(slot) {
    if (!bodyHover.hovered || hoverStale || dragging || menuOpen || insertIndex >= 0) return 1
    var pointer = vertical ? bodyHover.point.position.y : bodyHover.point.position.x
    var center = slots[vertical ? "y" : "x"] + (vertical ? slot.y : slot.x) + slotSize / 2
    var weight = Math.max(0, 1 - Math.abs(pointer - center) / (slotSize * 1.5))
    return 1 + (dock ? dock.hoverScale / 100 : 0.40) * weight * weight
  }

  // Reserve space inward for the dock settings menu.
  readonly property int popupRoom: Style.space(530) + gap * 2
  // Icons pop away from the screen edge.
  readonly property int popOrigin: position === "top" ? Item.Top
    : position === "left" ? Item.Left
    : position === "right" ? Item.Right
    : Item.Bottom

  // The app being dragged along the dock, how far the pointer has taken it,
  // and the slot it would land in.
  property int dragIndex: -1
  property int dropIndex: -1
  property real dragOffset: 0
  readonly property bool dragging: dragIndex >= 0
  // Off while a drop resets the slots: they snap to where the reorder puts
  // them rather than sliding back from where they stepped aside. Set before
  // the drag state changes, so the slots never see the reset animated.
  property bool animateShifts: true
  // After a drop the slots have moved under a pointer that has not, so what
  // they think is hovered is stale until it moves again.
  property bool hoverStale: false
  property point dropPoint
  // Where an app dragged in from the app grid would land, or -1.
  property int insertIndex: -1

  // Where this window sits on its screen, which a point from the app grid's
  // fullscreen surface is given in: against its edge, clear of the space
  // other surfaces such as the bar reserve. Hyprland lists that space as
  // left, top, right, bottom.
  function origin() {
    var reserved = monitor && monitor.lastIpcObject && monitor.lastIpcObject.reserved ? monitor.lastIpcObject.reserved : [0, 0, 0, 0]
    var left = reserved[0] || 0, top = reserved[1] || 0, right = reserved[2] || 0, bottom = reserved[3] || 0
    var x = window.position === "right" ? screen.width - right - window.width : left
    var y = window.position === "bottom" ? screen.height - bottom - window.height : top
    return Qt.point(x, y)
  }

  // An app from the app grid lands where the pointer is, once it is over the
  // dock or close to it on the inward side.
  function moveExternalDrag(screenX, screenY) {
    var at = window.origin()
    var point = Qt.point(screenX - at.x - body.x, screenY - at.y - body.y)
    var reach = window.slotSize
    var along = window.vertical ? point.y : point.x
    var across = window.vertical ? point.x : point.y
    var length = window.vertical ? body.height : body.width
    var depth = window.vertical ? body.width : body.height
    var near = along >= -window.slotSize && along <= length + window.slotSize && across >= -reach && across <= depth + reach
    if (window.shown && window.autohide && near) window.revealed = true
    window.insertIndex = window.shown && near ? window.slotIndexAt(point) : -1
  }

  function dropExternalDrag(screenX, screenY, key) {
    window.moveExternalDrag(screenX, screenY)
    window.settleShifts()
    if (window.insertIndex >= 0 && key && window.dock) window.dock.pinAt(key, window.insertIndex)
    window.endExternalDrag()
  }

  function endExternalDrag() {
    window.insertIndex = -1
    if (window.autohide) hideTimer.restart()
  }

  // The slot a point along the dock falls before, counting from the first app.
  function slotIndexAt(point) {
    var along = window.vertical ? point.y : point.x
    var first = window.slotSize + window.edgePadding
    var count = window.dock ? window.dock.itemModel.count : 0
    return Math.max(0, Math.min(count, Math.round((along - first) / window.slotSize)))
  }
  property var menuItem: null
  property Item menuSlot: null
  // The apps button's menu: where the dock sits and whether it hides.
  property bool settingsMenu: false

  onShownChanged: {
    if (shown) return
    closeMenu()
    window.revealed = false
  }
  Component.onCompleted: if (dock) dock.readMode(workspaceId)

  function openMenu(item, slot) {
    window.settingsMenu = false
    window.menuItem = item
    window.menuSlot = slot
  }

  function openDockSettings() {
    if (shown) openSettingsMenu(appsButton)
  }

  function openSettingsMenu(slot) {
    window.menuItem = null
    window.settingsMenu = true
    window.menuSlot = slot
  }

  function settleShifts() {
    window.animateShifts = false
    Qt.callLater(function() { window.animateShifts = true })
  }

  function endDrag() {
    window.settleShifts()
    window.hoverStale = true
    window.dragIndex = -1
    window.dropIndex = -1
    window.dragOffset = 0
  }

  function closeMenu() {
    window.menuItem = null
    window.settingsMenu = false
    window.menuSlot = null
    if (window.autohide) hideTimer.restart()
  }

  // Places the menu inward of the dock, centered on a slot.
  function popupX(slot, popup) {
    if (!slot) return 0
    var center = slot.mapToItem(window.contentItem, slot.width / 2, 0).x
    if (window.position === "left") return body.x + body.width + window.gap
    if (window.position === "right") return body.x - window.gap - popup.width
    return Math.max(window.gap, Math.min(window.width - popup.width - window.gap, center - popup.width / 2))
  }

  function popupY(slot, popup) {
    if (!slot) return 0
    var center = slot.mapToItem(window.contentItem, 0, slot.height / 2).y
    if (window.position === "top") return body.y + body.height + window.gap
    if (window.position === "bottom") return Math.max(0, body.y - window.gap - popup.height)
    return Math.max(window.gap, Math.min(window.height - popup.height - window.gap, center - popup.height / 2))
  }

  visible: !remapGuard.remapping && !changingNamespace
  color: "transparent"
  WlrLayershell.namespace: layerNamespace
  WlrLayershell.layer: fullscreen ? WlrLayer.Overlay : WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  // The visible dock reserves its edge from tiled and maximized windows.
  // True fullscreen retains the complete output even when the dock is revealed.
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: contentShown && !fullscreen ? dockDepth + gap + hoverRoom : 0

  anchors {
    top: window.position !== "bottom"
    bottom: window.position !== "top"
    left: window.position !== "right"
    right: window.position !== "left"
  }

  implicitWidth: window.vertical ? window.gap + window.dockDepth + window.hoverRoom + window.popupRoom : 0
  implicitHeight: window.vertical ? 0 : window.gap + window.dockDepth + window.hoverRoom + window.popupRoom

  mask: Region {
    item: window.contentShown ? body : null

    Region { item: window.shown && window.autohide ? edgeTrigger : null }
    Region { item: window.contentShown && window.autohide ? edgeBridge : null }
    Region { item: menu.visible ? menu : null }
  }

  function resetReveal() {
    revealTimer.stop()
    hideTimer.stop()
    revealed = false
  }

  function maybeHide() {
    if (autohide && revealed) hideTimer.restart()
  }

  onAutohideChanged: resetReveal()
  onFullscreenChanged: {
    closeMenu()
    resetReveal()
  }
  onWorkspaceIdChanged: {
    if (dock) dock.readMode(workspaceId)
    closeMenu()
    resetReveal()
  }
  onLayerNamespaceChanged: {
    changingNamespace = true
    namespaceRemap.restart()
  }

  Timer { id: namespaceRemap; interval: 65; onTriggered: window.changingNamespace = false }

  Timer {
    id: revealTimer
    interval: 140
    onTriggered: {
      if (window.shown && window.autohide && edgeHover.hovered) window.revealed = true
    }
  }

  Timer {
    id: hideTimer
    interval: window.dock ? window.dock.hideDelay : 280
    onTriggered: {
      if (!bodyHover.hovered && !edgeHover.hovered && !bridgeHover.hovered
          && !window.menuOpen && !window.dragging) window.revealed = false
    }
  }

  Item {
    id: edgeTrigger
    readonly property int depth: 2
    readonly property int length: Math.min(window.vertical ? body.height : body.width, Style.space(520))
    x: window.position === "left" ? 0 : window.position === "right" ? window.width - depth
      : Math.floor((window.width - width) / 2)
    y: window.position === "top" ? 0 : window.position === "bottom" ? window.height - depth
      : Math.floor((window.height - height) / 2)
    width: window.vertical ? depth : length
    height: window.vertical ? length : depth

    HoverHandler {
      id: edgeHover
      onHoveredChanged: {
        if (hovered && !window.revealed) revealTimer.restart()
        else if (!hovered) {
          revealTimer.stop()
          window.maybeHide()
        }
      }
    }
  }

  // Connect the edge to the moving dock without making the glass wings clickable.
  Item {
    id: edgeBridge
    x: window.vertical ? Math.min(edgeTrigger.x, body.x + body.width) : edgeTrigger.x
    y: window.vertical ? edgeTrigger.y : Math.min(edgeTrigger.y, body.y + body.height)
    width: window.vertical
      ? Math.max(0, (window.position === "left" ? body.x : window.width - body.x - body.width))
      : edgeTrigger.width
    height: window.vertical ? edgeTrigger.height
      : Math.max(0, (window.position === "top" ? body.y : window.height - body.y - body.height))

    HoverHandler {
      id: bridgeHover
      onHoveredChanged: if (!hovered) window.maybeHide()
    }
  }

  ScreenMoveRemap {
    id: remapGuard
    window: window
  }

  HyprlandFocusGrab {
    active: window.menuOpen
    windows: [window]
    onCleared: window.closeMenu()
  }

  Item {
    id: body

    // The strip keeps its order in every language, like the bar: drags and
    // drops reckon slots along x from the first app. Only the menu mirrors.
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    width: window.vertical ? window.dockDepth : slots.implicitWidth + window.edgePadding * 2
    height: window.vertical ? slots.implicitHeight + window.edgePadding * 2 : window.dockDepth
    // How far the dock is tucked past its edge. Auto-hide slides it, but only
    // while the dock is on screen: arriving on a floating workspace shows it
    // where it belongs at once.
    property real tuck: window.tucked ? window.dockDepth + window.gap + Style.space(8) : 0

    // Tucking away is quicker than coming back. A gentler curve than
    // Style.easeOut, which crosses the short slide in a frame or two.
    Behavior on tuck {
      id: tuckMotion
      enabled: window.shown
      NumberAnimation {
        duration: window.motion(tuckMotion.targetValue > 0 ? 145 : 210)
        easing.type: Easing.OutCubic
      }
    }

    x: window.position === "left" ? window.gap - tuck
      : window.position === "right" ? window.width - width - window.gap + tuck
      : Math.round((window.width - width) / 2)
    y: window.position === "top" ? window.gap - tuck
      : window.position === "bottom" ? window.height - height - window.gap + tuck
      : Math.round((window.height - height) / 2)
    opacity: window.contentShown ? 1 : 0
    Behavior on opacity {
      NumberAnimation { duration: window.motion(window.contentShown ? 195 : 125); easing.type: Easing.OutCubic }
    }

    HoverHandler {
      id: bodyHover
      onHoveredChanged: if (!hovered) window.maybeHide()
      // Only a real move clears it: the release itself reports the pointer too.
      onPointChanged: {
        if (!window.hoverStale || window.dragging) return
        var at = point.position
        if (Math.hypot(at.x - window.dropPoint.x, at.y - window.dropPoint.y) > Style.space(4)) window.hoverStale = false
      }
    }

    Repeater {
      model: 6

      delegate: Rectangle {
        required property int index
        x: glass.x - index
        y: 2 - index
        width: glass.width + index * 2
        height: body.height + index * 2
        radius: glass.radius + index
        color: Qt.rgba(0.02, 0.03, 0.07, (0.055 - index * 0.006) * Math.min(1, window.glassAlpha * 2) * (window.dock ? window.dock.dockShadow / 55 : 1))
      }
    }

    Rectangle {
      id: glass
      anchors.centerIn: parent
      width: window.vertical || !window.dock || window.dock.dockWidth === "fit" ? body.width
        : Math.max(body.width, Math.round((window.width - 2 * window.sideMargin) * window.dock.dockWidth / 100))
      Behavior on width {
        NumberAnimation { duration: Style.duration(175); easing.type: Easing.OutCubic }
      }
      height: body.height
      radius: Math.min(height / 2, Style.space(window.dock ? window.dock.cornerRadius : 22))
      border.width: 1
      border.color: Util.alpha(window.glassColors[3], Math.min(0.92, window.glassAlpha + 0.18))
      gradient: Gradient {
        GradientStop { position: 0; color: Util.alpha(window.glassColors[0], window.glassAlpha * 0.82) }
        GradientStop { position: 0.47; color: Util.alpha(window.glassColors[1], window.glassAlpha * (window.dock && window.dock.blur === "strong" ? 0.78 : 0.44)) }
        GradientStop { position: 1; color: Util.alpha(window.glassColors[2], window.glassAlpha * 0.88) }
      }

      Rectangle {
        visible: ["liquid", "gradient", "aurora", "wallpaper"].includes(window.glassStyle)
        x: parent.radius
        y: 2
        width: Math.max(0, parent.width - parent.radius * 2)
        height: 1
        color: Qt.rgba(1, 1, 1, window.glassAlpha * 0.72)
      }

      Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Math.max(0, parent.radius - 2)
        color: "transparent"
        border.width: 1
        border.color: "#22ffffff"
      }
    }

    Grid {
      id: slots
      anchors.centerIn: parent
      columns: window.vertical ? 1 : appRepeater.count + 1

      AppsSlot { id: appsButton }

      Repeater {
        id: appRepeater
        model: window.dock ? window.dock.itemModel : null

        delegate: AppSlot {}
      }
    }
  }

  component Slot: Item {
    id: slot

    property alias mouse: mouse

    width: window.vertical ? window.dockDepth : window.slotSize
    height: window.vertical ? window.slotSize : window.dockDepth

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    }
  }

  component AppsSlot: Slot {
    id: appsSlot

    property real displayedShift: window.insertIndex >= 0 ? -window.slotSize / 2 : 0

    Behavior on displayedShift {
      enabled: window.animateShifts
      NumberAnimation { duration: Style.duration(150); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
    }

    transform: Translate {
      x: window.vertical ? 0 : appsSlot.displayedShift
      y: window.vertical ? appsSlot.displayedShift : 0
    }

    mouse.onClicked: function(event) {
      if (event.button === Qt.RightButton) {
        window.openSettingsMenu(appsSlot)
        return
      }
      window.closeMenu()
      if (window.dock) window.dock.openApps()
    }

    z: appsSlot.mouse.containsMouse ? 1 : 0

    IconGlow {
      anchors.centerIn: parent
      scale: window.magnification(parent)
    }

    DockIcon {
      anchors.centerIn: parent
      width: window.iconSize
      height: width
      launcher: true
      scale: window.magnification(appsSlot)
      transformOrigin: window.popOrigin
      Behavior on scale { NumberAnimation { duration: window.motion(130); easing.type: Easing.OutCubic } }
    }
  }

  component AppSlot: Slot {
    id: appSlot

    required property int index
    required property string key
    readonly property var modelData: window.dock ? window.dock.itemFor(key) : null
    readonly property bool launching: !!window.dock && window.dock.isLaunching(key)
    readonly property bool lifted: window.dragIndex === index
    property point pressPoint
    property bool dragged: false
    readonly property int windowCount: modelData ? modelData.windows.length : 0
    property real pulse: 1

    // Slots between where the dragged app was and where it would land step
    // aside to make room; the dragged one follows the pointer.
    readonly property real shift: window.insertIndex >= 0 ? (index >= window.insertIndex ? 1 : -1) * window.slotSize / 2
      : !window.dragging ? 0
      : lifted ? window.dragOffset
      : (window.dragIndex < index && index <= window.dropIndex) ? -window.slotSize
      : (window.dropIndex <= index && index < window.dragIndex) ? window.slotSize
      : 0
    property real displayedShift: shift

    // Only while dragging: once the drop reorders the slots, they are already
    // where they were shown.
    Behavior on displayedShift {
      enabled: window.animateShifts && ((window.dragging && !appSlot.lifted) || window.insertIndex >= 0)
      NumberAnimation { duration: Style.duration(150); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
    }

    z: lifted ? 2 : mouse.containsMouse ? 1 : 0

    // The slot, and the pointer handling in it, stays where it is; only the
    // icon moves. Reading the pointer through a slot that moves with it would
    // feed each move back into the next.
    function bodyPoint(event) {
      return appSlot.mapToItem(body, event.x, event.y)
    }

    mouse.onPressed: function(event) {
      appSlot.dragged = false
      if (event.button === Qt.LeftButton) appSlot.pressPoint = appSlot.bodyPoint(event)
    }

    mouse.onPositionChanged: function(event) {
      if (!(appSlot.mouse.pressedButtons & Qt.LeftButton)) return
      var point = appSlot.bodyPoint(event)
      var delta = window.vertical ? point.y - appSlot.pressPoint.y : point.x - appSlot.pressPoint.x
      // A press that wanders is a drag in the making, not a click.
      if (Math.hypot(point.x - appSlot.pressPoint.x, point.y - appSlot.pressPoint.y) > Style.space(4)) appSlot.dragged = true
      if (!window.dragging) {
        if (Math.abs(delta) < Style.space(6)) return
        window.closeMenu()
        // The landing slot first: with the dragged slot set and no landing
        // slot yet, every slot before it would count as in between and step
        // aside for a moment.
        window.dropIndex = appSlot.index
        window.dragIndex = appSlot.index
      }
      if (!appSlot.lifted) return
      window.dragOffset = delta
      window.dropIndex = DockModel.dropIndex(appSlot.index, delta, window.slotSize, appRepeater.count)
    }

    mouse.onReleased: function(event) {
      if (!appSlot.lifted) return
      window.dropPoint = appSlot.mapToItem(body, event.x, event.y)
      var from = window.dragIndex
      var to = window.dropIndex
      appSlot.dragged = true
      window.endDrag()
      window.dock.moveItem(from, to)
    }

    mouse.onCanceled: if (appSlot.lifted) window.endDrag()

    mouse.onClicked: function(event) {
      // A drag ends in a release over the app, which is not a click on it.
      if (appSlot.dragged) {
        appSlot.dragged = false
        return
      }
      if (event.button === Qt.RightButton) {
        window.openMenu(appSlot.modelData, appSlot)
        return
      }
      window.closeMenu()
      if (event.button === Qt.MiddleButton) window.dock.launch(appSlot.modelData)
      else window.dock.activate(appSlot.modelData)
    }

    IconGlow {
      anchors.centerIn: parent
      visible: !window.dragging && window.insertIndex < 0
      scale: window.magnification(appSlot)
    }

    DockIcon {
      anchors.centerIn: parent
      width: window.iconSize
      height: width
      appId: appSlot.key
      source: window.dock && appSlot.modelData ? window.dock.iconFor(appSlot.modelData) : ""
      opacity: appSlot.launching ? appSlot.pulse : 1
      transform: Translate {
        x: window.vertical ? 0 : appSlot.displayedShift
        y: window.vertical ? appSlot.displayedShift : 0
      }
      scale: appSlot.lifted ? 1.16 : window.magnification(appSlot)
      transformOrigin: window.popOrigin

      Behavior on scale { NumberAnimation { duration: window.motion(130); easing.type: Easing.OutCubic } }
    }

    Rectangle {
      opacity: appSlot.launching ? appSlot.pulse : appSlot.windowCount > 0 ? 1 : 0
      scale: opacity > 0 ? 1 : 0.75
      Behavior on opacity { NumberAnimation { duration: window.motion(150); easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: window.motion(150); easing.type: Easing.OutCubic } }
      width: Math.max(2, Math.min(Style.space(5), Math.round(window.iconSize * 0.12)))
      height: width
      radius: width / 2
      color: "#e9f2ff"
      x: window.position === "left" ? window.iconInset / 2 - width / 2
        : window.position === "right" ? parent.width - (window.iconInset + width) / 2
        : (parent.width - width) / 2
      y: window.position === "top" ? window.iconInset / 2 - height / 2
        : window.position === "bottom" ? parent.height - (window.iconInset + height) / 2
        : (parent.height - height) / 2
      transform: Translate {
        x: window.vertical ? 0 : appSlot.displayedShift
        y: window.vertical ? appSlot.displayedShift : 0
      }
    }

    // With animations off it holds still rather than spinning through
    // zero-length steps.
    SequentialAnimation {
      running: appSlot.launching && !Style.reduceMotion
      loops: Animation.Infinite
      onRunningChanged: if (!running) appSlot.pulse = 1

      NumberAnimation { target: appSlot; property: "pulse"; from: 1; to: window.idleOpacity; duration: Style.duration(500); easing.type: Easing.InOutSine }
      NumberAnimation { target: appSlot; property: "pulse"; to: 1; duration: Style.duration(500); easing.type: Easing.InOutSine }
    }
  }

  BorderSurface {
    id: menu

    readonly property var item: window.menuItem
    readonly property bool hasEntry: !!item && !!window.dock && !!window.dock.entryFor(item)
    readonly property bool running: !!item && item.windows.length > 0

    visible: window.contentShown && (!!item || window.settingsMenu)
    width: (window.settingsMenu ? Style.space(358) : Math.max(Style.space(140), menuColumn.implicitWidth)) + padding * 2
    height: menuColumn.implicitHeight + padding * 2
    x: window.popupX(window.menuSlot, menu)
    y: window.popupY(window.menuSlot, menu)
    radius: Style.cornerRadius
    color: Commons.Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)
    padding: Style.spacing.sm

    Column {
      id: menuColumn
      x: menu.contentLeftInset
      y: menu.contentTopInset
      width: menu.width - menu.contentLeftInset - menu.contentRightInset

      DockSettings {
        visible: window.settingsMenu
        width: parent.width
        height: visible ? implicitHeight : 0
        dock: window.dock
        onPositionChangedByUser: window.closeMenu()
      }

      MenuRow {
        visible: menu.hasEntry && menu.running
        text: Commons.I18n.t("dock.newWindow")
        onTriggered: window.dock.launch(menu.item)
      }

      MenuRow {
        visible: menu.hasEntry
        text: menu.item && menu.item.pinned ? Commons.I18n.t("dock.removeFromDock") : Commons.I18n.t("dock.keepInDock")
        onTriggered: window.dock.setPinned(menu.item.key, !menu.item.pinned)
      }

      MenuRow {
        visible: menu.running
        text: Commons.I18n.t("dock.quit")
        onTriggered: window.dock.quit(menu.item)
      }
    }
  }

  component IconGlow: Item {
    width: window.iconSize
    height: width
    opacity: window.dock ? window.dock.dockGlow / 100 : 0

    Repeater {
      model: 3
      delegate: Rectangle {
        required property int index
        anchors.centerIn: parent
        width: parent.width + Style.space((index + 1) * 4)
        height: width
        radius: width * 0.28
        color: Util.alpha(window.glassColors[3], 0.21 - index * 0.045)
      }
    }
  }

  component MenuRow: Rectangle {
    id: row

    property string text: ""
    property bool checked: false
    property bool keepOpen: false
    signal triggered()

    width: parent ? parent.width : 0
    height: visible ? Style.spacing.popupRowHeight : 0
    radius: Style.cornerRadius
    color: rowMouse.containsMouse ? Style.hoverFill : "transparent"

    Text {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.controlPaddingX
      textFormat: Text.PlainText
      text: row.text
      color: Commons.Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    Text {
      visible: row.checked
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.controlPaddingX
      textFormat: Text.PlainText
      text: "✓"
      color: Commons.Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        row.triggered()
        if (!row.keepOpen) window.closeMenu()
      }
    }
  }
}
