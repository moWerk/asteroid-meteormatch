// GameBoard.qml
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

    // ── Public interface
    property string gameState: "playing"  // "playing" | "zooming" | "gameover"
    property int score: 0
    property bool boardReady: false

    signal scoreDelta(int delta)
    signal gameOver()
    signal gameWon()
    signal boardChanged()
    // Emitted at the START of a move — before any deaths — so main.qml
    // can write the write-ahead log (dirty=true, pendingTap=col,row).
    // The board in GameStorage at this point is the pre-tap state.
    signal tapStarted(int col, int row)
    signal longPressed()

    anchors.fill: parent

    // ── Board constants
    readonly property int cols: 10
    readonly property int rows: 12
    readonly property int tileCount: cols * rows
    readonly property int tileSize: Math.floor(Math.min(parent.width, parent.height) / 5)
    readonly property int boardPixelW: cols * tileSize
    readonly property int boardPixelH: rows * tileSize
    readonly property int vpSize: tileSize * 5

    // ── Pan state
    property real panX: 0
    property real panY: 0
    property bool panning: false
    property bool zooming: false
    property bool zoomedOut: false
    property real prePanX: 0
    property real prePanY: 0

    readonly property int edgePad: tileSize
    readonly property real panMinX: -(boardPixelW - vpSize + edgePad)
    readonly property real panMaxX: edgePad
    readonly property real panMinY: -(boardPixelH - vpSize + edgePad)
    readonly property real panMaxY: edgePad
    readonly property real zoomScale_target: vpSize / Math.max(boardPixelW, boardPixelH)
    readonly property real centeredPanX: (vpSize - boardPixelW) / 2
    readonly property real centeredPanY: (vpSize - boardPixelH) / 2

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

    // ── Board model
    ListModel { id: boardModel }

    function boardIndex(col, row) { return col + row * cols }

    function cellType(col, row) {
        if (col < 0 || col >= cols || row < 0 || row >= rows) return -1
            return boardModel.get(boardIndex(col, row)).type
    }

    function initBoard() {
        boardReady = false
        panning = true
        panX = 0
        panY = 0
        score = 0
        boardModel.clear()
        for (var i = 0; i < tileCount; i++)
            boardModel.append({
                type: Math.floor(Math.random() * 3),
                dying: false,
                visualRow: Math.floor(i / cols),
                visualCol: i % cols
            })
        readyTimer.restart()
    }

    function loadBoard(jsonStr) {
        boardReady = false
        isRestoring = true
        panning = true
        boardModel.clear()
        var arr = JSON.parse(jsonStr)
        for (var i = 0; i < tileCount; i++)
            boardModel.append({
                type: arr[i],
                dying: false,
                visualRow: Math.floor(i / cols),
                visualCol: i % cols
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
        repeat: false
        onTriggered: {
            boardReady = true
            Qt.callLater(function() { panning = false })
            if (!isRestoring) {
                boardChanged()
            } else {
                Qt.callLater(function() {
                    if (!hasValidMoves()) initBoard()
                })
            }
            isRestoring = false
        }
    }

    // ── Viewport helper
    function isAnyOutsideViewport(indices) {
        var vpLeft = Math.floor(-panX / tileSize)
        var vpTop = Math.floor(-panY / tileSize)
        var vpRight = vpLeft + 5
        var vpBottom = vpTop + 5
        for (var i = 0; i < indices.length; i++) {
            var c = indices[i] % cols
            var r = Math.floor(indices[i] / cols)
            if (c < vpLeft || c >= vpRight || r < vpTop || r >= vpBottom)
                return true
        }
        return false
    }

    // ── Flood fill
    property var floodVisited: []

    function floodFill(col, row) {
        var targetType = cellType(col, row)
        if (targetType < 0) return { count: 0, indices: [], type: -1 }
        floodVisited = new Array(tileCount)
        var indices = []
        floodStep(col, row, targetType, indices)
        if (indices.length < 2) return { count: 0, indices: [], type: -1 }
        return { count: indices.length, indices: indices, type: targetType }
    }

    function floodStep(col, row, targetType, indices) {
        if (col < 0 || col >= cols || row < 0 || row >= rows) return
            var idx = boardIndex(col, row)
            if (floodVisited[idx]) return
                if (boardModel.get(idx).type !== targetType) return
                    floodVisited[idx] = true
                    indices.push(idx)
                    floodStep(col + 1, row, targetType, indices)
                    floodStep(col - 1, row, targetType, indices)
                    floodStep(col, row + 1, targetType, indices)
                    floodStep(col, row - 1, targetType, indices)
    }

    // Find cascadeType groups >= 3 containing at least one tile that moved during gravity.
    // Stationary connected groups of the same color are never cascaded.
    // movedSet: hash-set { boardIndex: true } of every tile that changed position.
    function findCascadeIndices(movedSet) {
        var visited = new Array(tileCount)
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
                    floodStepWith(col + 1, row, targetType, indices, visited)
                    floodStepWith(col - 1, row, targetType, indices, visited)
                    floodStepWith(col, row + 1, targetType, indices, visited)
                    floodStepWith(col, row - 1, targetType, indices, visited)
    }

    // ── Gravity — pure computation, no model changes
    // Returns { moves, movedSet }.
    // moves: array of { col, sourceRow, destRow, destIdx, sourceIdx, type }
    // movedSet: hash { boardIndex: true } for every destination that received a tile
    function computeVerticalMoves() {
        var moves = []
        var movedSet = {}
        for (var col = 0; col < cols; col++) {
            var writeRow = rows - 1
            for (var row = rows - 1; row >= 0; row--) {
                var t = cellType(col, row)
                if (t >= 0) {
                    if (writeRow !== row) {
                        moves.push({
                            col:       col,
                            sourceRow: row,
                            destRow:   writeRow,
                            destIdx:   boardIndex(col, writeRow),
                                   sourceIdx: boardIndex(col, row),
                                   type:      t
                        })
                        movedSet[boardIndex(col, writeRow)] = true
                    }
                    writeRow--
                }
            }
        }
        return { moves: moves, movedSet: movedSet }
    }

    // Horizontal column compaction — runs instantly after gravity animation completes.
    // movedSet updated in place so cascade detection reflects correct final indices.
    // Pure column move computation + movedSet update.
    // Side-effect: updates pendingMovedSet in place for cascade detection.
    function computeColumnMoves() {
        var moves = []
        var writeCol = 0
        for (var col = 0; col < cols; col++) {
            if (cellType(col, rows - 1) >= 0) {
                if (writeCol !== col) {
                    for (var row = 0; row < rows; row++) {
                        var t = cellType(col, row)
                        if (t >= 0 && pendingMovedSet[boardIndex(col, row)])
                            pendingMovedSet[boardIndex(writeCol, row)] = true
                        delete pendingMovedSet[boardIndex(col, row)]
                        if (t >= 0) {
                            moves.push({
                                sourceCol: col,
                                destCol:   writeCol,
                                row:       row,
                                sourceIdx: boardIndex(col, row),
                                destIdx:   boardIndex(writeCol, row),
                                type:      t
                            })
                        }
                    }
                }
                writeCol++
            }
        }
        return moves
    }

    function startCollapseAnimation() {
        var moves = computeColumnMoves()

        if (moves.length === 0) {
            afterGravityComplete()
            return
        }

        collapseBehavior = false
        pendingColMoves = moves

        // Pre-position: destination tiles appear at source column, source becomes empty.
        for (var i = 0; i < moves.length; i++) {
            boardModel.setProperty(moves[i].destIdx, "visualCol", moves[i].sourceCol)
            boardModel.setProperty(moves[i].destIdx, "type",      moves[i].type)
            boardModel.setProperty(moves[i].sourceIdx, "type",    -1)
            boardModel.setProperty(moves[i].sourceIdx, "visualCol", moves[i].sourceCol)
        }

        collapseKickTimer.restart()
    }

    // ── Gravity animation state
    // gravityActive: true from startGravityAnimation until afterGravityComplete —
    //   blocks input for the full gravity + column collapse window.
    // gravityBehavior: true only during the animated fall window —
    //   gates the Behavior on y in the delegate so pre-positioning is always instant.
    property bool gravityActive: false
    property bool gravityBehavior: false
    property bool collapseBehavior: false

    readonly property int gravityStaggerMs: 25   // delay per column — wave left-to-right
    readonly property int gravityAnimMs: 220      // fall duration per tile
    readonly property int collapseAnimMs: 200

    property var pendingMoves: []
    property var pendingMovedSet: ({})
    property var pendingColMoves: []

    // Phase 1 — pre-position + type swap (Behavior disabled).
    // gravityKickTimer separates this from phase 2 so the renderer
    // paints the pre-positioned state before the Behavior fires.
    function startGravityAnimation() {
        var result = computeVerticalMoves()
        pendingMovedSet = result.movedSet
        gravityActive = true

        if (result.moves.length === 0) {
            startCollapseAnimation()
            return
        }

        pendingMoves = result.moves
        gravityBehavior = false

        for (var i = 0; i < pendingMoves.length; i++)
            boardModel.setProperty(pendingMoves[i].destIdx, "visualRow", pendingMoves[i].sourceRow)

            for (var i = 0; i < pendingMoves.length; i++) {
                boardModel.setProperty(pendingMoves[i].destIdx, "type", pendingMoves[i].type)
                boardModel.setProperty(pendingMoves[i].sourceIdx, "type", -1)
            }

            gravityKickTimer.restart()
    }

    // Phase 2 — enable Behavior and push all visualRows to destination.
    // Fires one frame after phase 1 so the renderer has painted the starting positions.
    Timer {
        id: gravityKickTimer
        interval: 32
        repeat: false
        onTriggered: {
            gravityBehavior = true
            for (var i = 0; i < pendingMoves.length; i++)
                boardModel.setProperty(pendingMoves[i].destIdx, "visualRow", pendingMoves[i].destRow)
                // Total animation window: last column finishes at (cols-1)*stagger + animDuration
                gravityCompleteTimer.interval = (cols - 1) * gravityStaggerMs + gravityAnimMs
                gravityCompleteTimer.restart()
        }
    }

    // Gravity done — disable Behavior, apply instant column collapse, check cascades.
    Timer {
        id: gravityCompleteTimer
        repeat: false
        onTriggered: {
            gravityBehavior = false
            startCollapseAnimation()
        }
    }

    Timer {
        id: collapseKickTimer
        interval: 32
        repeat: false
        onTriggered: {
            collapseBehavior = true
            for (var i = 0; i < pendingColMoves.length; i++)
                boardModel.setProperty(pendingColMoves[i].destIdx, "visualCol", pendingColMoves[i].destCol)
                collapseCompleteTimer.interval = collapseAnimMs
                collapseCompleteTimer.restart()
        }
    }

    Timer {
        id: collapseCompleteTimer
        repeat: false
        onTriggered: {
            collapseBehavior = false
            afterGravityComplete()
        }
    }

    // ── Cascade state
    property int cascadeType: -1          // tile type locked for this turn's chain, -1 = none
    property int pendingDeaths: 0
    property var lastResult: null
    property bool isInitialTap: false     // true for first wave, false for cascade waves
    property var pendingDeathIndices: []

    // ── Death wave — zoom out first so the player sees what happens,
    //    then start deaths.
    function startDeathWave(indices) {
        pendingDeaths = indices.length
        var outside = isAnyOutsideViewport(indices)
        if (outside && !zoomedOut) {
            pendingDeathIndices = indices
            triggerZoomOut()
        } else {
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

            // Clear all dead tiles from the model, then animate gravity.
            var result = lastResult
            for (var i = 0; i < result.indices.length; i++) {
                boardModel.setProperty(result.indices[i], "type", -1)
                boardModel.setProperty(result.indices[i], "dying", false)
            }

            startGravityAnimation()
    }

    // Called after gravity animation + column collapse complete.
    function afterGravityComplete() {
        gravityActive = false

        // 2-tile matches never trigger cascades — cascade blocking is the only malus
        var cascadeIndices = isInitialTap && lastResult.count === 2
        ? []
        : findCascadeIndices(pendingMovedSet)

        if (cascadeIndices.length >= 3) {
            var delta = (cascadeIndices.length - 1) * (cascadeIndices.length - 1)
            score += delta
            scoreDelta(delta)
            isInitialTap = false
            lastResult = { indices: cascadeIndices, count: cascadeIndices.length }
            startDeathWave(cascadeIndices)
        } else {
            cascadeType = -1
            isInitialTap = false
            if (zoomedOut) triggerZoomIn()
                finalizeTurn()
        }
    }

    function finalizeTurn() {
        boardChanged()
        checkGameOver()
    }

    function hasValidMoves() {
        for (var col = 0; col < cols; col++) {
            for (var row = 0; row < rows; row++) {
                var t = cellType(col, row)
                if (t < 0) continue
                    if (cellType(col + 1, row) === t) return true
                        if (cellType(col, row + 1) === t) return true
            }
        }
        return false
    }

    function checkGameOver() {
        // Check for win first — board fully cleared
        var empty = true
        for (var i = 0; i < tileCount; i++) {
            if (boardModel.get(i).type >= 0) { empty = false; break }
        }
        if (empty) {
            score += 100
            gameState = "gameover"
            gameWon()
            return
        }
        if (!hasValidMoves()) {
            gameState = "gameover"
            gameOver()
        }
    }

    // ── Tap handler
    function handleTap(col, row) {
        if (gameState !== "playing") return
            var result = floodFill(col, row)
            if (result.count < 2) return

                // Save viewport position at tap time — always the zoom-in return point
                prePanX = panX
                prePanY = panY

                cascadeType = result.type
                isInitialTap = true
                lastResult = result

                // Write-ahead: signal BEFORE any deaths so main.qml can persist
                // dirty=true + pendingTap. If the app dies mid-cascade, recovery
                // replays this tap against the last clean board in GameStorage.
                tapStarted(col, row)

                var delta = (result.count - 1) * (result.count - 1)
                score += delta
                scoreDelta(delta)

                startDeathWave(result.indices)
    }

    // ── Zoom — instant cuts, animation-ready hooks preserved via zooming flag
    property real zoomScale: 1.0

    ParallelAnimation {
        id: zoomOutAnim
        NumberAnimation { target: gameBoard; property: "zoomScale"; to: zoomScale_target; duration: 320; easing.type: Easing.OutQuart }
        NumberAnimation { target: gameBoard; property: "panX";      to: centeredPanX;    duration: 320; easing.type: Easing.OutQuart }
        NumberAnimation { target: gameBoard; property: "panY";      to: centeredPanY;    duration: 320; easing.type: Easing.OutQuart }
        onStopped: {
            zoomedOut = true
            zooming = false
            executePendingDeaths(pendingDeathIndices)
        }
    }

    ParallelAnimation {
        id: zoomInAnim
        NumberAnimation { target: gameBoard; property: "zoomScale"; to: 1.0;     duration: 320; easing.type: Easing.InOutQuad }
        NumberAnimation { target: gameBoard; property: "panX";      to: prePanX; duration: 320; easing.type: Easing.InOutQuad }
        NumberAnimation { target: gameBoard; property: "panY";      to: prePanY; duration: 320; easing.type: Easing.InOutQuad }
        onStopped: {
            zoomedOut = false
            zooming = false
        }
    }

    function triggerZoomOut() {
        zooming = true
        zoomOutAnim.restart()
    }

    function triggerZoomIn() {
        zooming = true
        zoomInAnim.restart()
    }

    // ── Viewport
    Item {
        id: viewport
        width: vpSize
        height: vpSize
        anchors.centerIn: parent
        clip: true
        visible: boardReady

        Item {
            id: boardContainer
            width: boardPixelW
            height: boardPixelH
            x: panX
            y: panY
            scale: zoomScale

            Behavior on x {
                enabled: !panning && !zooming
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.8
                }
            }

            Behavior on y {
                enabled: !panning && !zooming
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.8
                }
            }

            Repeater {
                id: tilesRepeater
                model: boardModel

                delegate: Tile {
                    id: tileDelegate

                    // Column captured here — used by the stagger PauseAnimation below.
                    readonly property int tileCol: index % cols

                    tileType: model.type < 0 ? 0 : model.type
                    dying: model.dying
                    visible: model.type >= 0
                    width: tileSize
                    height: tileSize
                    x: model.visualCol * tileSize
                    y: model.visualRow * tileSize

                    Behavior on x {
                        enabled: gameBoard.collapseBehavior
                        NumberAnimation {
                            duration: gameBoard.collapseAnimMs
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        enabled: gameBoard.gravityBehavior
                        SequentialAnimation {
                            // Left columns start first — wave sweeps left to right.
                            PauseAnimation {
                                duration: Math.max(0, tileDelegate.tileCol * gameBoard.gravityStaggerMs)
                            }
                            NumberAnimation {
                                duration: gameBoard.gravityAnimMs
                                easing.type: Easing.InQuad
                            }
                        }
                    }

                    onDeathComplete: gameBoard.onTileDied()
                }
            }
        }
    }

    // ── Pan / tap input
    MouseArea {
        anchors.fill: viewport
        // Block input during deaths, gravity animation, and the kick-timer window
        enabled: gameState === "playing" && pendingDeaths === 0 && !gravityActive && !zooming

        property real pressX: 0
        property real pressY: 0
        property real pressPanX: 0
        property real pressPanY: 0
        property bool tracking: false
        property bool longConsumed: false  // set by onPressAndHold, blocks tap in onReleased
        property real lastMX: 0
        property real lastMY: 0
        property real velX: 0
        property real velY: 0

        readonly property real threshold: Dims.l(3)

        onPressed: {
            pressX = mouse.x
            pressY = mouse.y
            pressPanX = panX
            pressPanY = panY
            lastMX = mouse.x
            lastMY = mouse.y
            velX = 0
            velY = 0
            tracking = false
            longConsumed = false
        }

        onPositionChanged: {
            var dx = mouse.x - pressX
            var dy = mouse.y - pressY

            if (!tracking) {
                if (Math.sqrt(dx * dx + dy * dy) < threshold) return
                    tracking = true
                    panning = true
                    preventStealing = true
            }

            velX = (mouse.x - lastMX) * 0.5 + velX * 0.5
            velY = (mouse.y - lastMY) * 0.5 + velY * 0.5
            lastMX = mouse.x
            lastMY = mouse.y

            var c = softClampPan(pressPanX + dx, pressPanY + dy)
            panX = c.x
            panY = c.y
        }

        onReleased: {
            if (!tracking && !longConsumed) {
                var boardX = mouse.x - panX
                var boardY = mouse.y - panY
                handleTap(Math.floor(boardX / tileSize), Math.floor(boardY / tileSize))
            } else {
                var target = clampPan(panX + velX * 4.5, panY + velY * 4.5)
                panning = false
                panX = target.x
                panY = target.y
            }
            tracking = false
            panning = false
            preventStealing = false
        }

        onCanceled: {
            tracking = false
            panning = false
            preventStealing = false
        }

        onPressAndHold: {
            if (!tracking) {
                longConsumed = true
                gameBoard.longPressed()
            }
        }
    }
}
