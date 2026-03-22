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
import org.asteroid.utils 1.0

Item {
    id: gameBoard

    // ── Public interface ─────────────────────────────────────────────────────
    property string gameState: "playing"   // "playing" | "zooming" | "gameover"
    property int    score:     0

    signal scoreChanged(int delta)
    signal gameOver()
    signal boardChanged()    // emitted after every settled move — triggers save
    // ────────────────────────────────────────────────────────────────────────

    anchors.fill: parent

    // ── Board constants ──────────────────────────────────────────────────────
    readonly property int cols:      10
    readonly property int rows:      12
    readonly property int tileCount: cols * rows   // 120

    // Tile pixel size — board fills a 5×5 viewport on screen
    readonly property int tileSize:  Math.floor(Math.min(parent.width, parent.height) / 5)

    // Full board pixel dimensions
    readonly property int boardPixelW: cols * tileSize
    readonly property int boardPixelH: rows * tileSize

    // Viewport pixel size (5×5 tiles)
    readonly property int vpSize: tileSize * 5
    // ────────────────────────────────────────────────────────────────────────

    // ── Pan state ────────────────────────────────────────────────────────────
    property real panX: 0   // board offset — always <= 0, >= -(boardPixelW - vpSize)
    property real panY: 0

    readonly property real panMinX: -(boardPixelW - vpSize)
    readonly property real panMinY: -(boardPixelH - vpSize)

    function clampPan(px, py) {
        return {
            x: Math.max(panMinX, Math.min(0, px)),
            y: Math.max(panMinY, Math.min(0, py))
        }
    }

    Behavior on panX { SpringAnimation { spring: 2.5; damping: 0.5 } }
    Behavior on panY { SpringAnimation { spring: 2.5; damping: 0.5 } }
    // ────────────────────────────────────────────────────────────────────────

    // ── Board model ───────────────────────────────────────────────────────────
    // Each entry: { type: int 0-2, dying: bool }
    // type -1 = empty slot
    ListModel { id: boardModel }

    function boardIndex(col, row) { return col + row * cols }

    function cellType(col, row) {
        if (col < 0 || col >= cols || row < 0 || row >= rows) return -1
        return boardModel.get(boardIndex(col, row)).type
    }

    function initBoard() {
        boardModel.clear()
        for (var i = 0; i < tileCount; i++)
            boardModel.append({ type: Math.floor(Math.random() * 3), dying: false })
    }

    function loadBoard(jsonStr) {
        var arr = JSON.parse(jsonStr)
        boardModel.clear()
        for (var i = 0; i < tileCount; i++)
            boardModel.append({ type: arr[i], dying: false })
    }

    function boardToJson() {
        var arr = []
        for (var i = 0; i < tileCount; i++)
            arr.push(boardModel.get(i).type)
        return JSON.stringify(arr)
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Flood fill ────────────────────────────────────────────────────────────
    // Returns { count, indices, anyOutsideViewport }
    property var floodVisited: []

    function floodFill(col, row) {
        var targetType = cellType(col, row)
        if (targetType < 0) return { count: 0, indices: [], anyOutsideViewport: false }

        floodVisited = new Array(tileCount)
        var indices = []
        floodStep(col, row, targetType, indices)
        if (indices.length < 2) return { count: 0, indices: [], anyOutsideViewport: false }

        // Check if any removed tile is outside current viewport
        var vpLeft   = Math.floor(-panX / tileSize)
        var vpTop    = Math.floor(-panY / tileSize)
        var vpRight  = vpLeft + 5
        var vpBottom = vpTop  + 5
        var outside  = false
        for (var i = 0; i < indices.length; i++) {
            var c = indices[i] % cols
            var r = Math.floor(indices[i] / cols)
            if (c < vpLeft || c >= vpRight || r < vpTop || r >= vpBottom) {
                outside = true
                break
            }
        }
        return { count: indices.length, indices: indices, anyOutsideViewport: outside }
    }

    function floodStep(col, row, targetType, indices) {
        if (col < 0 || col >= cols || row < 0 || row >= rows) return
        var idx = boardIndex(col, row)
        if (floodVisited[idx]) return
        if (boardModel.get(idx).type !== targetType) return
        floodVisited[idx] = true
        indices.push(idx)
        floodStep(col + 1, row,     targetType, indices)
        floodStep(col - 1, row,     targetType, indices)
        floodStep(col,     row + 1, targetType, indices)
        floodStep(col,     row - 1, targetType, indices)
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Gravity ───────────────────────────────────────────────────────────────
    // Called after dying tiles are cleared. Drops tiles down within each column.
    function applyGravity() {
        for (var col = 0; col < cols; col++) {
            var writeRow = rows - 1
            for (var row = rows - 1; row >= 0; row--) {
                var t = cellType(col, row)
                if (t >= 0) {
                    if (writeRow !== row) {
                        boardModel.setProperty(boardIndex(col, writeRow), "type", t)
                        boardModel.setProperty(boardIndex(col, row),      "type", -1)
                    }
                    writeRow--
                }
            }
            // Clear remaining top slots
            for (var r = writeRow; r >= 0; r--)
                boardModel.setProperty(boardIndex(col, r), "type", -1)
        }
        collapseColumns()
    }

    // Slide non-empty columns left to fill gaps
    function collapseColumns() {
        var writeCol = 0
        for (var col = 0; col < cols; col++) {
            if (cellType(col, rows - 1) >= 0) {
                if (writeCol !== col) {
                    for (var row = 0; row < rows; row++) {
                        boardModel.setProperty(boardIndex(writeCol, row), "type", cellType(col, row))
                        boardModel.setProperty(boardIndex(col,      row), "type", -1)
                    }
                }
                writeCol++
            }
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Refill (two-pair penalty) ─────────────────────────────────────────────
    // Drops two new random tiles into the exact two columns from which the pair
    // was removed. Gravity has already run — tiles land at lowest empty slot.
    function refillPenalty(indices) {
        var affectedCols = []
        for (var i = 0; i < indices.length; i++) {
            var c = indices[i] % cols
            if (affectedCols.indexOf(c) < 0)
                affectedCols.push(c)
        }
        // Clamp to two columns max (pair can only span two cols or sit in one)
        var targetCols = affectedCols.slice(0, 2)
        for (var j = 0; j < targetCols.length; j++) {
            var col = targetCols[j]
            // Find topmost empty row in this column after gravity
            for (var row = 0; row < rows; row++) {
                if (cellType(col, row) < 0) {
                    // Place a random type, guaranteed different from its lower neighbour
                    var lowerType = cellType(col, row + 1)
                    var newType
                    do { newType = Math.floor(Math.random() * 3) } while (newType === lowerType)
                    boardModel.setProperty(boardIndex(col, row), "type", newType)
                    break
                }
            }
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Move handler ─────────────────────────────────────────────────────────
    // Called by tap input. Drives the full turn sequence.
    property int pendingDeaths: 0

    function handleTap(col, row) {
        if (gameState !== "playing") return
        var result = floodFill(col, row)
        if (result.count < 2) return

        // Score: (n-1)^2
        var delta = (result.count - 1) * (result.count - 1)
        score += delta
        scoreChanged(delta)

        // Mark tiles dying — Tile.qml animates and signals deathComplete()
        pendingDeaths = result.count
        for (var i = 0; i < result.count; i++)
            boardModel.setProperty(result.indices[i], "dying", true)

        // Store result for post-death callback
        lastResult = result
    }

    property var lastResult: null

    // Called by each Tile via Connections when deathComplete fires
    function onTileDied() {
        pendingDeaths--
        if (pendingDeaths > 0) return

        // All tiles dead — clear them, apply gravity, maybe refill, then save
        for (var i = 0; i < lastResult.indices.length; i++) {
            boardModel.setProperty(lastResult.indices[i], "type",  -1)
            boardModel.setProperty(lastResult.indices[i], "dying", false)
        }

        applyGravity()

        if (lastResult.count === 2)
            refillPenalty(lastResult.indices)

        if (lastResult.anyOutsideViewport && lastResult.count >= 3)
            triggerZoomOut()

        lastResult = null
        boardChanged()
        checkGameOver()
    }

    function checkGameOver() {
        // Game over when no group of 2+ exists anywhere on the board
        for (var col = 0; col < cols; col++) {
            for (var row = 0; row < rows; row++) {
                var t = cellType(col, row)
                if (t < 0) continue
                if (cellType(col + 1, row) === t) return
                if (cellType(col,     row + 1) === t) return
            }
        }
        gameState = "gameover"
        gameOver()
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Zoom-out ──────────────────────────────────────────────────────────────
    property real zoomScale: 1.0

    function triggerZoomOut() {
        gameState = "zooming"
        zoomOutAnim.start()
    }

    SequentialAnimation {
        id: zoomOutAnim
        NumberAnimation {
            target:   gameBoard
            property: "zoomScale"
            to:       vpSize / Math.max(boardPixelW, boardPixelH)
            duration: 400
            easing.type: Easing.OutCubic
        }
        PauseAnimation { duration: 1200 }
        NumberAnimation {
            target:   gameBoard
            property: "zoomScale"
            to:       1.0
            duration: 350
            easing.type: Easing.InCubic
        }
        onStopped: gameState = "playing"
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Viewport container ───────────────────────────────────────────────────
    Item {
        id: viewport
        width:  vpSize
        height: vpSize
        anchors.centerIn: parent
        clip: true

        // Board container — panned and scaled inside the viewport
        Item {
            id:     boardContainer
            width:  boardPixelW
            height: boardPixelH
            x:      panX
            y:      panY
            scale:  zoomScale
            transformOrigin: Item.TopLeft

            // Tile Repeater — one Tile per model entry
            Repeater {
                id:    tileRepeater
                model: boardModel

                delegate: Tile {
                    id:       tileDelegate
                    tileType: model.type < 0 ? 0 : model.type
                    dying:    model.dying
                    visible:  model.type >= 0
                    width:    tileSize
                    height:   tileSize
                    x:        (index % cols) * tileSize
                    y:        Math.floor(index / cols) * tileSize

                    Connections {
                        target: tileDelegate
                        onDeathComplete: gameBoard.onTileDied()
                    }
                }
            }
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Pan / tap MouseArea ───────────────────────────────────────────────────
    MouseArea {
        anchors.fill: viewport
        enabled: gameState === "playing"

        property real pressX:     0
        property real pressY:     0
        property real pressPanX:  0
        property real pressPanY:  0
        property bool tracking:   false
        property bool axisDecided: false
        readonly property real threshold: Dims.l(3)

        onPressed: {
            pressX      = mouse.x
            pressY      = mouse.y
            pressPanX   = panX
            pressPanY   = panY
            tracking    = false
            axisDecided = false
        }

        onPositionChanged: {
            var dx = mouse.x - pressX
            var dy = mouse.y - pressY

            if (!tracking) {
                if (Math.sqrt(dx * dx + dy * dy) < threshold) return
                tracking        = true
                preventStealing = true
            }

            var clamped = clampPan(pressPanX + dx, pressPanY + dy)
            panX = clamped.x
            panY = clamped.y
        }

        onReleased: {
            if (!tracking) {
                // It was a tap — translate screen coords to board col/row
                var boardX = mouse.x - panX
                var boardY = mouse.y - panY
                var col    = Math.floor(boardX / tileSize)
                var row    = Math.floor(boardY / tileSize)
                handleTap(col, row)
            }
            tracking        = false
            axisDecided     = false
            preventStealing = false
        }

        onCanceled: {
            tracking        = false
            axisDecided     = false
            preventStealing = false
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    Component.onCompleted: initBoard()
}
