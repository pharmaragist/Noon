import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import qs.common
import qs.common.widgets
import qs.common.functions
import qs.common.utils
import qs.services

Item {
    id: root


    property color activeColor: isInverted ? Colors.m3.m3inverseOnSurface : Colors.m3.m3onSurface
    property color bgColor: isInverted ? Colors.m3.m3inverseSurface : "transparent"

    Behavior on activeColor {
        CAnim {}
    }
    Behavior on bgColor {
        CAnim {}
    }


    property bool isPlaying: false
    property bool isGameOver: false
    property real gameSpeed: 6.0
    property real score: 0
    property real highScore: {
        var val = parseFloat(Paths.methods.readFile(saveFile));
        if (!isNaN(val))
            return val;
        else
            return 0;
    }
    property bool isDucking: false
    property bool isInverted: false

    property bool _previousDnd: false


    property real dinoY: 0
    property real dinoVelocityY: 0
    property real gravity: 0.8
    property real duckGravity: 1.5
    property real jumpForce: -13.0


    property var obstacles: []
    property real obstacleTimer: 0


    property var clouds: []
    property real cloudTimer: 0
    property real groundX: 0


    property int frameCount: 0
    readonly property string assetsFolder: Paths.assets + "/dino/"
    readonly property string saveFile: Paths.methods.trim(Paths.standard.home) + "/.dino_highscore.txt"
    implicitWidth: Math.max(250, parent.width * 0.8)
    implicitHeight: 200
    clip: true
    focus: true

    function startGame() {
        if (isGameOver) {
            score = 0;
            obstacles = [];
            clouds = [];
            groundX = 0;
            gameSpeed = 6.0;
            frameCount = 0;
            isInverted = false;
        }

        isPlaying = true;
        isGameOver = false;
        dinoY = 0;
        dinoVelocityY = 0;
        gameLoop.start();
    }

    function writeScore(score) {
        Paths.methods.createFileWith(saveFile, score);
    }

    function gameOver() {
        isPlaying = false;
        isGameOver = true;
        gameLoop.stop();

        if (score > highScore) {
            highScore = score;
            writeScore(Math.floor(highScore).toString());
        }
    }

    function jump() {
        if (dinoY === 0 && isPlaying) {
            dinoVelocityY = jumpForce;
        } else if (!isPlaying) {
            startGame();
        }
    }

    Shortcut {
        sequence: "Space"
        onActivated: {
            root.forceActiveFocus();
            root.jump();
        }
    }
    Shortcut {
        sequence: "Up"
        onActivated: {
            root.forceActiveFocus();
            root.jump();
        }
    }

    Keys.onDownPressed: event => {
        if (event.isAutoRepeat)
            return;
        if (root.isPlaying)
            root.isDucking = true;
    }

    Keys.onReleased: event => {
        if (event.isAutoRepeat)
            return;
        if (event.key === Qt.Key_Down)
            root.isDucking = false;
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            root.jump();
        }
    }


    Rectangle {
        anchors.fill: parent
        color: root.bgColor
        z: -1
    }


    Item {
        visible: root.isPlaying || root.isGameOver
        width: parent.width
        height: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        clip: true

        Image {
            x: -root.groundX
            width: 2400
            height: 24
            source: root.assetsFolder + "/dino_ground.png"
            fillMode: Image.PreserveAspectFit

            layer.enabled: true

            layer.effect: Colouriser {
                colorizationColor: root.activeColor
                brightness: 1
            }
        }

        Image {
            x: 2400 - root.groundX
            width: 2400
            height: 24
            source: root.assetsFolder + "/dino_ground.png"
            fillMode: Image.PreserveAspectFit

            layer.enabled: true
            layer.effect: Colouriser {
                colorizationColor: root.activeColor
                brightness: 1
            }
        }
    }


    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.isPlaying && !root.isGameOver
        spacing: Padding.verylarge

        Item {
            Layout.alignment: Qt.AlignHCenter
            width: 250
            height: 109.375

            Image {
                anchors.centerIn: parent
                width: 250
                height: 109.375
                source: root.assetsFolder + "/dino.png"
                fillMode: Image.PreserveAspectFit

                layer.enabled: true
                layer.effect: Colouriser {
                    colorizationColor: root.activeColor
                    brightness: 1
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("All up to date!")
            color: root.activeColor
        }
    }


    Item {
        anchors.fill: parent
        visible: root.isPlaying || root.isGameOver


        Repeater {
            model: root.clouds
            Image {
                x: modelData.x
                y: modelData.y
                width: 92
                height: 27
                source: root.assetsFolder + "/dino_cloud.png"
                fillMode: Image.PreserveAspectFit

                layer.enabled: true
                layer.effect: Colouriser {
                    colorizationColor: root.activeColor
                    brightness: 1
                }
            }
        }


        Image {
            id: dino
            width: root.isDucking ? 59 : 44
            height: root.isDucking ? 30 : 47
            source: {
                if (root.isGameOver)
                    return root.assetsFolder + "/dino_crash.png";
                if (root.dinoY < 0)
                    return root.assetsFolder + "/dino_stand.png";
                if (root.isDucking)
                    return Math.floor(root.frameCount / 5) % 2 === 0 ? root.assetsFolder + "/dino_duck1.png" : root.assetsFolder + "/dino_duck2.png";
                return Math.floor(root.frameCount / 5) % 2 === 0 ? root.assetsFolder + "/dino_run1.png" : root.assetsFolder + "/dino_run2.png";
            }
            x: 30
            y: parent.height - 30 - height + root.dinoY

            layer.enabled: true
            layer.effect: Colouriser {
                colorizationColor: root.activeColor
                sourceColor: "white"
            }
        }


        StyledText {
            text: "HI " + ("00000" + Math.floor(root.highScore)).slice(-5) + "  " + ("00000" + Math.floor(root.score)).slice(-5)
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            font.pixelSize: Fonts.sizes.large
            color: root.activeColor
            Component.onCompleted: font.features = {
                "tnum": 1
            }
        }


        Repeater {
            model: root.obstacles
            Image {
                width: modelData.width
                height: modelData.height
                source: {
                    if (modelData.type === "bird")
                        return Math.floor(root.frameCount / 7) % 2 === 0 ? root.assetsFolder + "/bird_1.png" : root.assetsFolder + "/bird_2.png";
                    return modelData.type === "small" ? root.assetsFolder + "/cactus_small.png" : root.assetsFolder + "/cactus_large.png";
                }
                x: modelData.x
                y: parent.height - 30 - height - (modelData.yOffset || 0)

                layer.enabled: true
                layer.effect: Colouriser {
                    colorizationColor: root.activeColor
                    sourceColor: "white"
                }
            }
        }
    }


    StyledText {
        visible: root.isGameOver && Math.floor(root.score) < 99999
        text: "G A M E   O V E R\nClick to restart"
        horizontalAlignment: Text.AlignHCenter
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        font.pixelSize: Fonts.sizes.huge
        color: root.activeColor
    }


    StyledText {
        visible: root.isGameOver && Math.floor(root.score) >= 99999
        text: "Y O U   W I N !\nNow go touch grass"
        horizontalAlignment: Text.AlignHCenter
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        font.pixelSize: Fonts.sizes.huge
        color: root.activeColor
    }

    Timer {
        id: gameLoop
        interval: 16
        repeat: true
        onTriggered: {
            root.dinoVelocityY += (root.isDucking ? root.duckGravity : root.gravity);
            root.dinoY += root.dinoVelocityY;
            if (root.dinoY > 0) {
                root.dinoY = 0;
                root.dinoVelocityY = 0;
            }

            root.frameCount++;
            root.score += 0.15;


            root.groundX = (root.groundX + root.gameSpeed) % 2400;

            var newClouds = [];
            for (var c = 0; c < root.clouds.length; c++) {
                var cloud = root.clouds[c];
                cloud.x -= root.gameSpeed * 0.25;
                if (cloud.x + 92 > 0)
                    newClouds.push(cloud);
            }
            root.clouds = newClouds;

            root.cloudTimer++;
            if (root.cloudTimer > 150 + Math.random() * 200) {
                root.cloudTimer = 0;
                root.clouds.push({
                    x: root.width,
                    y: 10 + Math.random() * 80
                });
            }


            root.isInverted = (Math.floor(root.score / 700) % 2 === 1);

            if (Math.floor(root.score) >= 99999) {
                root.score = 99999;
                root.gameOver();
                return;
            }

            if (Math.floor(root.score) > 0 && Math.floor(root.score) % 100 === 0) {
                root.gameSpeed += 0.05;
            }

            var newObstacles = [];
            for (var i = 0; i < root.obstacles.length; i++) {
                var obs = root.obstacles[i];
                obs.x -= root.gameSpeed;

                var dWidth = root.isDucking ? 59 : 44;
                var dHeight = root.isDucking ? 30 : 47;
                var dRect = {
                    x: 30 + 10,
                    y: parent.height - 30 - dHeight + root.dinoY + 10,
                    w: dWidth - 20,
                    h: dHeight - 15
                };
                var oRect = {
                    x: obs.x + 8,
                    y: parent.height - 30 - obs.height - (obs.yOffset || 0) + 8,
                    w: obs.width - 16,
                    h: obs.height - 16
                };

                if (dRect.x < oRect.x + oRect.w && dRect.x + dRect.w > oRect.x && dRect.y < oRect.y + oRect.h && dRect.y + dRect.h > oRect.y) {
                    root.gameOver();
                    return;
                }

                if (obs.x + obs.width > 0) {
                    newObstacles.push(obs);
                }
            }
            root.obstacles = newObstacles;

            root.obstacleTimer++;
            if (root.obstacleTimer > 60 + Math.random() * 80) {
                root.obstacleTimer = 0;
                var canSpawnBird = root.score > 300;
                var spawnType = (canSpawnBird && Math.random() > 0.7) ? "bird" : (Math.random() > 0.5 ? "small" : "large");
                var newObs = {
                    x: root.width
                };
                if (spawnType === "bird") {
                    newObs.type = "bird";
                    newObs.width = 46;
                    newObs.height = 40;
                    var heights = [10, 35, 60];
                    newObs.yOffset = heights[Math.floor(Math.random() * heights.length)];
                } else if (spawnType === "small") {
                    newObs.type = "small";
                    newObs.width = 34;
                    newObs.height = 35;
                    newObs.yOffset = 0;
                } else {
                    newObs.type = "large";
                    newObs.width = 25;
                    newObs.height = 50;
                    newObs.yOffset = 0;
                }
                root.obstacles.push(newObs);
            }
        }
    }
    component Colouriser: MultiEffect {
        property color sourceColor: "black"

        colorization: 1
        brightness: 1 - sourceColor.hslLightness

        Behavior on colorizationColor {
            CAnim {}
        }
    }
}
