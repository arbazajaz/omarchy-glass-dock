import QtQuick
import Quickshell.Wayland
import qs.Commons
import "DockModel.js" as DockModel

Item {
  id: strip

  required property var overview
  readonly property int tileWidth: Math.round(Math.max(Style.space(89),
    Math.min(Style.space(151), (width - Style.space(145)) / Math.max(1, Math.min(10, overview.workspaceGroups.length)) - Style.space(8))))
  readonly property int thumbnailHeight: Math.round(tileWidth * 0.63)
  implicitHeight: thumbnailHeight + Style.space(29)

  function showActiveSpace() {
    var position = overview.workspaceGroups.findIndex(space => space.id === overview.activeWorkspaceId)
    if (position >= 0) list.positionViewAtIndex(position, ListView.Contain)
  }

  Connections {
    target: strip.overview
    function onActiveWorkspaceIdChanged() {
      if (strip.overview.shown) Qt.callLater(strip.showActiveSpace)
    }
    function onShownChanged() {
      if (strip.overview.shown) Qt.callLater(strip.showActiveSpace)
    }
  }

  function targetAt(point) {
    var at = strip.mapFromItem(overview.contentItem, point.x, point.y)
    if (at.x < list.x || at.x > list.x + list.width || at.y < 0 || at.y > list.height) return null
    var item = list.itemAt(at.x - list.x + list.contentX, at.y)
    return item ? item.modelData.id : null
  }

  function scrollDrag(point) {
    var at = strip.mapFromItem(overview.contentItem, point.x, point.y)
    if (at.y < 0 || at.y > list.height) return
    if (at.x >= list.x && at.x < list.x + Style.space(24)) {
      list.contentX = Math.max(0, list.contentX - Style.space(24))
    } else if (at.x <= list.x + list.width && at.x > list.x + list.width - Style.space(24)) {
      list.contentX = Math.min(Math.max(0, list.contentWidth - list.width), list.contentX + Style.space(24))
    }
  }

  ActionChip {
    id: allWindows
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(84)
    label: overview.label("overview.all")
    selected: overview.selectedWorkspace === null
    onTriggered: overview.selectWorkspace(null)
  }

  ActionChip {
    id: addSpace
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(36)
    label: "+"
    accessibleLabel: overview.label("spaces.add")
    onTriggered: overview.addSpace()
  }

  ListView {
    id: list
    anchors.left: allWindows.right
    anchors.right: addSpace.left
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    height: parent.height
    orientation: ListView.Horizontal
    spacing: Style.space(8)
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    model: overview.shown ? overview.workspaceGroups : []
    onCountChanged: if (overview.shown) Qt.callLater(strip.showActiveSpace)

    delegate: Item {
      id: tile
      required property var modelData
      readonly property bool active: modelData.id === overview.activeWorkspaceId
      readonly property bool selected: modelData.id === overview.selectedWorkspace
      readonly property bool dropTarget: modelData.id === overview.dragDestination && modelData.id !== overview.dragSource
      readonly property bool removable: /^Glass-Space-[0-9]+$/.test(modelData.name)
      width: strip.tileWidth
      height: list.height

      Rectangle {
        id: thumbnail
        width: parent.width
        height: strip.thumbnailHeight
        radius: Style.space(11)
        color: "#24324a"
        border.width: tile.active || tile.dropTarget ? 2 : 1
        border.color: tile.dropTarget ? "#96f7d0" : tile.active ? overview.accent : tile.selected ? "#a1bbdf" : "#556987a9"

        Item {
          id: thumbnailContent
          anchors.fill: parent
          anchors.margins: 3
          clip: true

          Image {
            anchors.fill: parent
            source: overview.wallpaperUrl
            sourceSize: Qt.size(320, 180)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            opacity: 0.68
          }

          Repeater {
            model: tile.modelData.windows.slice(0, 4)
            delegate: Rectangle {
              id: miniature
              required property int index
              required property var modelData
              readonly property var ipc: modelData.lastIpcObject || ({})
              readonly property var screen: tile.modelData.workspace && tile.modelData.workspace.monitor
                ? tile.modelData.workspace.monitor.lastIpcObject : null
              readonly property real screenWidth: screen && screen.width ? screen.width / (screen.scale || 1) : 1280
              readonly property real screenHeight: screen && screen.height ? screen.height / (screen.scale || 1) : 720
              width: Math.min(parent.width, Math.max(parent.width * 0.22, (ipc.size ? ipc.size[0] : 900) / screenWidth * parent.width))
              height: Math.min(parent.height, Math.max(parent.height * 0.20, (ipc.size ? ipc.size[1] : 500) / screenHeight * parent.height))
              x: Math.max(0, Math.min(parent.width - width, ipc.at && screen ? (ipc.at[0] - screen.x) / screenWidth * parent.width : index * 5 + 4))
              y: Math.max(0, Math.min(parent.height - height, ipc.at && screen ? (ipc.at[1] - screen.y) / screenHeight * parent.height : index * 3 + 3))
              radius: 3
              color: "#cf293655"
              border.color: "#8aa4bd"
              clip: true
              opacity: 0
              Component.onCompleted: opacity = 1
              Behavior on opacity { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }

              ScreencopyView {
                id: capture
                anchors.centerIn: parent
                constraintSize: Qt.size(parent.width, parent.height)
                captureSource: overview.contentRevealed && miniature.modelData.wayland ? miniature.modelData.wayland : null
                live: false
              }

              DockIcon {
                anchors.centerIn: parent
                visible: !capture.hasContent
                width: Math.min(Style.space(16), parent.height - 2)
                height: width
                readonly property var entry: miniature.modelData.wayland
                  ? overview.dock.entryForAppId(miniature.modelData.wayland.appId) : null
                appId: entry ? entry.id : ""
                source: overview.dock.appLibrary
                  ? overview.dock.appLibrary.iconSource(DockModel.iconNameForEntry(entry)) : ""
              }
            }
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: parent.radius
          color: "#3096f7d0"
          opacity: tile.dropTarget ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: overview.switchSpace(tile.modelData.id)
          Accessible.role: Accessible.Button
          Accessible.name: overview.workspaceLabel(tile.modelData)
          Accessible.onPressAction: overview.switchSpace(tile.modelData.id)
        }

        ActionChip {
          visible: tile.removable
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: 3
          width: Style.space(21)
          height: width
          label: "×"
          accessibleLabel: overview.label("spaces.remove")
          onTriggered: overview.requestRemove(tile.modelData)
        }
      }

      Text {
        anchors.top: thumbnail.bottom
        anchors.topMargin: Style.space(5)
        width: parent.width
        textFormat: Text.PlainText
        text: overview.workspaceLabel(tile.modelData)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        font.pixelSize: Style.font.body
        color: "#f0f4ff"
      }
    }
  }

  component ActionChip: Rectangle {
    id: chip
    property string label
    property string accessibleLabel: label
    property bool selected: false
    signal triggered()
    height: Style.space(35)
    radius: height * 0.34
    color: chipMouse.containsMouse || selected ? "#b13f567b" : "#b3222c43"
    border.color: selected ? overview.accent : "#60839bc2"

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: chip.label
      color: "#ebf2ff"
      font.pixelSize: chip.label.length === 1 ? Style.space(19) : Style.font.body - 1
    }
    MouseArea {
      id: chipMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.triggered()
      Accessible.role: Accessible.Button
      Accessible.name: chip.accessibleLabel
      Accessible.onPressAction: chip.triggered()
    }
  }
}
