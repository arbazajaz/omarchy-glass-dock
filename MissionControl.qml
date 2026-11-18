import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "DockModel.js" as DockModel

OverlayWindow {
  id: overview

  required property var dock
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
  readonly property var workspaceGroups: {
    var seen = new Set()
    return windows.map(window => window.workspace).filter(function(workspace) {
      if (seen.has(workspace.id)) return false
      seen.add(workspace.id)
      return true
    })
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

  function close() {
    if (!shown || closing) return
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
    if (workspace.id <= 0) return workspace.name.replace(/^special:/, "")
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
    Hyprland.refreshToplevels()
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
      source: overview.shown ? Util.fileUrl(overview.wallpaperPath) : ""
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
      anchors.fill: parent
      anchors.margins: Style.space(34)
      focus: true

      scale: overview.contentRevealed && !overview.closing ? 1 : 0.97
      Behavior on scale {
        NumberAnimation { duration: Style.duration(overview.closing ? 120 : 190); easing.type: Easing.OutCubic }
      }

      Keys.onEscapePressed: overview.close()
      Keys.onLeftPressed: overview.moveSelection(-1)
      Keys.onRightPressed: overview.moveSelection(1)
      Keys.onUpPressed: overview.moveSelection(-overview.columns)
      Keys.onDownPressed: overview.moveSelection(overview.columns)
      Keys.onReturnPressed: overview.activate(overview.displayedWindows[overview.selectedIndex])
      Keys.onEnterPressed: overview.activate(overview.displayedWindows[overview.selectedIndex])

      Flickable {
        id: workspaceStrip
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, workspaceTabs.width)
        height: workspaceTabs.height
        contentWidth: workspaceTabs.width
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Row {
          id: workspaceTabs
          spacing: Style.space(8)

          Repeater {
            model: [null].concat(overview.workspaceGroups)
            delegate: Rectangle {
              id: tab
              required property var modelData
              readonly property bool selected: overview.selectedWorkspace === (modelData ? modelData.id : null)
              width: tabLabel.implicitWidth + Style.space(28)
              height: Style.space(34)
              radius: height / 2
              color: selected ? "#a7435b80" : "#40232c43"
              border.color: selected ? "#add9e9ff" : "#44d1deff"

              Text {
                id: tabLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: tab.modelData ? overview.workspaceLabel(tab.modelData) : strings.t("overview.all")
                color: "#f3f7ff"
                font.pixelSize: Style.font.body
                font.weight: tab.selected ? Font.DemiBold : Font.Normal
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: overview.selectWorkspace(tab.modelData ? tab.modelData.id : null)
              }
            }
          }
        }
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
        anchors.bottomMargin: workspaceStrip.height

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
              anchors.fill: frame
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: overview.selectedIndex = windowCard.index
              Accessible.role: Accessible.Button
              Accessible.name: windowCard.toplevel ? windowCard.toplevel.title : ""
              Accessible.onPressAction: overview.activate(windowCard.modelData)
              onClicked: overview.activate(windowCard.modelData)
            }
          }
        }
      }
    }
  }
}
