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

pragma Singleton
import QtQuick 2.6
import Nemo.Configuration 1.0

// SailfishOS: replaces the C++ GameStorage (QSettings, game.ini) so the
// app is pure QML and one noarch package. Same API; the values live in
// dconf under /apps/harbour-asteroid-meteormatch and every change is
// written at once, as the C++ synced after every write. The high score
// is never lowered.
QtObject {
    id: store

    property QtObject _cfg: ConfigurationGroup { path: "/apps/harbour-asteroid-meteormatch" }
    property bool _ready: false

    property int    score:      0
    property int    highScore:  0
    property string board:      ""
    property bool   dirty:      false
    property string pendingTap: ""
    property real   panX:       0
    property real   panY:       0

    function _save(key, v) { if (_ready) _cfg.setValue(key, v) }
    onScoreChanged:      _save("score", score)
    onBoardChanged:      _save("board", board)
    onDirtyChanged:      _save("dirty", dirty)
    onPendingTapChanged: _save("pendingTap", pendingTap)
    onPanXChanged:       _save("panX", panX)
    onPanYChanged:       _save("panY", panY)
    onHighScoreChanged: {
        if (!_ready) return
        var stored = Number(_cfg.value("highScore", 0))
        if (highScore > stored) _cfg.setValue("highScore", highScore)
        else if (highScore < stored) highScore = stored
    }

    function clear() {
        board = ""; score = 0; pendingTap = ""; dirty = false; panX = 0; panY = 0
    }

    Component.onCompleted: {
        score      = Number(_cfg.value("score", 0))
        highScore  = Number(_cfg.value("highScore", 0))
        board      = String(_cfg.value("board", ""))
        dirty      = _cfg.value("dirty", false) === true || _cfg.value("dirty", false) === "true"
        pendingTap = String(_cfg.value("pendingTap", ""))
        panX       = Number(_cfg.value("panX", 0))
        panY       = Number(_cfg.value("panY", 0))
        _ready = true
    }
}
