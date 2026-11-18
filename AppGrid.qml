import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Every app on one grid. Type to narrow it, arrows to move, Enter to launch.
Item {
  id: root

  property var appLibrary: null
  property var dock: null

  property bool opened: false
  property bool closing: false
  // While an app is dragged out toward the dock, the grid steps aside so the
  // dock shows through, and the app's icon follows the pointer. The grid keeps
  // the pointer for as long as the button is held, and tells the dock where it
  // is.
  property bool dragging: false
  property var dragEntry: null
  property point dragPoint
  // The app waiting on the user to confirm uninstalling it.
  property var uninstallEntry: null
  // The app whose menu is open, and where it opened.
  property var menuEntry: null
  property point menuPoint
  property string filterText: ""
  property int selectedIndex: 0
  property var apps: []

  readonly property int iconSize: Math.round(56 * Style.fontScale)
  readonly property int labelHeight: Math.ceil(labelMetrics.height) * 2
  readonly property int cellGutter: Style.spacing.sm
  readonly property int cellPadding: Style.spacing.lg
  readonly property int cellWidth: Math.round(iconSize * 2.2)
  readonly property int cellHeight: cellPadding * 2 + iconSize + Style.spacing.md + labelHeight
  readonly property int maxColumns: 10
  readonly property int headerHeight: Math.max(Style.space(36), Style.font.heading + Style.spacing.controlPaddingY * 2)
  readonly property int headerSpacing: Style.spacing.xl
  readonly property int screenMargin: Style.space(40)

  readonly property int columns: Math.max(1, Math.min(maxColumns,
    Math.floor((panel.width - screenMargin * 2) / cellWidth)))
  readonly property int gridWidth: columns * cellWidth

  Timer {
    id: closeDelay
    interval: Style.duration(125)
    onTriggered: root.closing = false
  }

  function open() {
    root.selectedIndex = 0
    if (root.appLibrary) root.appLibrary.refreshIcons()
    // The cells from last time are reused when nothing changed, so the grid
    // opens with its icons already drawn.
    if (root.appsStale || root.filterText !== "" || root.apps.length === 0) {
      search.clear()
      root.filterText = ""
      root.rebuild()
    } else {
      grid.positionViewAtBeginning()
    }
    closeDelay.stop()
    root.closing = false
    root.opened = true
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  function close() {
    if (root.dragging && root.dock) root.dock.endExternalDrag()
    root.closing = root.opened && !Style.reduceMotion
    root.opened = false
    if (root.closing) closeDelay.restart()
    root.uninstallEntry = null
    root.dragging = false
    root.dragEntry = null
    root.menuEntry = null
  }

  function dragTo(entry, point) {
    if (!root.dragging) {
      root.menuEntry = null
      root.dragEntry = entry
      root.dragging = true
    }
    root.dragPoint = point
    if (root.dock) root.dock.moveExternalDrag(panel.screen, point.x, point.y)
  }

  function dropDrag() {
    var entry = root.dragEntry
    if (entry && root.dock) root.dock.dropExternalDrag(panel.screen, root.dragPoint.x, root.dragPoint.y, String(entry.id || ""))
    root.close()
  }

  function requestUninstall(entry) {
    if (!entry) return
    root.menuEntry = null
    uninstallConfirm.selectedIndex = 1
    root.uninstallEntry = entry
  }

  function cancelUninstall() {
    root.uninstallEntry = null
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  function confirmUninstall() {
    var entry = root.uninstallEntry
    root.uninstallEntry = null
    root.close()
    if (entry && root.appLibrary) root.appLibrary.remove(entry.id, root.appLibrary.entryName(entry))
  }

  function openMenu(entry, point) {
    root.menuEntry = entry
    root.menuPoint = point
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function rebuild() {
    root.appsStale = false
    var rows = root.appLibrary ? root.appLibrary.sortedEntries(root.filterText) : []
    root.apps = rows.map(function(row) { return row.entry })
    root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.apps.length - 1))
    grid.positionViewAtBeginning()
  }

  function setFilter(text) {
    root.filterText = text
    root.selectedIndex = 0
    root.rebuild()
  }

  function select(delta) {
    if (root.apps.length === 0) return
    root.selectedIndex = Math.max(0, Math.min(root.apps.length - 1, root.selectedIndex + delta))
    grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function launch(index) {
    var entry = root.apps[index]
    if (!entry || !root.appLibrary) return
    root.close()
    if (root.dock) root.dock.launchEntry(entry)
    else root.appLibrary.launch(entry.id, root.appLibrary.entryName(entry))
  }

  FontMetrics {
    id: labelMetrics
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.body
  }

  // Apps installed or removed while the grid is closed are picked up when it
  // next opens.
  property bool appsStale: false

  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      if (root.opened) root.rebuild()
      else root.appsStale = true
    }
  }

  OverlayWindow {
    id: panel
    shown: root.opened || root.closing
    shownKeyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: root.opened ? panel.contentItem : null }
    WlrLayershell.namespace: "omarchy-dock-apps"
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0; color: "#b02a3650" }
        GradientStop { position: 0.55; color: "#ae212840" }
        GradientStop { position: 1; color: "#d0131827" }
      }
      opacity: root.opened && panel.contentRevealed && !root.dragging ? 1 : 0

      Behavior on opacity {
        id: scrimFade
        NumberAnimation { duration: Style.duration(scrimFade.targetValue > 0 ? 150 : 100); easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: {
        if (root.menuEntry) root.menuEntry = null
        else root.close()
      }
    }

    Item {
      id: card
      anchors.fill: parent
      enabled: root.opened
      opacity: root.opened && panel.contentRevealed && !root.dragging ? 1 : 0
      scale: root.opened && panel.contentRevealed ? 1 : 0.97

      Behavior on opacity {
        NumberAnimation { duration: Style.duration(root.opened ? 180 : 120); easing.type: Easing.OutCubic }
      }
      Behavior on scale {
        NumberAnimation { duration: Style.duration(root.opened ? 180 : 120); easing.type: Easing.OutCubic }
      }

      ConfirmDialog {
        id: uninstallConfirm

        anchors.fill: parent
        opened: !!root.uninstallEntry
        z: 10
        message: Commons.I18n.t("common.uninstallConfirm").arg(root.uninstallEntry && root.appLibrary ? root.appLibrary.entryName(root.uninstallEntry) : "")
        confirmText: Commons.I18n.t("common.uninstall")
        background: Commons.Color.menu.background
        foreground: Commons.Color.menu.text
        scrim: Commons.Color.menu.scrim
        selectedBackground: Commons.Color.menu.selectedBackground
        selectedText: Commons.Color.menu.selectedText
        fontFamily: Style.font.menuFamily
        cornerRadius: Style.cornerRadius
        onCanceled: root.cancelUninstall()
        onConfirmed: root.confirmUninstall()
      }

      Column {
        width: root.gridWidth
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: root.screenMargin
        anchors.bottomMargin: root.screenMargin / 2
        spacing: root.headerSpacing

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.min(parent.width, Style.space(390))
          height: root.headerHeight
          radius: height / 2
          color: "#40d5e1ff"
          border.color: "#76e6edff"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "⌕"
            font.pixelSize: Style.space(20)
            color: "#f1f5ff"
          }

          Text {
            anchors.fill: search
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: Commons.I18n.t("dock.searchApps")
            visible: search.text.length === 0
            color: "#d2dcf5"
            font: search.font
          }

          TextInput {
            id: search
            anchors.fill: parent
            anchors.leftMargin: Style.space(44)
            anchors.rightMargin: Style.space(16)
            verticalAlignment: TextInput.AlignVCenter
            color: "#f8faff"
            selectionColor: "#557ac1"
            font.pixelSize: Style.font.heading
            clip: true
            focus: true
            selectByMouse: true
            text: root.filterText
            onTextEdited: root.setFilter(text)

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
              if (root.uninstallEntry) {
                if (uninstallConfirm.handleKey(event)) event.accepted = true
                return
              }
              if (event.key === Qt.Key_Delete && !root.filterText) {
                root.requestUninstall(root.apps[root.selectedIndex])
              } else if (event.key === Qt.Key_Escape) {
                if (root.menuEntry) root.menuEntry = null
                else if (root.filterText) {
                  search.clear()
                  root.setFilter("")
                } else root.close()
              } else if (event.key === Qt.Key_Up) {
                root.select(-root.columns)
              } else if (event.key === Qt.Key_Down) {
                root.select(root.columns)
              } else if (!root.filterText && Util.readingKey(event) === Qt.Key_Left) {
                root.select(-1)
              } else if (!root.filterText && Util.readingKey(event) === Qt.Key_Right) {
                root.select(1)
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.launch(root.selectedIndex)
              } else return
              event.accepted = true
            }
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - parent.spacing

          GridView {
            id: grid
            anchors.fill: parent
            model: root.apps
            clip: true
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
              id: cell

              required property int index
              required property var modelData
              readonly property bool selected: index === root.selectedIndex
              property point pressPoint
              // A press that wanders is a drag in the making, not a click.
              property bool moved: false

              width: root.cellWidth
              height: root.cellHeight

              DockIcon {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.cellPadding
                width: root.iconSize
                height: root.iconSize
                appId: cell.modelData.id
                source: root.appLibrary ? root.appLibrary.iconSource(cell.modelData.icon) : ""
                scale: cell.selected ? 1.1 : 1

                Behavior on scale {
                  NumberAnimation { duration: Style.duration(145); easing.type: Easing.OutCubic }
                }
              }

              // The selection marks the app's name, not the whole cell.
              Rectangle {
                anchors.centerIn: label
                width: Math.min(cell.width - root.cellGutter * 2, label.contentWidth + Style.spacing.md * 2)
                height: label.contentHeight + Style.spacing.xs * 2
                radius: Style.cornerRadius
                color: cell.selected ? "#65485e8c" : "transparent"
              }

              Text {
                id: label
                anchors.top: icon.bottom
                anchors.topMargin: Style.spacing.md
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - (root.cellGutter + Style.spacing.md) * 2
                textFormat: Text.PlainText
                text: root.appLibrary ? root.appLibrary.entryName(cell.modelData) : ""
                color: "#f2f6ff"
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }

              MouseArea {
                id: appHit
                x: Math.max(0, (parent.width - Math.max(icon.width, label.contentWidth) - root.cellGutter) / 2)
                y: icon.y
                width: parent.width - x * 2
                height: label.y + label.contentHeight - y + Style.spacing.xs
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                // The grid would otherwise take a dragging press for a scroll.
                preventStealing: true
                onContainsMouseChanged: if (containsMouse && !root.dragging) root.selectedIndex = cell.index
                onPressed: function(event) {
                  cell.moved = false
                  cell.pressPoint = Qt.point(event.x, event.y)
                }
                onPositionChanged: function(event) {
                  if (!(pressedButtons & Qt.LeftButton)) return
                  if (!cell.moved && Math.hypot(event.x - cell.pressPoint.x, event.y - cell.pressPoint.y) > Style.space(4)) cell.moved = true
                  if (cell.moved) root.dragTo(cell.modelData, appHit.mapToItem(panel.contentItem, event.x, event.y))
                }
                onReleased: function(event) {
                  if (root.dragging && event.button === Qt.LeftButton) root.dropDrag()
                }
                onCanceled: if (root.dragging) root.close()
                onClicked: function(event) {
                  if (cell.moved) return
                  if (event.button === Qt.RightButton) {
                    root.openMenu(cell.modelData, appHit.mapToItem(panel.contentItem, event.x, event.y))
                    return
                  }
                  root.menuEntry = null
                  root.launch(cell.index)
                }
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: root.apps.length === 0
            textFormat: Text.PlainText
            text: Commons.I18n.t("dock.noAppsMatch").arg(root.filterText)
            color: "#e5ecff"
            opacity: 0.85
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.title
          }
        }
      }
    }
    // The dragged app's icon, under the pointer.
    Image {
      visible: root.dragging && !!root.dragEntry
      x: root.dragPoint.x - width / 2
      y: root.dragPoint.y - height / 2
      width: root.iconSize
      height: root.iconSize
      sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
      source: root.dragEntry && root.appLibrary ? root.appLibrary.iconSource(root.dragEntry.icon) : ""
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
    }

    // Right-click on an app: open it, or keep it in the dock or take it out.
    BorderSurface {
      id: menu

      readonly property var entry: root.menuEntry
      readonly property bool pinned: !!entry && !!root.dock && root.dock.isPinned(String(entry.id || ""))

      visible: !!entry && !root.dragging
      width: Math.max(Style.space(160), menuColumn.implicitWidth) + padding * 2
      height: menuColumn.implicitHeight + padding * 2
      // Opens along the reading direction from the pointer.
      x: LayoutMirroring.enabled
        ? Math.max(Style.gapsOut, root.menuPoint.x - width)
        : Math.min(root.menuPoint.x, panel.width - width - Style.gapsOut)
      y: Math.min(root.menuPoint.y, panel.height - height - Style.gapsOut)
      radius: Style.cornerRadius
      color: Commons.Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)
      padding: Style.spacing.sm

      Column {
        id: menuColumn
        x: menu.contentLeftInset
        y: menu.contentTopInset
        width: menu.width - menu.contentLeftInset - menu.contentRightInset

        MenuRow {
          text: Commons.I18n.t("dock.open")
          onTriggered: {
            var entry = menu.entry
            root.close()
            if (entry && root.dock) root.dock.launchEntry(entry)
            else if (entry && root.appLibrary) root.appLibrary.launch(entry.id, root.appLibrary.entryName(entry))
          }
        }

        MenuRow {
          visible: !!root.dock
          text: menu.pinned ? Commons.I18n.t("dock.removeFromDock") : Commons.I18n.t("dock.keepInDock")
          onTriggered: {
            if (root.dock && menu.entry) root.dock.setPinned(String(menu.entry.id || ""), !menu.pinned)
            root.menuEntry = null
          }
        }

        MenuRow {
          text: Commons.I18n.t("dock.uninstall")
          onTriggered: root.requestUninstall(menu.entry)
        }
      }
    }
  }

  component MenuRow: Rectangle {
    id: row

    property string text: ""
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

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.triggered()
    }
  }
}
