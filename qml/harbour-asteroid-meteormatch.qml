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
import Sailfish.Silica 1.0
import "game" as Game

ApplicationWindow {
    id: app

    allowedOrientations: Orientation.Portrait

    // The board lives in the page while the app is in front. When the app
    // goes to the background the same scene is moved into the cover, scaled
    // down, so the home screen tile shows the board as it was left.
    property Item stageItem: null
    property Item stageHome: null
    property Item coverHolder: null

    function placeStage() {
        if (!stageItem) return
        if (applicationActive || !coverHolder) {
            if (stageItem.parent !== stageHome) {
                stageItem.parent = stageHome
                stageItem.scale = 1
            }
        } else {
            stageItem.parent = coverHolder
            stageItem.scale = Math.min(coverHolder.width / stageItem.width,
                                       coverHolder.height / stageItem.height)
        }
    }

    onApplicationActiveChanged: placeStage()
    onCoverHolderChanged: placeStage()

    initialPage: Component {
        Page {
            id: page

            // false: the play field fills the screen.
            // true:  a square field as on a watch, centred.
            property bool squareStage: false

            allowedOrientations: Orientation.Portrait
            backNavigation: false
            showNavigationIndicator: false

            Rectangle {
                anchors.fill: parent
                color: "black"
            }

            Item {
                id: stage
                property Item game: gameLoader.item
                width: page.squareStage ? Math.min(page.width, page.height) : page.width
                height: page.squareStage ? width : page.height
                anchors.centerIn: parent
                clip: true

                Loader {
                    id: gameLoader
                    anchors.fill: parent
                    active: false
                    source: "game/main.qml"
                }
            }

            Component.onCompleted: {
                app.stageHome = page
                app.stageItem = stage
            }

            // The game reads its scale once at start, so the size has to
            // be known before it is loaded.
            onStatusChanged: {
                if (status === PageStatus.Active && !gameLoader.active) {
                    Game.Dims.width = stage.width
                    Game.Dims.height = stage.height
                    gameLoader.active = true
                }
            }
        }
    }

    cover: Component {
        CoverBackground {
            Rectangle {
                anchors.fill: parent
                color: "black"
            }

            // the play field is moved in here while the app is in the background
            Item {
                id: holder
                anchors.fill: parent
                clip: true
                Component.onCompleted: app.coverHolder = holder
                Component.onDestruction: app.coverHolder = null
            }

            Label {
                anchors.centerIn: parent
                text: "Meteor Match"
                visible: !app.stageItem || app.stageItem.parent !== holder
            }
        }
    }
}
