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

import QtQuick 2.9
import org.asteroid.controls 1.0
import org.asteroid.utils 1.0
import org.asteroid.meteormatch 1.0

Application {
    id: app

    centerColor: "#1A1A2E"
    outerColor:  "#0A0A14"

    // ── Save / load ───────────────────────────────────────────────────────────
    function saveResult() {
        GameStorage.dirty      = true
        GameStorage.board      = board.boardToJson()
        GameStorage.score      = board.score
        GameStorage.panX       = board.panX
        GameStorage.panY       = board.panY
        GameStorage.pendingTap = ""
        GameStorage.dirty      = false
    }

    function loadOrInit() {
        var savedBoard = GameStorage.board
        var savedScore = GameStorage.score
        var dirty      = GameStorage.dirty
        var pending    = GameStorage.pendingTap

        if (dirty && savedBoard !== "" && pending !== "") {
            // Power-loss recovery — replay last tap on pre-tap board
            board.score = savedScore
            board.loadBoard(savedBoard)
            var parts = pending.split(",")
            board.handleTap(parseInt(parts[0]), parseInt(parts[1]))
        } else if (savedBoard !== "") {
            // Restore saved game including viewport position
            board.score   = savedScore
            board.panning = true        // suppress pan spring while placing saved pan values
            board.panX    = GameStorage.panX
            board.panY    = GameStorage.panY
            board.loadBoard(savedBoard) // loadBoard also sets panning=true; readyTimer clears it
        } else {
            board.initBoard()
        }
    }

    function newGame() {
        board.gameState = "playing"
        board.score     = 0
        GameStorage.clear()
        board.initBoard()
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Game board ────────────────────────────────────────────────────────────
    GameBoard {
        id: board

        onBoardChanged: saveResult()
        onScoreDelta:   {}
        onTapStarted: {
            GameStorage.dirty      = true
            GameStorage.pendingTap = col + "," + row
            GameStorage.score      = board.score
        }
        onGameOver: {
            if (board.score > GameStorage.highScore)
                GameStorage.highScore = board.score
                gameOverOverlay.won     = false
                gameOverOverlay.visible = true
        }
        onGameWon: {
            if (board.score > GameStorage.highScore)
                GameStorage.highScore = board.score
                gameOverOverlay.won     = true
                gameOverOverlay.visible = true
        }
        onLongPressed: resetOverlay.visible = true
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── HUD — score ───────────────────────────────────────────────────────────
    Label {
        id: scoreLabel
        anchors {
            top:              parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin:        Dims.l(4)
        }
        text:           board.score
        font.pixelSize: Dims.l(8)
        visible:        board.gameState !== "gameover"
        color:          "#E0E0E0"
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Reset overlay (long press) ────────────────────────────────────────────
    Item {
        id: resetOverlay
        anchors.fill: parent
        visible:      false

        Rectangle {
            anchors.fill: parent
            color:        "#CC000000"
        }

        // Tap outside the button to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked:    resetOverlay.visible = false
        }

        Column {
            anchors.centerIn: parent
            spacing:          Dims.l(4)

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "Reset Board"
                text:           qsTrId("id-reset-board")
                font.pixelSize: Dims.l(9)
                color:          "#E0E0E0"
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "Start a new game?"
                text:           qsTrId("id-start-new-game")
                font.pixelSize: Dims.l(6)
                color:          "#888888"
            }

            // Confirm button — explicit tap required so accidental long press
            // doesn't silently destroy progress
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width:  Dims.w(55)
                height: Dims.l(16)
                radius: Dims.l(3)
                color:  "#D55E00"

                Label {
                    anchors.centerIn: parent
                    //% "New Game"
                    text:           qsTrId("id-new-game")
                    font.pixelSize: Dims.l(7)
                    color:          "white"
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
    // ────────────────────────────────────────────────────────────────────────

    // ── Game over overlay ─────────────────────────────────────────────────────
    Item {
        id: gameOverOverlay
        anchors.fill: parent
        visible:      false
        property bool won: false

        Rectangle {
            anchors.fill: parent
            color:        "#CC000000"
        }

        Column {
            anchors.centerIn: parent
            spacing:          Dims.l(3)

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "You Won!"
                text: gameOverOverlay.won ? qsTrId("id-you-won")
                //% "Game Over!"
                : qsTrId("id-game-over")
                font.pixelSize: Dims.l(10)
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "Score"
                text:           qsTrId("id-score") + ": " + board.score
                font.pixelSize: Dims.l(8)
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "Best"
                text:           qsTrId("id-best") + ": " + GameStorage.highScore
                font.pixelSize: Dims.l(7)
                color:          "#AAAAAA"
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "Tap to play again"
                text:           qsTrId("id-tap-to-play-again")
                font.pixelSize: Dims.l(6)
                color:          "#888888"
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                gameOverOverlay.visible = false
                newGame()
            }
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    Component.onCompleted: loadOrInit()
}
