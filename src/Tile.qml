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
    property int  tileType: 0
    property bool dying:    false
    signal deathComplete()
    // ────────────────────────────────────────────────────────────────────────

    // SpringAnimation on y — fires when model.visualRow * tileSize changes
    Behavior on y {
        SpringAnimation { spring: 2.2; damping: 0.26 }
    }

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

    // ── Tile body ────────────────────────────────────────────────────────────
    Rectangle {
        id: body
        anchors.fill:    parent
        anchors.margins: Dims.l(1)
        radius:          Dims.l(2)
        color:           typeColors[tileType]
        opacity:         dying ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

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

    // ── Death puff ShaderEffect ───────────────────────────────────────────────
    // NOTE: "time" is a reserved Qt 5 ShaderEffect built-in — use "animTime"
    ShaderEffect {
        id: puff

        property real animTime: 0.0   // NOT "time" — that name is reserved by Qt 5
        property real puffR: tileType === 0 ? 0.835 : tileType === 1 ? 0.337 : 0.0
        property real puffG: tileType === 0 ? 0.369 : tileType === 1 ? 0.706 : 0.620
        property real puffB: tileType === 0 ? 0.0   : tileType === 1 ? 0.914 : 0.451

        width:  tile.width  * 1.6
        height: tile.height * 1.6
        anchors.centerIn: parent
        visible: dying
        opacity: 1.0 - animTime

        NumberAnimation on animTime {
            id:          puffAnim
            from:        0.0
            to:          1.0
            duration:    380
            running:     false
            easing.type: Easing.Linear
            onRunningChanged: {
                if (!running && tile.dying) {
                    tile.deathComplete()
                }
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
    uniform highp float animTime;
    uniform highp float puffR;
    uniform highp float puffG;
    uniform highp float puffB;
    uniform highp float qt_Opacity;

    highp float noise(highp vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
    }

    void main() {
    highp vec3  puffColor = vec3(puffR, puffG, puffB);
    highp vec2  uv   = coord - vec2(0.5);
    highp float fade = 1.0 - animTime;
    highp vec3  color = vec3(0.0);
    highp float alpha = 0.0;

    for (int i = 0; i < 10; i++) {
        highp float fi    = float(i);
        highp float angle = fi * 0.6283 + noise(vec2(fi, 0.0)) * 0.5;
        highp float speed = 0.6 + noise(vec2(fi, 1.0)) * 0.4;
        highp vec2  pos   = vec2(cos(angle), sin(angle)) * speed * animTime * 0.45;
        highp float d     = length(uv - pos);
        highp float r     = 0.055 * (1.0 - animTime * 0.5);
        if (d < r) {
            highp float i2 = 1.0 - d / r;
            color += mix(vec3(1.0), puffColor, animTime) * i2 * fade;
            alpha += i2 * fade;
    }
    }

    highp float core = length(uv) * (1.0 + animTime * 3.0);
    if (core < 0.18) {
        highp float ci = 1.0 - core / 0.18;
        color += vec3(1.0) * ci * fade * 0.7;
        alpha += ci * fade * 0.7;
    }

    gl_FragColor = vec4(clamp(color, 0.0, 1.0),
    clamp(alpha, 0.0, 1.0) * qt_Opacity);
    }
    "
    }
    // ────────────────────────────────────────────────────────────────────────

    // ── Dying trigger ────────────────────────────────────────────────────────
    onDyingChanged: {
        if (dying) {
            puff.animTime = 0.0
            puffAnim.start()
        }
    }
    // ────────────────────────────────────────────────────────────────────────
}
