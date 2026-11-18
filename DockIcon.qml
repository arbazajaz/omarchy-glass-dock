import QtQuick

Item {
  id: tile

  property url source
  property string appId
  property bool launcher: false
  property bool useFilesFace: false
  readonly property bool filesFace: useFilesFace && appId.toLowerCase() === "org.gnome.nautilus"
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

  Canvas {
    anchors.fill: face
    visible: tile.filesFace
    antialiasing: true
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      ctx.scale(width / 100, height / 100)

      // The lighter half follows the tile's corner radius and the curved face.
      var light = ctx.createLinearGradient(49, 3, 92, 98)
      light.addColorStop(0, "#f2fcff")
      light.addColorStop(1, "#8ed1fb")
      ctx.beginPath()
      ctx.moveTo(58, 3)
      ctx.lineTo(73, 3)
      ctx.quadraticCurveTo(97, 3, 97, 27)
      ctx.lineTo(97, 73)
      ctx.quadraticCurveTo(97, 97, 73, 97)
      ctx.lineTo(46, 97)
      ctx.bezierCurveTo(48, 84, 51, 75, 45, 61)
      ctx.quadraticCurveTo(53, 59, 56, 53)
      ctx.lineTo(48, 53)
      ctx.quadraticCurveTo(52, 24, 58, 3)
      ctx.closePath()
      ctx.fillStyle = light
      ctx.fill()

      ctx.strokeStyle = "#123955"
      ctx.lineCap = "round"
      ctx.lineWidth = 5
      ctx.beginPath()
      ctx.moveTo(28, 34)
      ctx.lineTo(28, 40)
      ctx.moveTo(72, 31)
      ctx.lineTo(72, 37)
      ctx.moveTo(27, 65)
      ctx.quadraticCurveTo(51, 83, 75, 62)
      ctx.stroke()
    }
  }

  Image {
    id: appImage
    anchors.centerIn: parent
    width: parent.width * 0.72
    height: width
    source: tile.launcher || tile.filesFace ? "" : tile.source
    sourceSize: Qt.size(128, 128)
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    mipmap: true
  }

  Grid {
    id: glyph
    visible: !tile.filesFace && (tile.launcher || appImage.status === Image.Error || appImage.status === Image.Null)
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
