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
    id: tile

    // ── Public interface ─────────────────────────────────────────────────────
    // type: 0 = fire/red, 1 = ice/blue, 2 = void/purple
    property int  tileType:  0
    property bool dying:     false
    // Called by GameBoard after death animation completes so the board can
    // remove the model entry and repack. Avoids the board needing a Timer.
    signal deathComplete()
    // ────────────────────────────────────────────────────────────────────────

    // Tile size is driven by parent (GameBoard sets width/height on creation).
    // SpringAnimation on y produces the gravity-fall when rows above collapse.
    Behavior on y {
        SpringAnimation {
            spring:  2.2
            damping: 0.26
        }
    }

    // ── Tile colors by type ──────────────────────────────────────────────────
    readonly property var typeColors: [
        "#CC3300",  // 0 fire — warm red-orange
        "#0077CC",  // 1 ice  — cool blue
        "#7700CC"   // 2 void — purple
    ]

    readonly property var typeColorsDim: [
        "#661A00",  // 0 fire dim
        "#003D66",  // 1 ice  dim
        "#3D0066"   // 2 void dim
    ]
    // ────────────────────────────────────────────────────────────────────────

    // ── Tile body ────────────────────────────────────────────────────────────
    Rectangle {
        id: body
        anchors.fill:   parent
        anchors.margins: Dims.l(1)
        radius:          Dims.l(2)
        color:           typeColors[tileType]
        opacity:         dying ? 0.0 : 1.0

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

        // Inner highlight — one smaller rect to give the tile a face
        Rectangle {
            anchors {
                top:         parent.top
                left:        parent.left
                margins:     Dims.l(1)
            }
            width:   parent.width  * 0.38
            height:  parent.height * 0.38
            radius:  Dims.l(1)
            color:   "white"
            opacity: 0.18
        }

        // Inner shadow — bottom-right corner depth cue
        Rectangle {
            anchors {
                bottom:  parent.bottom
                right:   parent.right
                margins: Dims.l(1)
            }
            width:   parent.width  * 0.38
            height:  parent.height * 0.38
            radius:  Dims.l(1)
            color:   typeColorsDim[tileType]
            opacity: 0.6
        }
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Death puff ShaderEffect ───────────────────────────────────────────────
    // Positioned at tile center, destroyed when animation completes.
    // Kept deliberately small and fast — this fires 2–N times per move.
    ShaderEffect {
        id: puff

        property real time:      0.0
        property color puffColor: typeColors[tileType]

        // Centered on tile, slightly larger than tile so particles spill out
        width:  tile.width  * 1.6
        height: tile.height * 1.6
        anchors.centerIn: parent

        visible: dying
        opacity: 1.0 - time   // fades with the animation

        NumberAnimation on time {
            id:       puffAnim
            from:     0.0
            to:       1.0
            duration: 380
            running:  false
            easing.type: Easing.Linear
            onRunningChanged: {
                if (!running && time >= 1.0)
                    tile.deathComplete()
            }
        }

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
            uniform highp float time;
            uniform highp vec3  puffColor;
            uniform highp float qt_Opacity;

            highp float noise(highp vec2 p) {
                return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
            }

            void main() {
                highp vec2  uv    = coord - vec2(0.5);
                highp float fade  = 1.0 - time;
                highp vec3  color = vec3(0.0);
                highp float alpha = 0.0;

                // 10 radial particles — cheap, readable on catfish
                for (int i = 0; i < 10; i++) {
                    highp float fi     = float(i);
                    highp float angle  = fi * 0.6283 + noise(vec2(fi, 0.0)) * 0.5;
                    highp float speed  = 0.6 + noise(vec2(fi, 1.0)) * 0.4;
                    highp vec2  pos    = vec2(cos(angle), sin(angle)) * speed * time * 0.45;
                    highp float d      = length(uv - pos);
                    highp float r      = 0.055 * (1.0 - time * 0.5);
                    if (d < r) {
                        highp float i2 = 1.0 - d / r;
                        color += mix(vec3(1.0), puffColor, time) * i2 * fade;
                        alpha += i2 * fade;
                    }
                }

                // Small bright core at origin, present only at start
                highp float core = length(uv) * (1.0 + time * 3.0);
                if (core < 0.18) {
                    highp float ci = 1.0 - core / 0.18;
                    color += vec3(1.0) * ci * fade * 0.7;
                    alpha += ci * fade * 0.7;
                }

                gl_FragColor = vec4(clamp(color, 0.0, 1.0), clamp(alpha, 0.0, 1.0) * qt_Opacity);
            }
        "

        // Expose puffColor as vec3 uniform
        property variant uniforms: ({ "puffColor": Qt.vector3d(puffColor.r, puffColor.g, puffColor.b) })
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Dying state trigger ──────────────────────────────────────────────────
    onDyingChanged: {
        if (dying)
            puffAnim.start()
    }
    // ────────────────────────────────────────────────────────────────────────
}
