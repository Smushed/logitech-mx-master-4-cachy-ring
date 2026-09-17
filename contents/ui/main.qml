import QtQuick
import QtQuick.Window
import org.kde.kwin
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker
import "apps.js" as Apps
import "logic.js" as Logic

Window {
    id: ring
    title: "MX App Ring"
    width: 440
    height: 440
    color: "transparent"
    visible: false
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    property int selected: -1
    property var running: []
    property string message: ""

    function toggle() {
        if (visible) { hide(); return; }
        selected = -1;
        message = "";
        running = Apps.entries.map(app => !!Logic.findWindow(app, Workspace.stackingOrder));
        const pointer = Workspace.cursorPos;
        const output = Workspace.screens.find(screen => {
            const r = screen.geometry;
            return pointer.x >= r.x && pointer.x < r.x + r.width
                && pointer.y >= r.y && pointer.y < r.y + r.height;
        }) || Workspace.activeScreen;
        const area = Workspace.clientArea(KWin.FullScreenArea, output, Workspace.currentDesktop);
        x = Math.max(area.x, Math.min(pointer.x - width / 2, area.x + area.width - width));
        y = Math.max(area.y, Math.min(pointer.y - height / 2, area.y + area.height - height));
        show();
        requestActivate();
        surface.forceActiveFocus();
        opening.restart();
    }

    function choose(index) {
        if (index < 0 || index >= apps.count) { hide(); return; }
        const app = Apps.entries[index];
        const launcher = apps.itemAt(index).launcher;
        // Hide before focusing, so dismissing the popup cannot steal focus back.
        hide();
        const ok = Logic.activate(app, Workspace, () => launcher.count === 1 && launcher.trigger(0, "", null));
        if (!ok) {
            toggle();
            message = app.label + " is unavailable";
        }
    }

    ShortcutHandler {
        name: "MXRingToggle"
        text: "Open MX App Ring"
        sequence: "Meta+Alt+Space"
        onActivated: ring.toggle()
    }

    // Dismiss if another app gains focus while the wheel is open.
    Connections {
        target: Workspace
        function onWindowActivated() { if (ring.visible) ring.hide(); }
    }

    Item {
        id: surface
        anchors.fill: parent
        focus: true
        NumberAnimation { id: opening; target: surface; property: "scale"; from: 0.88; to: 1; duration: 130; easing.type: Easing.OutCubic }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) ring.hide();
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) ring.choose(event.key - Qt.Key_1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (ring.selected >= 0) ring.choose(ring.selected);
            } else if ([Qt.Key_Tab, Qt.Key_Right, Qt.Key_Down, Qt.Key_Left, Qt.Key_Up].includes(event.key)) {
                const step = [Qt.Key_Left, Qt.Key_Up].includes(event.key) || (event.modifiers & Qt.ShiftModifier) ? -1 : 1;
                ring.selected = ring.selected < 0 ? (step > 0 ? 0 : apps.count - 1)
                    : (ring.selected + step + apps.count) % apps.count;
            } else { event.accepted = false; return; }
            event.accepted = true;
        }

        Canvas {
            id: wheel
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const step = 2 * Math.PI / apps.count;
                for (let i = 0; i < apps.count; ++i) {
                    const a = i * step - Math.PI / 2 - step / 2 + 0.018;
                    const b = a + step - 0.036;
                    ctx.beginPath();
                    ctx.arc(220, 220, 204, a, b);
                    ctx.arc(220, 220, 80, b, a, true);
                    ctx.closePath();
                    ctx.fillStyle = i === ring.selected ? "#335c85" : "#ee202633";
                    ctx.fill();
                    ctx.strokeStyle = i === ring.selected ? "#8acaff" : "#485262";
                    ctx.lineWidth = i === ring.selected ? 2 : 1;
                    ctx.stroke();
                }
            }
            Connections {
                target: ring
                function onSelectedChanged() { wheel.requestPaint(); }
            }
        }

        Repeater {
            id: apps
            model: Apps.entries
            delegate: Item {
                id: appItem
                required property int index
                required property var modelData
                property alias launcher: launcherModel
                width: 116
                height: 90
                x: 220 + 142 * Math.sin(index * 2 * Math.PI / apps.count) - width / 2
                y: 220 - 142 * Math.cos(index * 2 * Math.PI / apps.count) - height / 2
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                Accessible.description: ring.running[index] ? "Switch to open window" : "Open application"
                Accessible.onPressAction: ring.choose(index)

                Kicker.SimpleFavoritesModel { id: launcherModel; favorites: [modelData.desktop] }
                Kirigami.Icon {
                    width: 38; height: 38
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: launcherModel.count ? launcherModel.data(launcherModel.index(0, 0), Qt.DecorationRole) : "application-x-executable"
                }
                Text {
                    y: 45; width: parent.width
                    text: appItem.modelData.label
                    color: "#f5f7fc"
                    font.pixelSize: 13; font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
                Text {
                    y: 65; width: parent.width
                    text: (appItem.index + 1) + (ring.running[appItem.index] ? "  •  Open" : "")
                    color: ring.running[appItem.index] ? "#99d7af" : "#a6b1c2"
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 146; height: 146; radius: 73
            color: "#f21a202c"
            border.color: "#485262"
            Text {
                anchors.centerIn: parent
                width: 134
                text: ring.message || (ring.selected < 0 ? "MX APP RING\n\nChoose an app\nEsc to close"
                    : Apps.entries[ring.selected].label + "\n\n" + (ring.running[ring.selected] ? "Switch to app" : "Open app"))
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: "#e5edf7"
                font.pixelSize: 12
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPositionChanged: mouse => ring.selected = Logic.sectorAt(mouse.x - 220, mouse.y - 220, apps.count, 80, 204)
            onExited: ring.selected = -1
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) ring.hide();
                else ring.choose(Logic.sectorAt(mouse.x - 220, mouse.y - 220, apps.count, 80, 204));
            }
        }
    }
}
