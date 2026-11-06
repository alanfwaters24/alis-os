// ALIS Assistant on screen (ALIS OS): two see-through overlays, no window frames.
//
//   Orb       balloons out of the top-right corner while she listens/thinks/
//             speaks (same teal->violet ring and helix as the NEST orb), with
//             what you said and her reply underneath; shrinks back when done.
//   Controls  Mic and Stop glass buttons slide in at the bottom right, just
//             above the dock, while she's active. While muted the red mic
//             button stays so you can see she's off and unmute in one click.
//
// Talks to the assistant on 127.0.0.1 (port = last command-line argument).
// Run with:  qml alis-ui.qml -- 47100
import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell

QtObject {
    id: app
    readonly property string base: "http://127.0.0.1:" + Qt.application.arguments[Qt.application.arguments.length - 1]
    property string vs: "idle"          // idle | listening | thinking | speaking
    property real level: 0
    property bool muted: false
    property string heard: ""
    property string caption: ""
    property bool active: vs !== "idle"
    property bool showOrb: false

    readonly property color teal: "#2DE0C8"
    readonly property color violet: "#B48CFF"
    readonly property color text: "#E8F5F0"
    readonly property color dim: "#8A9A96"

    function post(what) {
        var x = new XMLHttpRequest();
        x.open("POST", base + "/api/" + what);
        x.send("");
    }

    // Poll the assistant: quickly while she's on screen, gently otherwise.
    property Timer poller: Timer {
        interval: app.showOrb ? 70 : 120; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var x = new XMLHttpRequest();
            x.onreadystatechange = function () {
                if (x.readyState !== XMLHttpRequest.DONE || x.status !== 200) return;
                var s = JSON.parse(x.responseText);
                app.vs = s.state; app.level = s.level || 0; app.muted = !!s.muted;
                app.heard = s.heard || ""; app.caption = s.caption || "";
            };
            x.open("GET", app.base + "/api/status");
            x.send();
        }
    }

    // Show while active; linger a moment after she finishes so the reply can be read.
    onActiveChanged: { if (active) { linger.stop(); showOrb = true } else linger.restart() }
    property Timer linger: Timer { id: linger; interval: app.caption ? 2600 : 600; onTriggered: app.showOrb = false }

    // ------------------------------------------------------------------ the orb
    property Window orbWindow: Window {
        id: orbWin
        width: 340; height: 300
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        visible: app.showOrb || balloon.running || orbBody.scale > 0.02
        title: "ALIS Assistant"
        LayerShell.Window.scope: "alis-orb"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.activateOnShow: false

        Item {
            id: orbBody
            anchors.fill: parent
            transformOrigin: Item.TopRight
            scale: 0.0
            opacity: scale < 0.2 ? scale * 5 : 1

            states: State { name: "out"; when: app.showOrb; PropertyChanges { orbBody.scale: 1.0 } }
            transitions: [
                Transition { to: "out"; NumberAnimation { id: balloon; property: "scale"; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 2.2 } },
                Transition { to: ""; NumberAnimation { property: "scale"; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.4 } }
            ]

            // orb, top-right with a little breathing room from the corner
            Item {
                id: orb
                width: 150; height: 150
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 18; anchors.rightMargin: 22
                scale: app.vs === "speaking" ? 1 + app.level * 0.12 : 1
                Behavior on scale { NumberAnimation { duration: 70 } }

                // glow: teal while listening, violet while speaking, pulsing with the voice
                Shape {
                    anchors.centerIn: parent
                    width: 230; height: 230
                    opacity: app.vs === "listening" || app.vs === "speaking" ? 0.9 : 0.35
                    scale: 1 + app.level * (app.vs === "speaking" ? 0.45 : 0.35)
                    Behavior on scale { NumberAnimation { duration: 70 } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: RadialGradient {
                            centerX: 115; centerY: 115; centerRadius: 115; focalX: 115; focalY: 115
                            GradientStop { position: 0.0; color: app.vs === "speaking" ? "#61B48CFF" : "#592DE0C8" }
                            GradientStop { position: 1.0; color: "#002DE0C8" }
                        }
                        PathAngleArc { centerX: 115; centerY: 115; radiusX: 115; radiusY: 115; startAngle: 0; sweepAngle: 360 }
                    }
                }
                // dark disc behind the helix
                Rectangle { anchors.fill: parent; radius: width / 2; color: "#E605100D" }
                // the spinning teal->violet ring
                Shape {
                    id: ring
                    anchors.fill: parent
                    ShapePath {
                        strokeWidth: -1
                        fillRule: ShapePath.OddEvenFill
                        fillGradient: ConicalGradient {
                            centerX: 75; centerY: 75; angle: 0
                            GradientStop { position: 0.0; color: app.teal }
                            GradientStop { position: 0.5; color: app.violet }
                            GradientStop { position: 1.0; color: app.teal }
                        }
                        PathAngleArc { centerX: 75; centerY: 75; radiusX: 75; radiusY: 75; startAngle: 0; sweepAngle: 360 }
                        PathAngleArc { centerX: 75; centerY: 75; radiusX: 70; radiusY: 70; startAngle: 0; sweepAngle: 360; moveToStart: true }
                    }
                    RotationAnimator on rotation {
                        from: 0; to: 360; loops: Animation.Infinite; running: orbWin.visible
                        duration: app.vs === "thinking" ? 800 : app.vs === "listening" ? 2500 : 6000
                    }
                }
                Image {
                    anchors.centerIn: parent
                    width: 93; height: 93
                    source: Qt.resolvedUrl("orb-icon.svg")
                    sourceSize: Qt.size(186, 186)
                    SequentialAnimation on opacity {
                        running: app.vs === "thinking"; loops: Animation.Infinite
                        onRunningChanged: if (!running) parent.opacity = 1
                        NumberAnimation { to: 0.5; duration: 500 } NumberAnimation { to: 1.0; duration: 500 }
                    }
                }
            }

            // what you said + her reply, in a small glass bubble under the orb
            Rectangle {
                anchors.top: orb.bottom; anchors.topMargin: 14
                anchors.right: parent.right; anchors.rightMargin: 12
                width: Math.min(316, Math.max(heardText.implicitWidth, replyText.implicitWidth) + 28)
                height: col.implicitHeight + 20
                visible: app.heard !== "" || app.caption !== ""
                radius: 14
                color: "#D90C1C18"
                border.color: "#592DD4BF"; border.width: 1
                Column {
                    id: col
                    anchors.fill: parent; anchors.margins: 10; anchors.leftMargin: 14; anchors.rightMargin: 14
                    spacing: 4
                    Text {
                        id: heardText
                        width: Math.min(implicitWidth, 288)
                        visible: app.heard !== ""
                        text: "“" + app.heard + "”"
                        color: app.dim; font.family: "Rajdhani"; font.pixelSize: 14
                        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                    }
                    Text {
                        id: replyText
                        width: Math.min(implicitWidth, 288)
                        visible: app.caption !== ""
                        text: app.caption
                        color: app.text; font.family: "Rajdhani"; font.pixelSize: 16; font.weight: Font.Medium
                        wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ controls
    property Window controlsWindow: Window {
        id: ctlWin
        width: 132; height: 58
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        visible: app.active || app.muted || slide.running || bar.x < width
        title: "ALIS Controls"
        LayerShell.Window.scope: "alis-controls"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.activateOnShow: false
        // sit just above the floating dock, at the tray end of the screen
        LayerShell.Window.margins: Qt.rect(0, 0, 16, 76)

        Row {
            id: bar
            y: 5
            spacing: 10
            // slides in from the right edge
            x: app.active ? ctlWin.width - width - 8 : (app.muted ? ctlWin.width - 48 - 8 : ctlWin.width + 4)
            Behavior on x { NumberAnimation { id: slide; duration: 380; easing.type: Easing.OutCubic } }

            Repeater {
                model: [
                    { key: "mic", show: true },
                    { key: "stop", show: app.active }
                ]
                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    property bool isMic: modelData.key === "mic"
                    visible: modelData.show
                    width: 48; height: 48; radius: 24
                    color: isMic && app.muted ? "#66F87171" : (hover.hovered ? "#3314B8A6" : "#CC0C1C18")
                    border.width: 1
                    border.color: isMic && app.muted ? "#F87171" : "#662DD4BF"
                    Text {
                        anchors.centerIn: parent
                        text: btn.isMic ? (app.muted ? "🎙︎" : "🎙︎") : "■"
                        color: btn.isMic && app.muted ? "#FFE4E4" : app.text
                        font.pixelSize: btn.isMic ? 20 : 15
                    }
                    // a diagonal line through the mic while muted
                    Rectangle {
                        visible: btn.isMic && app.muted
                        anchors.centerIn: parent; width: 30; height: 2.5; radius: 1
                        rotation: -45; color: "#FFE4E4"
                    }
                    HoverHandler { id: hover }
                    TapHandler { onTapped: app.post(btn.isMic ? "toggle-mute" : "stop") }
                }
            }
        }
    }
}
