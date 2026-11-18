import QtQuick

Item {
  id: tile

  property url source
  property string appId
  property bool launcher: false
  readonly property var colors: paletteFor(appId.toLowerCase())

  function paletteFor(id) {
    if (launcher) return ["#78839d", "#32384e"]
    if (id === "org.gnome.nautilus") return ["#66d8fd", "#2672ca"]
    if (id === "chromium") return ["#e8f8ff", "#a5c8ec"]
    if (id === "foot") return ["#465771", "#141a2d"]
    if (id === "omacalc") return ["#636d84", "#252c41"]
    if (id === "omawrite") return ["#ffdb92", "#d58046"]
    if (id === "x") return ["#4d5365", "#181925"]
    if (id === "youtube") return ["#ffd8dc", "#d26072"]
    return ["#7d8ba1", "#394256"]
  }

  Rectangle {
    anchors.fill: face
    anchors.topMargin: 2
    anchors.bottomMargin: -2
    radius: face.radius
    color: "#450e101c"
  }

  Rectangle {
    id: face
    anchors.fill: parent
    radius: width * 0.26
    border.width: 1
    border.color: "#65ffffff"
    gradient: Gradient {
      GradientStop { position: 0; color: tile.colors[0] }
      GradientStop { position: 1; color: tile.colors[1] }
    }
  }

  Image {
    id: appImage
    anchors.centerIn: parent
    width: parent.width * 0.72
    height: width
    source: tile.launcher ? "" : tile.source
    sourceSize: Qt.size(128, 128)
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    mipmap: true
  }

  Grid {
    id: glyph
    visible: tile.launcher || appImage.status === Image.Error || appImage.status === Image.Null
    anchors.centerIn: parent
    columns: 3
    spacing: tile.width * 0.055

    Repeater {
      model: 9
      delegate: Rectangle {
        required property int index
        width: tile.width * 0.117
        height: width
        radius: width * 0.34
        color: ["#81d7ff", "#dfeaff", "#b3a8ff", "#b9adff", "#ffffff", "#f9c98c",
          "#99f2da", "#c0dcff", "#f7a5c6"][index]
      }
    }
  }
}
