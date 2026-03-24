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
    id: tile

    // ── Public interface ─────────────────────────────────────────────────────
    property int  tileType:  0
    property bool dying:     false
    signal deathComplete()
    // ────────────────────────────────────────────────────────────────────────

     // ── Wong palette — colorblind safe ───────────────────────────────────────
    // 0 = vermillion, 1 = sky blue, 2 = bluish green
    readonly property var typeColors: [
        "#D55E00",
        "#56B4E9",
        "#009E73"
    ]
    readonly property var typeColorsDim: [
        "#7A3500",
        "#1A5F8A",
        "#005740"
    ]
    // ────────────────────────────────────────────────────────────────────────

    // ── Death animation progress (0 = alive, 1 = fully gone) ─────────────────
    property real deathProgress: 0.0

    NumberAnimation on deathProgress {
        id:          deathAnim
        from:        0.0
        to:          1.0
        duration:    520
        running:     false
        easing.type: Easing.InCubic
        onStopped: tile.deathComplete()
    }

    // ────────────────────────────────────────────────────────────────────────

    // ── Tile body ────────────────────────────────────────────────────────────
    Rectangle {
        id: body
        anchors.fill:    parent
        anchors.margins: Dims.l(1)
        radius:          Dims.l(2)

        // Flash gold as death begins, then fade to transparent
        // deathProgress 0.0 → 0.25: lerp from typeColor to gold
        // deathProgress 0.25 → 1.0: fade out
        color: {
            if (!dying) return typeColors[tileType]
                if (deathProgress < 0.25) {
                    var t = deathProgress / 0.25
                    return Qt.rgba(
                        (1 - t) * (tileType === 0 ? 0.835 : tileType === 1 ? 0.337 : 0.0)   + t * 1.0,
                                   (1 - t) * (tileType === 0 ? 0.369 : tileType === 1 ? 0.706 : 0.620) + t * 0.84,
                                   (1 - t) * (tileType === 0 ? 0.0   : tileType === 1 ? 0.914 : 0.451) + t * 0.0,
                                   1.0)
                }
                return "#FFD700"
        }

        opacity: dying ? Math.max(0, 1.0 - (deathProgress - 0.2) / 0.8) : 1.0

        // Top-left highlight
        Rectangle {
            anchors { top: parent.top; left: parent.left; margins: Dims.l(1) }
            width:   parent.width  * 0.38
            height:  parent.height * 0.38
            radius:  Dims.l(1)
            color:   "white"
            opacity: 0.18
        }
        // Bottom-right shadow
        Rectangle {
            anchors { bottom: parent.bottom; right: parent.right; margins: Dims.l(1) }
            width:   parent.width  * 0.38
            height:  parent.height * 0.38
            radius:  Dims.l(1)
            color:   typeColorsDim[tileType]
            opacity: 0.6
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Gold shimmer ShaderEffect ─────────────────────────────────────────────
    // Radial shimmer that blooms outward as the tile goes gold, then fades.
    // Uses animTime (not "time" — reserved Qt 5 built-in).
    ShaderEffect {
        id: shimmer

        property real animTime: deathProgress
        property real shimmerR: 1.0
        property real shimmerG: 0.84
        property real shimmerB: 0.0

        width:  tile.width  * 2.2
        height: tile.height * 2.2
        anchors.centerIn: parent

        // Visible from death start, fades with body
        visible: dying
        opacity: dying ? Math.max(0, 0.85 - deathProgress * 1.1) : 0.0

        vertexShader: "
        uniform   highp mat4 qt_Matrix;
        attribute highp vec4 qt_Vertex;
        attribute highp vec2 qt_MultiTexCoord0;
        varying   highp vec2 coord;
        void main() {
        coord       = qt_MultiTexCoord0;
        gl_Position = qt_Matrix * qt_Vertex;
    }
    "

    fragmentShader: "
    varying highp vec2  coord;
    uniform highp float animTime;
    uniform highp float shimmerR;
    uniform highp float shimmerG;
    uniform highp float shimmerB;
    uniform highp float qt_Opacity;

    void main() {
    highp vec2  uv    = coord - vec2(0.5);
    highp float dist  = length(uv);
    highp vec3  gold  = vec3(shimmerR, shimmerG, shimmerB);

    // Expanding ring — radius grows with animTime
    highp float ring  = animTime * 0.48;
    highp float width = 0.06 + animTime * 0.04;
    highp float d     = abs(dist - ring);
    highp float ring_a = max(0.0, 1.0 - d / width);

    // Soft radial glow at center, strongest early
    highp float glow  = max(0.0, 0.3 - dist * 1.8) * (1.0 - animTime * 0.8);

    highp float alpha = (ring_a * 0.9 + glow) * qt_Opacity;
    gl_FragColor = vec4(gold * (ring_a + glow * 2.0), alpha);
    }
    "
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Dying trigger ────────────────────────────────────────────────────────
    onDyingChanged: {
        if (dying) {
            deathProgress = 0.0
            deathAnim.restart()
        } else {
            deathAnim.stop()
            deathProgress = 0.0
        }
    }
    // ────────────────────────────────────────────────────────────────────────
}
