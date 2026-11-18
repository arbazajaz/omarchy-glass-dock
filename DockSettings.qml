import QtQuick
import qs.Commons
import qs.Commons as Commons

Column {
  id: settings
  required property var dock
  signal positionChangedByUser()

  spacing: Style.space(4)

  Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function numeric(key, value, choices, unit) {
    return { key: key, value: value, choices: choices,
      display: strings.t(unit).arg(Commons.I18n.formatNumber(value)) }
  }

  function toggle(key, value) {
    return { key: key, value: value ? "on" : "off", choices: ["off", "on"],
      display: strings.t(value ? "dock.on" : "dock.off") }
  }

  Text {
    leftPadding: Style.space(8)
    height: Style.space(30)
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
    text: strings.t("dock.settings")
    color: Commons.Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.heading
    font.weight: Font.DemiBold
  }

  Grid {
    width: parent.width
    columns: 2
    spacing: Style.space(4)

    Repeater {
      model: !settings.dock ? [] : [
        settings.toggle("autohide", settings.dock.autohide),
        settings.toggle("fullscreenAutohide", settings.dock.fullscreenAutohide),
        settings.numeric("hideDelay", settings.dock.hideDelay, [0, 150, 280, 500, 750, 1000, 1500], "dock.milliseconds"),
        { key: "position", value: settings.dock.position, choices: ["bottom", "left", "top", "right"],
          display: Commons.I18n.t("dock.position" + settings.dock.position[0].toUpperCase() + settings.dock.position.slice(1)) },
        { key: "width", value: settings.dock.dockWidth, choices: ["fit", 50, 75, 100],
          display: settings.dock.dockWidth === "fit" ? strings.t("dock.fit")
            : strings.t("dock.percent").arg(Commons.I18n.formatNumber(settings.dock.dockWidth)) },
        settings.numeric("height", settings.dock.dockHeight, [42, 49, 56, 66, 79, 92, 104], "dock.pixels"),
        settings.numeric("iconSize", settings.dock.iconPixels, [24, 30, 36, 44, 48, 56, 64, 72], "dock.pixels"),
        settings.numeric("spacing", settings.dock.iconSpacing, [4, 8, 12, 16, 22, 30], "dock.pixels"),
        settings.numeric("opacity", settings.dock.glassOpacity, [10, 25, 45, 64, 80, 100], "dock.percent"),
        { key: "blur", value: settings.dock.blur, choices: ["off", "soft", "strong"],
          display: strings.t("dock.blur." + settings.dock.blur) },
        settings.numeric("animationSpeed", settings.dock.animationSpeed, [50, 75, 100, 125, 150, 200], "dock.percent"),
        { key: "backgroundColor", value: settings.dock.backgroundColor || "theme",
          choices: ["theme", "#151821", "#262a35", "#532e1d", "#242e52", "#597b8c", "#d2dde9"],
          display: settings.dock.backgroundColor || strings.t("dock.themeColor") },
        settings.numeric("radius", settings.dock.cornerRadius, [0, 8, 14, 22, 30, 42, 52], "dock.pixels"),
        settings.numeric("shadow", settings.dock.dockShadow, [0, 25, 55, 75, 100], "dock.percent"),
        settings.numeric("glow", settings.dock.dockGlow, [0, 15, 30, 60, 80, 100], "dock.percent"),
        settings.numeric("magnification", settings.dock.hoverScale, [0, 20, 40, 60, 80], "dock.percent"),
        { key: "style", value: settings.dock.dockStyle, choices: settings.dock.styles,
          display: strings.t("dock.theme." + settings.dock.dockStyle) }
      ]

      delegate: Rectangle {
        id: control
        required property var modelData
        readonly property string label: strings.t("dock.control." + modelData.key)
        width: (settings.width - Style.space(4)) / 2
        height: Style.space(47)
        radius: Style.space(9)
        color: pointer.containsMouse ? Style.hoverFill : Util.alpha(Commons.Color.popups.text, 0.045)
        border.color: Util.alpha(Commons.Color.popups.text, 0.12)

        Accessible.role: Accessible.Button
        Accessible.name: control.label + " " + control.modelData.display
        Accessible.onPressAction: change(false)

        function change(previous) {
          var choices = modelData.choices
          var offset = previous ? choices.length - 1 : 1
          var index = choices.indexOf(modelData.value)
          settings.dock.writeDockSetting(modelData.key, choices[(index + offset) % choices.length])
          if (modelData.key === "position") settings.positionChangedByUser()
        }

        Text {
          x: Style.space(9)
          y: Style.space(5)
          width: parent.width - Style.space(18)
          textFormat: Text.PlainText
          text: control.label
          color: Commons.Color.popups.text
          opacity: 0.72
          font.family: Style.font.family
          font.pixelSize: Style.font.body - 2
          elide: Text.ElideRight
        }

        Text {
          x: Style.space(9)
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(6)
          width: parent.width - Style.space(28)
          textFormat: Text.PlainText
          text: control.modelData.display
          color: Commons.Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(9)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "›"
          color: Commons.Color.popups.text
          opacity: 0.55
        }

        MouseArea {
          id: pointer
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: function(event) { control.change(event.button === Qt.RightButton) }
        }
      }
    }
  }
}
