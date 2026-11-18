import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "DockModel.js" as DockModel

OverlayWindow {
  id: overview

  required property var dock
  readonly property var spaceHost: overview
  property int selectedIndex: 0
  property var selectedWorkspace: null
  property bool closing: false
  readonly property var wallpaperPath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
    + "/omarchy/current/background"
  readonly property var windows: Hyprland.toplevels.values.filter(function(window) {
    return window.wayland && window.workspace
  }).sort(function(a, b) {
    var left = a.workspace.id < 0 ? Number.MAX_SAFE_INTEGER : a.workspace.id
    var right = b.workspace.id < 0 ? Number.MAX_SAFE_INTEGER : b.workspace.id
    return left - right
  })
  property var numberedSlots: []
  property bool addingSpace: false
  property var removal: null
  property var dragWindow: null
  property var dragSource: null
  property var dragDestination: null
  property point dragPoint
  readonly property var activeWorkspaceId: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
    ? Hyprland.focusedMonitor.activeWorkspace.id : null
  readonly property string wallpaperUrl: shown ? Util.fileUrl(wallpaperPath) : ""
  readonly property color accent: dock && dock.backgroundColor ? Qt.lighter(dock.backgroundColor, 2)
    : dock && dock.dockStyle === "native" ? "#ffab64" : dock && dock.dockStyle === "aurora" ? "#8df3d9" : "#a4caff"

  readonly property var workspaceGroups: {
    var byId = new Map()
    for (var i = 0; i < numberedSlots.length; i++) {
      var id = numberedSlots[i]
      byId.set(id, { id: id, name: String(id), workspace: null, windows: [] })
    }
    var workspaces = Hyprland.workspaces.values
    for (var j = 0; j < workspaces.length; j++) {
      var workspace = workspaces[j]
      if (workspace.name.indexOf("special:") === 0) continue
      byId.set(workspace.id, { id: workspace.id, name: workspace.name, workspace: workspace, windows: [] })
    }
    for (var k = 0; k < windows.length; k++) {
      var group = byId.get(windows[k].workspace.id)
      if (group) group.windows.push(windows[k])
    }
    return Array.from(byId.values()).sort(function(a, b) {
      if (a.id > 0 && b.id < 0) return -1
      if (a.id < 0 && b.id > 0) return 1
      return a.id < 0 ? b.id - a.id : a.id - b.id
    })
  }

  Process {
    id: slotQuery
    command: ["hyprctl", "repl", "local m=hl.get_active_monitor(); local ids={}; if m and o.workspaces then for slot=1,o.workspaces.slots do ids[slot]=o.workspaces.workspace_id(m,slot) end end; return table.concat(ids, ',')"]
    stdout: StdioCollector {
      onStreamFinished: {
        var value = text.trim()
        if (/^[0-9,]+$/.test(value)) overview.numberedSlots = value.split(",").map(Number)
      }
    }
  }

  onActiveWorkspaceIdChanged: {
    if (!shown || activeWorkspaceId === null) return
    if (selectedWorkspace !== null || addingSpace) selectWorkspace(activeWorkspaceId)
    addingSpace = false
  }

  onWorkspaceGroupsChanged: {
    if (selectedWorkspace !== null && !workspaceGroups.some(group => group.id === selectedWorkspace)) {
      selectWorkspace(null)
    }
  }

  function label(key) { return strings.t(key) }

  function ipc(expression) {
    Quickshell.execDetached(["hyprctl", "eval", expression])
    pollAfterAction.restart()
  }

  Timer {
    id: pollAfterAction
    interval: 160
    onTriggered: {
      Hyprland.refreshWorkspaces()
      Hyprland.refreshToplevels()
      overview.addingSpace = false
    }
  }

  function switchSpace(id) {
    if (!Number.isInteger(id)) return
    selectWorkspace(id)
    ipc("if o.spaces then o.spaces.focus(" + id + ") end")
  }

  function addSpace() {
    addingSpace = true
    ipc("if o.spaces then o.spaces.add() end")
  }

  function requestRemove(group) {
    var destination = workspaceGroups.find(space => space.id === activeWorkspaceId && space.id !== group.id)
      || workspaceGroups.find(space => space.id > 0 && space.id !== group.id)
    if (!destination) return
    if (group.windows.length === 0) removeSpace(group.id, destination.id)
    else removal = { source: group, destination: destination }
  }

  function removeSpace(id, destination, allowMove) {
    if (!Number.isInteger(id) || !Number.isInteger(destination)) return
    removal = null
    if (selectedWorkspace === id) selectWorkspace(destination)
    ipc("if o.spaces then o.spaces.remove(" + id + "," + destination + "," + (allowMove ? "true" : "false") + ") end")
  }

  function updateDrag(window, point) {
    if (!window || !window.workspace) return
    dragWindow = window
    dragSource = window.workspace.id
    dragPoint = point
    dragDestination = workspaceStrip.targetAt(point)
  }

  function finishDrag(drop) {
    var address = String(dragWindow ? dragWindow.address : "")
    var id = dragDestination
    if (drop && Number.isInteger(id) && id !== dragSource && /^(0x)?[0-9a-f]+$/i.test(address)) {
      if (address.indexOf("0x") !== 0) address = "0x" + address
      ipc('if o.spaces then o.spaces.move("' + address + '",' + id + ') end')
    }
    dragWindow = null
    dragSource = null
    dragDestination = null
  }

  Timer {
    interval: 65
    repeat: true
    running: !!overview.dragWindow
    onTriggered: {
      workspaceStrip.scrollDrag(overview.dragPoint)
      overview.dragDestination = workspaceStrip.targetAt(overview.dragPoint)
    }
  }

  readonly property var displayedWindows: selectedWorkspace === null ? windows
    : windows.filter(window => window.workspace.id === selectedWorkspace)
  readonly property int windowCount: displayedWindows.length
  readonly property int preferredColumns: windowCount <= 2 ? windowCount : windowCount === 4 ? 2 : 3
  readonly property int columns: Math.max(1, Math.min(preferredColumns, Math.floor(gridArea.width / Style.space(245))))
  readonly property int rows: Math.ceil(windowCount / columns)

  shownKeyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
  mask: Region { item: shown && !closing ? overview.contentItem : null }

  onWindowCountChanged: selectedIndex = Math.min(selectedIndex, Math.max(0, windowCount - 1))

  WlrLayershell.namespace: "omarchy-mission-control"

  Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  Timer {
    id: closeDelay
    interval: Style.duration(125)
    onTriggered: {
      overview.shown = false
      overview.closing = false
    }
  }

  property var closingWindow: null

  function requestWindowClose(toplevel) {
    if (!toplevel || closingWindow) return
    if (Style.reduceMotion) {
      toplevel.close()
      return
    }
    closingWindow = toplevel
    closeCardTimer.restart()
  }

  Timer {
    id: closeCardTimer
    interval: Style.duration(125)
    onTriggered: {
      if (overview.closingWindow) overview.closingWindow.close()
      closeCardReset.restart()
    }
  }

  // Allow the card to return when a window requests a save confirmation.
  Timer {
    id: closeCardReset
    interval: 350
    onTriggered: overview.closingWindow = null
  }

  function close() {
    if (!shown || closing) return
    finishDrag(false)
    removal = null
    if (Style.reduceMotion) shown = false
    else {
      closing = true
      closeDelay.restart()
    }
  }

  function fallbackAppName(toplevel) {
    var name = String(toplevel.appId || "").split(".").pop()
    return name ? name.charAt(0).toUpperCase() + name.slice(1) : toplevel.title
  }

  function workspaceLabel(workspace) {
    if (DockModel.isMinimizedWorkspace(workspace.name)) return strings.t("overview.minimized")
    if (workspace.id <= 0) {
      var match = /^Glass-Space-([0-9]+)$/.exec(workspace.name)
      return match ? strings.t("spaces.name").arg(match[1]) : workspace.name.replace(/^special:/, "")
    }
    if (workspace.name && workspace.name !== String(workspace.id)) return workspace.name
    return strings.t("overview.workspace").arg(I18n.formatNumber(workspace.id))
  }

  function selectWorkspace(workspaceId) {
    selectedWorkspace = workspaceId
    selectedIndex = 0
    grid.positionViewAtBeginning()
    panel.forceActiveFocus()
  }

  function open() {
    if (shown && !closing) return
    closeDelay.stop()
    closing = false
    selectedWorkspace = null
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
    slotQuery.running = true
    selectedIndex = 0
    shown = true
    grid.positionViewAtBeginning()
    Qt.callLater(function() { panel.forceActiveFocus() })
  }

  function activate(window) {
    if (!window || !window.wayland) return
    var address = String(window.address || "")
    var minimized = window.workspace && DockModel.isMinimizedWorkspace(window.workspace.name)
    close()
    Qt.callLater(function() {
      if (!/^(0x)?[0-9a-f]+$/i.test(address)) return
      overview.dock.bringForward({ address: address, minimized: minimized })
    })
  }

  function moveSelection(delta) {
    if (windowCount === 0) return
    selectedIndex = Math.max(0, Math.min(windowCount - 1, selectedIndex + delta))
    grid.positionViewAtIndex(selectedIndex, GridView.Contain)
  }

  Item {
    anchors.fill: parent
    opacity: overview.contentRevealed && !overview.closing ? 1 : 0
    Behavior on opacity {
      NumberAnimation { duration: Style.duration(overview.closing ? 120 : 180); easing.type: Easing.OutCubic }
    }

    Image {
      id: wallpaper
      anchors.fill: parent
      visible: false
      source: overview.wallpaperUrl
      sourceSize: Qt.size(Math.round(width * 0.6), Math.round(height * 0.6))
      fillMode: Image.PreserveAspectCrop
      cache: false
      asynchronous: true
    }

    MultiEffect {
      anchors.fill: parent
      visible: wallpaper.status === Image.Ready
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: true
      blurMax: 64
      blur: 0.88
      saturation: -0.18
    }

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0; color: "#7a17273e" }
        GradientStop { position: 0.48; color: "#91202843" }
        GradientStop { position: 1; color: "#d4131829" }
      }
    }

    MouseArea { anchors.fill: parent; onClicked: overview.close() }

    Item {
      id: panel
      readonly property var spaceOwner: overview.spaceHost
      anchors.fill: parent
      anchors.margins: Style.space(34)
      focus: true

      scale: overview.contentRevealed && !overview.closing ? 1 : 0.97
      Behavior on scale {
        NumberAnimation { duration: Style.duration(overview.closing ? 120 : 190); easing.type: Easing.OutCubic }
      }

      Keys.onEscapePressed: if (overview.removal) overview.removal = null; else overview.close()
      Keys.onLeftPressed: overview.moveSelection(-1)
      Keys.onRightPressed: overview.moveSelection(1)
      Keys.onUpPressed: overview.moveSelection(-overview.columns)
      Keys.onDownPressed: overview.moveSelection(overview.columns)
      Keys.onReturnPressed: function(event) { if (overview.removal) removalDialog.handleKey(event); else overview.activate(overview.displayedWindows[overview.selectedIndex]) }
      Keys.onEnterPressed: function(event) { if (overview.removal) removalDialog.handleKey(event); else overview.activate(overview.displayedWindows[overview.selectedIndex]) }

      SpacesStrip {
        id: workspaceStrip
        anchors.top: parent.top
        width: parent.width
        height: implicitHeight
        overview: panel.spaceOwner
      }

      Text {
        anchors.centerIn: parent
        visible: overview.windowCount === 0
        textFormat: Text.PlainText
        text: strings.t("overview.empty")
        color: "#d3ddf3"
        font.pixelSize: Style.font.heading
      }

      Item {
        id: gridArea
        anchors.top: workspaceStrip.bottom
        anchors.topMargin: Style.space(18)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(22)

        GridView {
          id: grid
          anchors.centerIn: parent
          width: cellWidth * overview.columns
          height: Math.min(parent.height, cellHeight * overview.rows)
          readonly property int previewRows: Math.min(overview.rows || 1, 2)
          readonly property int labelRoom: Style.space(46)
          cellWidth: Math.max(1, Math.floor(Math.min(parent.width / overview.columns,
            Style.space(840), (parent.height / previewRows - labelRoom - 3) / 0.60)))
          cellHeight: Math.round(cellWidth * 0.60) + labelRoom
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: overview.shown ? overview.displayedWindows : []

          delegate: Item {
            id: windowCard
            required property var modelData
            required property int index
            readonly property var toplevel: modelData.wayland
            readonly property var workspace: modelData.workspace
            readonly property bool selected: index === overview.selectedIndex
            readonly property bool minimized: !!workspace && DockModel.isMinimizedWorkspace(workspace.name)
            readonly property bool onVisibleWorkspace: {
              var monitors = Hyprland.monitors.values
              for (var i = 0; i < monitors.length; ++i) {
                if (monitors[i].activeWorkspace === workspace) return true
              }
              return false
            }
            readonly property var entry: toplevel ? overview.dock.entryForAppId(toplevel.appId) : null

            readonly property int itemsInRow: Math.min(overview.columns,
              overview.windowCount - Math.floor(index / overview.columns) * overview.columns)
            readonly property real rowOffset: (overview.columns - itemsInRow) * grid.cellWidth / 2

            width: grid.cellWidth
            height: grid.cellHeight
            z: selected ? 1 : 0

            Repeater {
              model: 4
              delegate: Rectangle {
                required property int index
                x: frame.x - index * 2
                y: frame.y + 4 - index
                width: frame.width + index * 4
                height: frame.height + index * 4
                radius: frame.radius + index * 2
                color: Qt.rgba(0.02, 0.04, 0.09, 0.20 - index * 0.038)
              }
            }

            Rectangle {
              id: frame
              x: Style.space(10) + windowCard.rowOffset
              y: Style.space(10)
              width: parent.width - Style.space(20)
              height: parent.height - Style.space(20)
              radius: Style.space(17)
              color: windowCard.selected ? "#c3445a7d" : "#a72c384e"
              border.color: windowCard.selected ? "#dbe9ff" : "#57bdccec"
              border.width: windowCard.selected ? 2 : 1
              scale: windowCard.selected ? 1.025 : 1
              Behavior on scale {
                NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic }
              }

              Item {
                id: preview
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: title.top
                anchors.margins: Style.space(10)
                clip: true

                ScreencopyView {
                  id: capture
                  anchors.centerIn: parent
                  constraintSize: Qt.size(preview.width, preview.height)
                  captureSource: overview.contentRevealed && !windowCard.minimized ? windowCard.toplevel : null
                  // Frame requests avoid holding a continuous stream open across
                  // window closes. Refresh visible desktops while the overview is up.
                  live: false
                }

                Timer {
                  interval: 850
                  repeat: true
                  running: capture.hasContent && overview.shown && windowCard.onVisibleWorkspace
                  onTriggered: capture.captureFrame()
                }

                DockIcon {
                  visible: !capture.hasContent
                  anchors.centerIn: parent
                  width: Style.space(54)
                  height: width
                  appId: windowCard.entry ? windowCard.entry.id : ""
                  source: overview.dock.appLibrary
                    ? overview.dock.appLibrary.iconSource(windowCard.entry ? windowCard.entry.icon : "")
                    : ""
                }
              }

              Text {
                id: title
                anchors.bottom: desktop.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Style.space(7)
                textFormat: Text.PlainText
                text: windowCard.entry ? windowCard.entry.name
                  : windowCard.toplevel ? overview.fallbackAppName(windowCard.toplevel) : ""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: "#f4f7ff"
                font.pixelSize: Style.font.body
              }

              Text {
                id: desktop
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: Style.space(8)
                textFormat: Text.PlainText
                text: windowCard.workspace ? overview.workspaceLabel(windowCard.workspace) : ""
                color: "#c9d6f3"
                font.pixelSize: Style.font.body - 2
              }
            }

            MouseArea {
              id: windowPointer
              anchors.fill: frame
              enabled: !windowCard.closingCard
              preventStealing: true
              property point startPoint
              property bool moved: false
              onPressed: function(event) {
                moved = false
                startPoint = Qt.point(event.x, event.y)
              }
              onPositionChanged: function(event) {
                if (!pressed) return
                if (!moved && Math.hypot(event.x - startPoint.x, event.y - startPoint.y) < Style.space(8)) return
                moved = true
                overview.updateDrag(windowCard.modelData, mapToItem(overview.contentItem, event.x, event.y))
              }
              onReleased: function(event) {
                if (!moved) return
                overview.updateDrag(windowCard.modelData, mapToItem(overview.contentItem, event.x, event.y))
                overview.finishDrag(true)
              }
              onCanceled: if (moved) overview.finishDrag(false)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: overview.selectedIndex = windowCard.index
              Accessible.role: Accessible.Button
              Accessible.name: windowCard.toplevel ? windowCard.toplevel.title : ""
              Accessible.onPressAction: overview.activate(windowCard.modelData)
              onClicked: if (!moved) overview.activate(windowCard.modelData)
            }

            Rectangle {
              id: closeButton
              anchors.top: frame.top
              anchors.right: frame.right
              anchors.margins: Style.space(9)
              width: Style.space(25)
              height: width
              radius: width / 2
              color: closePointer.containsMouse ? "#cf3948" : "#d9232939"
              border.color: "#8be2e8f4"

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "×"
                color: "white"
                font.pixelSize: Style.space(17)
              }

              MouseArea {
                id: closePointer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: strings.t("overview.closeWindow")
                Accessible.onPressAction: overview.requestWindowClose(windowCard.toplevel)
                onClicked: overview.requestWindowClose(windowCard.toplevel)
              }
            }
          }
        }
      }

      ConfirmDialog {
        id: removalDialog
        anchors.fill: parent
        z: 10
        opened: !!overview.removal
        message: overview.removal ? strings.t("spaces.confirmRemove")
          .arg(overview.workspaceLabel(overview.removal.source))
          .arg(overview.workspaceLabel(overview.removal.destination)) : ""
        confirmText: strings.t("spaces.moveRemove")
        background: "#25334c"
        foreground: "#f3f6ff"
        scrim: "#af101523"
        selectedBackground: overview.accent
        selectedText: "#121b2b"
        fontFamily: Style.font.family
        cornerRadius: Style.cornerRadius
        onCanceled: overview.removal = null
        onConfirmed: if (overview.removal) overview.removeSpace(overview.removal.source.id, overview.removal.destination.id, true)
      }
    }

    DockIcon {
      z: 20
      readonly property var entry: overview.dragWindow && overview.dragWindow.wayland
        ? overview.dock.entryForAppId(overview.dragWindow.wayland.appId) : null
      x: overview.dragPoint.x - width / 2
      y: overview.dragPoint.y - height / 2 + Style.space(18)
      width: Style.space(48)
      height: width
      opacity: overview.dragWindow ? 1 : 0
      scale: overview.dragDestination !== null ? 0.85 : 1
      appId: entry ? entry.id : ""
      source: overview.dock.appLibrary
        ? overview.dock.appLibrary.iconSource(DockModel.iconNameForEntry(entry)) : ""
      Behavior on opacity { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: Style.duration(135); easing.type: Easing.OutCubic } }
    }
  }
}
