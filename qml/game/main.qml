/*
 * Copyright (C) 2026 - Timo Könnecke <github.com/moWerk>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.6
import QtGraphicalEffects 1.0
import "."

// SailfishOS: Application of org.asteroid.utils draws a radial
// background from centerColor to outerColor. Here a plain Item does the same.
Item {
    id: app
    anchors.fill: parent

    property color centerColor: "#1A1A2E"
    property color outerColor: "#0A0A14"

    RadialGradient {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: app.centerColor }
            GradientStop { position: 0.5; color: app.outerColor }
        }
    }

    // ── Save / load
    function saveResult() {
        GameStorage.dirty = true
        GameStorage.board = board.boardToJson()
        GameStorage.score = board.score
        GameStorage.panX = board.panX
        GameStorage.panY = board.panY
        GameStorage.pendingTap = ""
        GameStorage.dirty = false
    }

    function loadOrInit() {
        var savedBoard = GameStorage.board
        var savedScore = GameStorage.score
        var dirty = GameStorage.dirty
        var pending = GameStorage.pendingTap

        if (dirty && savedBoard !== "" && pending !== "") {
            // Power-loss recovery — replay last tap on pre-tap board
            board.score = savedScore
            board.loadBoard(savedBoard)
            var parts = pending.split(",")
            board.handleTap(parseInt(parts[0]), parseInt(parts[1]))
        } else if (savedBoard !== "") {
            // Restore saved game including viewport position
            board.score = savedScore
            board.panning = true
            board.panX = GameStorage.panX
            board.panY = GameStorage.panY
            board.loadBoard(savedBoard)
        } else {
            board.initBoard()
        }
        showTitle()
    }

    function showTitle() {
        titleScreen.opacity = 1
        titleScreen.visible = true
    }

    function resetBoard() {
        board.gameState = "playing"
        board.score = 0
        GameStorage.clear()
        board.initBoard()
    }

    function newGame() {
        resetBoard()
        showTitle()
    }

    // ── Game board
    GameBoard {
        id: board

        onBoardChanged: saveResult()
        onScoreDelta: {}
        onTapStarted: {
            GameStorage.dirty = true
            GameStorage.pendingTap = col + "," + row
            GameStorage.score = board.score
        }
        onGameOver: {
            if (board.score > GameStorage.highScore)
                GameStorage.highScore = board.score
            gameOverOverlay.won = false
            gameOverOverlay.visible = true
        }
        onGameWon: {
            if (board.score > GameStorage.highScore)
                GameStorage.highScore = board.score
            gameOverOverlay.won = true
            gameOverOverlay.visible = true
        }
        onLongPressed: resetOverlay.visible = true
    }

    // ── Score HUD
    Label {
        id: scoreLabel
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            // SailfishOS: below the camera notch of a phone like the Jolla C2
            topMargin: Dims.l(3) + Dims.l(6)
        }
        text: board.score
        font {
            pixelSize: Dims.l(12)
            family: "Xolonium"
            styleName: "Bold"

        }
        visible: board.gameState !== "gameover"
        color: "#E0E0E0"
        style: Text.Outline
        styleColor: "black"
    }

    // ── Reset overlay (long press)
    Item {
        id: resetOverlay
        anchors.fill: parent
        visible: false

        Rectangle {
            anchors.fill: parent
            color: "#CC000000"
        }

        // Tap outside button to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: resetOverlay.visible = false
        }

        Column {
            anchors.centerIn: parent
            spacing: Dims.l(4)

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "Reset Board"
                text: qsTrId("id-reset-board")
                font.pixelSize: Dims.l(9)
                color: "#E0E0E0"
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "Start a new game?"
                text: qsTrId("id-start-new-game")
                font.pixelSize: Dims.l(6)
                color: "#888888"
            }

            // Explicit confirm required — prevents accidental long press destroying progress
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Dims.w(55)
                height: Dims.l(16)
                radius: Dims.l(3)
                color: "#D55E00"

                Label {
                    anchors.centerIn: parent
                    //% "New Game"
                    text: qsTrId("id-new-game")
                    font.pixelSize: Dims.l(7)
                    color: "white"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        resetOverlay.visible = false
                        newGame()
                    }
                }
            }
        }
    }

    // ── Game over / win overlay
    Item {
        id: gameOverOverlay
        anchors.fill: parent
        visible: false
        property bool won: false

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        // SailfishOS: the cover art, dimmed to half (see the title screen)
        Image {
            anchors.fill: parent
            source: "img/title-art.jpg"
            fillMode: Image.PreserveAspectCrop
            opacity: 0.5
        }

        // SailfishOS: laid out like the title screen, in its font: the verdict
        // where the title sits, the scores below it with room to breathe, the
        // prompt where "Tap to play" sits.
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: parent.height * 0.25 - Dims.l(12)
            //% "You Won!"
            text: gameOverOverlay.won ? qsTrId("id-you-won")
            //% "Game Over!"
            : qsTrId("id-game-over")
            font { family: "Fyodor"; pixelSize: Dims.l(18) }
            color: "#E0E0E0"
            style: Text.Outline
            styleColor: "black"
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: parent.height * 0.5
            spacing: Dims.l(8)

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "Score"
                text: qsTrId("id-score") + ": " + board.score
                font { family: "Fyodor"; pixelSize: Dims.l(12) }
                color: "#E0E0E0"
                style: Text.Outline
                styleColor: "black"
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "Best"
                text: qsTrId("id-best") + ": " + GameStorage.highScore
                font { family: "Fyodor"; pixelSize: Dims.l(9) }
                color: "#BBBBBB"
                style: Text.Outline
                styleColor: "black"
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: parent.height * 0.745
            //% "Tap to play again"
            text: qsTrId("id-tap-to-play-again")
            font { family: "Fyodor"; pixelSize: Dims.l(10) }
            color: "#E0E0E0"
            style: Text.Outline
            styleColor: "black"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                gameOverOverlay.visible = false
                newGame()
            }
        }
    }

    // ── Title screen
    // SailfishOS: shown on every start and before every new game; a saved
    // board waits underneath and survives the title. Cover art
    // (AI-generated with Grok from the author's prompt; see img/README); a tap
    // anywhere fades it out to the new board.
    Item {
        id: titleScreen
        anchors.fill: parent
        visible: false
        opacity: 1
        Behavior on opacity { NumberAnimation { duration: 1000; easing.type: Easing.InOutQuad } }
        onOpacityChanged: if (opacity === 0) visible = false

        Image {
            anchors.fill: parent
            source: "img/title-art.jpg"
            fillMode: Image.PreserveAspectCrop
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: parent.height * 0.25 - Dims.l(12)
            text: "METEOR\nMATCH"
            horizontalAlignment: Text.AlignHCenter
            font { family: "Fyodor"; pixelSize: Dims.l(24) }
            color: "#E0E0E0"
            style: Text.Outline
            styleColor: "black"
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: parent.height * 0.745
            //% "Tap to play"
            text: qsTrId("id-tap-to-play")
            font { family: "Fyodor"; pixelSize: Dims.l(12) }
            color: "#E0E0E0"
            style: Text.Outline
            styleColor: "black"
        }

        MouseArea {
            anchors.fill: parent
            enabled: titleScreen.opacity === 1
            onClicked: {
                // A finished game restored at start waits underneath with its
                // game over overlay; the tap on the title already means "play".
                if (gameOverOverlay.visible) {
                    gameOverOverlay.visible = false
                    resetBoard()
                }
                titleScreen.opacity = 0
            }
        }
    }

    Component.onCompleted: loadOrInit()
}
