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

Item {
    id: gameBoard

    // ── Public interface ─────────────────────────────────────────────────────
    property string gameState:  "playing"  // "playing" | "zooming" | "gameover"
    property int    score:      0
    property bool   boardReady: false

    signal scoreDelta(int delta)
    signal gameOver()
    signal boardChanged()
    // Emitted at the START of a move — before any deaths — so main.qml
    // can write the write-ahead log (dirty=true, pendingTap=col,row).
    // The board in GameStorage at this point is the pre-tap state.
    signal tapStarted(int col, int row)
    // ────────────────────────────────────────────────────────────────────────

    anchors.fill: parent

    // ── Board constants ──────────────────────────────────────────────────────
    readonly property int cols:       10
    readonly property int rows:       12
    readonly property int tileCount:  cols * rows

    readonly property int tileSize:   Math.floor(Math.min(parent.width, parent.height) / 5)
    readonly property int boardPixelW: cols * tileSize
    readonly property int boardPixelH: rows * tileSize
    readonly property int vpSize:     tileSize * 5
    // ────────────────────────────────────────────────────────────────────────

    // ── Pan state ────────────────────────────────────────────────────────────
    property real panX:    0
    property real panY:    0
    property bool panning: false
    property bool zooming: false
    property bool zoomedOut: false

    readonly property int  edgePad:  tileSize
    readonly property real panMinX:  -(boardPixelW - vpSize + edgePad)
    readonly property real panMaxX:   edgePad
    readonly property real panMinY:  -(boardPixelH - vpSize + edgePad)
    readonly property real panMaxY:   edgePad

    property real prePanX: 0
    property real prePanY: 0

    readonly property real zoomScale_target: vpSize / Math.max(boardPixelW, boardPixelH)
    readonly property real centeredPanX:     (vpSize - boardPixelW) / 2
    readonly property real centeredPanY:     (vpSize - boardPixelH) / 2

    function clampPan(px, py) {
        return {
            x: Math.max(panMinX, Math.min(panMaxX, px)),
            y: Math.max(panMinY, Math.min(panMaxY, py))
        }
    }

    function softClampPan(px, py) {
        var o = tileSize * 0.5
        return {
            x: Math.max(panMinX - o, Math.min(panMaxX + o, px)),
            y: Math.max(panMinY - o, Math.min(panMaxY + o, py))
        }
    }

    Behavior on panX {
        enabled: !panning && !zooming
        SpringAnimation { spring: 2.8; damping: 0.28 }
    }
    Behavior on panY {
        enabled: !panning && !zooming
        SpringAnimation { spring: 2.8; damping: 0.28 }
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Board model ───────────────────────────────────────────────────────────
    ListModel { id: boardModel }

    function boardIndex(col, row) { return col + row * cols }

    function cellType(col, row) {
        if (col < 0 || col >= cols || row < 0 || row >= rows) return -1
            return boardModel.get(boardIndex(col, row)).type
    }

    function initBoard() {
        boardReady = false
        score      = 0
        boardModel.clear()
        for (var i = 0; i < tileCount; i++)
            boardModel.append({
                type:      Math.floor(Math.random() * 3),
                              dying:     false,
                              visualRow: Math.floor(i / cols)
            })
            readyTimer.restart()
    }

    function loadBoard(jsonStr) {
        boardReady    = false
        isRestoring   = true
        boardModel.clear()
        var arr = JSON.parse(jsonStr)
        for (var i = 0; i < tileCount; i++)
            boardModel.append({
                type:      arr[i],
                dying:     false,
                visualRow: Math.floor(i / cols)
            })
            readyTimer.restart()
    }

    function boardToJson() {
        var arr = []
        for (var i = 0; i < tileCount; i++)
            arr.push(boardModel.get(i).type)
            return JSON.stringify(arr)
    }

    property bool isRestoring: false

    Timer {
        id: readyTimer
        interval: 32
        repeat:   false
        onTriggered: {
            boardReady = true
            if (!isRestoring)
                boardChanged()   // save fresh board; skip on restore to avoid redundant write
                isRestoring = false
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Viewport helper ───────────────────────────────────────────────────────
    function isAnyOutsideViewport(indices) {
        var vpLeft   = Math.floor(-panX / tileSize)
        var vpTop    = Math.floor(-panY / tileSize)
        var vpRight  = vpLeft + 5
        var vpBottom = vpTop  + 5
        for (var i = 0; i < indices.length; i++) {
            var c = indices[i] % cols
            var r = Math.floor(indices[i] / cols)
            if (c < vpLeft || c >= vpRight || r < vpTop || r >= vpBottom)
                return true
        }
        return false
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Flood fill ────────────────────────────────────────────────────────────
    property var floodVisited: []

    function floodFill(col, row) {
        var targetType = cellType(col, row)
        if (targetType < 0) return { count: 0, indices: [], type: -1 }

        floodVisited = new Array(tileCount)
        var indices = []
        floodStep(col, row, targetType, indices)
        if (indices.length < 2) return { count: 0, indices: [], type: -1 }

        return {
            count:   indices.length,
            indices: indices,
            type:    targetType
        }
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

    // Find cascadeType groups >= 3 that contain at least one tile that moved
    // during gravity. Stationary connected groups of the same color are left alone.
    // movedSet: object used as a hash-set of moved board indices.
    function findCascadeIndices(movedSet) {
        var visited    = new Array(tileCount)
        var allIndices = []

        for (var col = 0; col < cols; col++) {
            for (var row = 0; row < rows; row++) {
                var idx = boardIndex(col, row)
                if (visited[idx]) continue
                    if (cellType(col, row) !== cascadeType) continue

                        var groupIndices = []
                        var groupVisited = new Array(tileCount)
                        floodStepWith(col, row, cascadeType, groupIndices, groupVisited)

                        for (var k = 0; k < groupIndices.length; k++)
                            visited[groupIndices[k]] = true

                            // Only cascade this group if it has >= 3 tiles AND at least one moved
                            if (groupIndices.length >= 3) {
                                var hasMoved = false
                                for (var m = 0; m < groupIndices.length; m++) {
                                    if (movedSet[groupIndices[m]]) { hasMoved = true; break }
                                }
                                if (hasMoved) {
                                    for (var j = 0; j < groupIndices.length; j++)
                                        allIndices.push(groupIndices[j])
                                }
                            }
            }
        }
        return allIndices
    }

    // Like floodStep but uses its own visited array — for cascade scanning
    function floodStepWith(col, row, targetType, indices, visited) {
        if (col < 0 || col >= cols || row < 0 || row >= rows) return
            var idx = boardIndex(col, row)
            if (visited[idx]) return
                if (boardModel.get(idx).type !== targetType) return
                    visited[idx] = true
                    indices.push(idx)
                    floodStepWith(col + 1, row,     targetType, indices, visited)
                    floodStepWith(col - 1, row,     targetType, indices, visited)
                    floodStepWith(col,     row + 1, targetType, indices, visited)
                    floodStepWith(col,     row - 1, targetType, indices, visited)
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Gravity ───────────────────────────────────────────────────────────────
    // Returns movedSet: a hash-object { boardIndex: true } of every tile that
    // changed position. Used by findCascadeIndices to gate cascade eligibility.
    //
    // Sliding animation approach:
    //   Step 1 (this frame): destination slot gets type + visualRow = sourceRow
    //                        → tile appears at source position, invisible-to-visible
    //   Step 2 (next frame, via Qt.callLater): visualRow set to destRow
    //                        → SpringAnimation fires, tile falls to destination
    //
    // Tiles that also shift left via collapseColumns lose the fall animation for
    // that move — they appear at the new column instantly. Y-fall animation is
    // the visually important one.
    function applyGravity(doRefill, refillIndices) {
        var movedSet  = {}
        var deferred  = []   // flat pairs: [idx, targetRow, idx, targetRow, ...]

        for (var col = 0; col < cols; col++) {
            var writeRow = rows - 1
            for (var row = rows - 1; row >= 0; row--) {
                var t = cellType(col, row)
                if (t >= 0) {
                    if (writeRow !== row) {
                        // Step 1: destination slot appears at SOURCE visual row
                        boardModel.setProperty(boardIndex(col, writeRow), "visualRow", row)
                        boardModel.setProperty(boardIndex(col, writeRow), "type",      t)
                        // Clear source slot
                        boardModel.setProperty(boardIndex(col, row), "type",      -1)
                        boardModel.setProperty(boardIndex(col, row), "visualRow", row)
                        // Queue step 2 — deferred to next frame
                        deferred.push(boardIndex(col, writeRow), writeRow)
                        movedSet[boardIndex(col, writeRow)] = true
                    }
                    writeRow--
                }
            }
            for (var r = writeRow; r >= 0; r--) {
                boardModel.setProperty(boardIndex(col, r), "type",      -1)
                boardModel.setProperty(boardIndex(col, r), "visualRow", r)
            }
        }

        if (doRefill)
            refillPenalty(refillIndices)

            collapseColumns(movedSet)

            // Step 2 deferred: trigger SpringAnimation by setting final visualRow.
            // Qt.callLater runs after this JS frame completes, giving the renderer
            // one frame to show tiles at their source position before animating.
            if (deferred.length > 0) {
                var d = deferred
                Qt.callLater(function() {
                    for (var i = 0; i < d.length; i += 2)
                        boardModel.setProperty(d[i], "visualRow", d[i + 1])
                })
            }

            return movedSet
    }

    function collapseColumns(movedSet) {
        var writeCol = 0
        for (var col = 0; col < cols; col++) {
            if (cellType(col, rows - 1) >= 0) {
                if (writeCol !== col) {
                    for (var row = 0; row < rows; row++) {
                        var t = cellType(col, row)
                        if (t >= 0) movedSet[boardIndex(writeCol, row)] = true
                            boardModel.setProperty(boardIndex(writeCol, row), "type",      t)
                            boardModel.setProperty(boardIndex(writeCol, row), "visualRow", row)
                            boardModel.setProperty(boardIndex(col,      row), "type",      -1)
                            boardModel.setProperty(boardIndex(col,      row), "visualRow", row)
                    }
                }
                writeCol++
            }
        }
    }

    function refillPenalty(indices) {
        var affectedCols = []
        for (var i = 0; i < indices.length; i++) {
            var c = indices[i] % cols
            if (affectedCols.indexOf(c) < 0)
                affectedCols.push(c)
        }
        var targetCols = affectedCols.slice(0, 2)
        for (var j = 0; j < targetCols.length; j++) {
            var col = targetCols[j]
            for (var row = 0; row < rows; row++) {
                if (cellType(col, row) < 0) {
                    var lowerType = cellType(col, row + 1)
                    var newType
                    do { newType = Math.floor(Math.random() * 3) } while (newType === lowerType)
                        boardModel.setProperty(boardIndex(col, row), "type",      newType)
                        boardModel.setProperty(boardIndex(col, row), "visualRow", row)
                        break
                }
            }
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Cascade state ─────────────────────────────────────────────────────────
    // cascadeType: the tile type locked for this turn's chain. -1 = none active.
    // pendingDeathIndices: indices waiting to be marked dying after zoom-out lands.
    property int cascadeType:         -1
    property var pendingDeathIndices: null
    property int pendingDeaths:       0
    property var lastResult:          null
    property bool isInitialTap:       false  // true for first wave, false for cascade waves
    // ────────────────────────────────────────────────────────────────────────

    // ── Death wave ────────────────────────────────────────────────────────────
    // Single entry point for starting any death wave — initial tap or cascade.
    // Zooms out first if needed, then fires the dying flags.
    function startDeathWave(indices) {
        pendingDeaths = indices.length
        var outside = isAnyOutsideViewport(indices)
        if (outside && !zoomedOut) {
            // Store indices, zoom out, execute deaths when zoom lands
            pendingDeathIndices = indices
            triggerZoomOut()
        } else {
            // Already zoomed or all in viewport — fire immediately
            executePendingDeaths(indices)
        }
    }

    function executePendingDeaths(indices) {
        for (var i = 0; i < indices.length; i++)
            boardModel.setProperty(indices[i], "dying", true)
    }

    function onTileDied() {
        pendingDeaths--
        if (pendingDeaths > 0) return

            // All tiles in this wave are dead — clear them
            var result = lastResult
            for (var i = 0; i < result.indices.length; i++) {
                boardModel.setProperty(result.indices[i], "type",  -1)
                boardModel.setProperty(result.indices[i], "dying", false)
            }

            // Gravity — refill only on initial 2-tile tap, never on cascade waves
            var isTwoPenalty = isInitialTap && result.count === 2
            var movedSet = applyGravity(isTwoPenalty, result.indices)

            // 2-tile penalty taps never trigger cascades — they are junk moves
            var cascadeIndices = isTwoPenalty ? [] : findCascadeIndices(movedSet)
            if (cascadeIndices.length >= 3) {
                // Continue cascade — score for this wave, start next death wave
                var delta = (cascadeIndices.length - 1) * (cascadeIndices.length - 1)
                score += delta
                scoreDelta(delta)

                isInitialTap = false
                lastResult = { indices: cascadeIndices, count: cascadeIndices.length }
                startDeathWave(cascadeIndices)
            } else {
                // Cascade ended — zoom back if we're out, then finish turn
                cascadeType = -1
                isInitialTap = false
                if (zoomedOut) {
                    triggerZoomIn()
                } else {
                    finalizeTurn()
                }
            }
    }

    function finalizeTurn() {
        boardChanged()
        checkGameOver()
    }

    function checkGameOver() {
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

    // ── Tap handler ───────────────────────────────────────────────────────────
    function handleTap(col, row) {
        if (gameState !== "playing") return
            var result = floodFill(col, row)
            if (result.count < 2) return

                // Lock cascade color for this turn
                cascadeType  = result.type
                isInitialTap = true
                lastResult   = result

                // Write-ahead: signal BEFORE any deaths so main.qml can persist
                // dirty=true + pendingTap. If the app dies mid-cascade, recovery
                // replays this tap against the last clean board in GameStorage.
                tapStarted(col, row)

                var delta = (result.count - 1) * (result.count - 1)
                score += delta
                scoreDelta(delta)

                startDeathWave(result.indices)
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Zoom animations ───────────────────────────────────────────────────────
    property real zoomScale: 1.0

    function triggerZoomOut() {
        zooming  = true
        gameState = "zooming"
        prePanX  = panX
        prePanY  = panY
        zoomOutAnim.start()
    }

    function triggerZoomIn() {
        zooming = true
        zoomInAnim.start()
    }

    // Fly out — fast with snappy overshoot at endpoint
    ParallelAnimation {
        id: zoomOutAnim
        NumberAnimation {
            target: gameBoard; property: "zoomScale"
            to: zoomScale_target; duration: 220
            easing.type: Easing.OutBack; easing.overshoot: 1.2
        }
        NumberAnimation {
            target: gameBoard; property: "panX"
            to: centeredPanX; duration: 220
            easing.type: Easing.OutBack; easing.overshoot: 1.2
        }
        NumberAnimation {
            target: gameBoard; property: "panY"
            to: centeredPanY; duration: 220
            easing.type: Easing.OutBack; easing.overshoot: 1.2
        }
        onStopped: {
            // Zoom landed — we are now in the zoomed-out overview state.
            // pendingDeaths gate in MouseArea blocks input while deaths play.
            zooming   = false
            zoomedOut = true
            gameState = "playing"
            if (pendingDeathIndices !== null) {
                var idx = pendingDeathIndices
                pendingDeathIndices = null
                executePendingDeaths(idx)
            }
        }
    }

    // Fly back — snappy return to saved position
    ParallelAnimation {
        id: zoomInAnim
        NumberAnimation {
            target: gameBoard; property: "zoomScale"
            to: 1.0; duration: 200
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: gameBoard; property: "panX"
            to: prePanX; duration: 200
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: gameBoard; property: "panY"
            to: prePanY; duration: 200
            easing.type: Easing.InCubic
        }
        onStopped: {
            zoomedOut = false
            zooming   = false
            gameState = "playing"
            finalizeTurn()
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Viewport container ───────────────────────────────────────────────────
    Item {
        id: viewport
        width:   vpSize
        height:  vpSize
        anchors.centerIn: parent
        clip:    true
        visible: boardReady

        Item {
            id:     boardContainer
            width:  boardPixelW
            height: boardPixelH
            x:      panX
            y:      panY
            scale:  zoomScale

            Repeater {
                model: boardModel

                delegate: Tile {
                    tileType: model.type < 0 ? 0 : model.type
                    dying:    model.dying
                    visible:  model.type >= 0
                    width:    tileSize
                    height:   tileSize
                    x:        (index % cols) * tileSize
                    y:        model.visualRow * tileSize

                    onDeathComplete: gameBoard.onTileDied()
                }
            }
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Pan / tap MouseArea ───────────────────────────────────────────────────
    MouseArea {
        anchors.fill: viewport
        // Block input while zooming or tiles are dying
        enabled: gameState === "playing" && pendingDeaths === 0

        property real pressX:    0
        property real pressY:    0
        property real pressPanX: 0
        property real pressPanY: 0
        property bool tracking:  false
        property real lastMX:    0
        property real lastMY:    0
        property real velX:      0
        property real velY:      0

        readonly property real threshold: Dims.l(3)

        onPressed: {
            pressX    = mouse.x
            pressY    = mouse.y
            pressPanX = panX
            pressPanY = panY
            lastMX    = mouse.x
            lastMY    = mouse.y
            velX      = 0
            velY      = 0
            tracking  = false
        }

        onPositionChanged: {
            var dx = mouse.x - pressX
            var dy = mouse.y - pressY

            if (!tracking) {
                if (Math.sqrt(dx * dx + dy * dy) < threshold) return
                    tracking        = true
                    panning         = true
                    preventStealing = true
            }

            velX   = (mouse.x - lastMX) * 0.5 + velX * 0.5
            velY   = (mouse.y - lastMY) * 0.5 + velY * 0.5
            lastMX = mouse.x
            lastMY = mouse.y

            var c  = softClampPan(pressPanX + dx, pressPanY + dy)
            panX   = c.x
            panY   = c.y
        }

        onReleased: {
            if (!tracking) {
                var boardX = mouse.x - panX
                var boardY = mouse.y - panY
                handleTap(Math.floor(boardX / tileSize), Math.floor(boardY / tileSize))
            } else {
                var target = clampPan(panX + velX * 4.5, panY + velY * 4.5)
                panning = false
                panX = target.x
                panY = target.y
            }
            tracking        = false
            panning         = false
            preventStealing = false
        }

        onCanceled: {
            tracking        = false
            panning         = false
            preventStealing = false
        }
    }
    // ────────────────────────────────────────────────────────────────────────

}
