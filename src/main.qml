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
import Nemo.Configuration 1.0

Application {
    id: app

    centerColor: "#1A1A2E"
    outerColor:  "#0A0A14"

    // ── Persistent state ─────────────────────────────────────────────────────
    ConfigurationValue {
        id: savedBoard
        key:          "/asteroid/apps/meteormatch/boardState"
        defaultValue: ""
    }

    ConfigurationValue {
        id: savedPendingTap
        key:          "/asteroid/apps/meteormatch/pendingTap"
        defaultValue: ""
    }

    ConfigurationValue {
        id: savedDirty
        key:          "/asteroid/apps/meteormatch/boardDirty"
        defaultValue: false
    }

    ConfigurationValue {
        id: savedScore
        key:          "/asteroid/apps/meteormatch/score"
        defaultValue: 0
    }

    ConfigurationValue {
        id: highScore
        key:          "/asteroid/apps/meteormatch/highScore"
        defaultValue: 0
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Save / load ───────────────────────────────────────────────────────────
    function saveMove(col, row) {
        savedDirty.value      = true
        savedPendingTap.value = col + "," + row
    }

    function saveResult() {
        savedBoard.value      = board.boardToJson()
        savedScore.value      = board.score
        savedPendingTap.value = ""
        savedDirty.value      = false
    }

    function loadOrInit() {
        if (savedDirty.value && savedBoard.value !== "" && savedPendingTap.value !== "") {
            // Power-loss recovery: replay last move on the pre-move board
            board.loadBoard(savedBoard.value)
            board.score = savedScore.value
            var parts = savedPendingTap.value.split(",")
            board.handleTap(parseInt(parts[0]), parseInt(parts[1]))
        } else if (savedBoard.value !== "") {
            board.loadBoard(savedBoard.value)
            board.score = savedScore.value
        } else {
            board.initBoard()
            board.score = 0
        }
    }

    function newGame() {
        board.score      = 0
        board.gameState  = "playing"
        board.initBoard()
        savedBoard.value      = ""
        savedPendingTap.value = ""
        savedDirty.value      = false
        savedScore.value      = 0
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Game board ────────────────────────────────────────────────────────────
    GameBoard {
        id: board

        onBoardChanged:    saveResult()
        onScoreChanged:    {}   // score written in saveResult() after move settles
        onGameOver: {
            if (board.score > highScore.value)
                highScore.value = board.score
            gameOverOverlay.visible = true
        }
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
        text:            board.score
        font.pixelSize:  Dims.l(8)
        visible:         board.gameState !== "gameover"
        color:           "#E0E0E0"
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Game over overlay ─────────────────────────────────────────────────────
    Item {
        id: gameOverOverlay
        anchors.fill: parent
        visible:      false

        Rectangle {
            anchors.fill: parent
            color:        "#CC000000"
        }

        Column {
            anchors.centerIn: parent
            spacing:          Dims.l(3)

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "Game Over"
                text:           qsTrId("id-game-over")
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
                text:           qsTrId("id-best") + ": " + highScore.value
                font.pixelSize: Dims.l(7)
                color:          "#AAAAAA"
            }

            // Tap anywhere below to restart — no dedicated button needed on watch
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
