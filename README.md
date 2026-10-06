# Meteor Match

A color-matching puzzle game for AsteroidOS watches.

## SailfishOS

This branch is the SailfishOS version of the game. It is built for
Sailfish OS 5.1 on aarch64 and was run on a Jolla C2. The game is the
1.0 watch version; this section lists what is different.

### On a tall phone screen

The board and its tiles keep the proportions of the watch: five tiles
across the screen width. Only the view onto the board grows. On a watch
it shows five by five tiles, on the C2 it fills the screen and shows
about eleven rows. Panning, the zoom-out on a large match and the
centring all work with the larger view.

### Only on SailfishOS

- **Cover**: swipe the app away and the home screen tile shows the board
  as you left it.
- **Sandboxed**: the app runs in the SailfishOS sandbox and needs no
  permissions. The package passes Jolla's store validator
  (`rpmvalidation`, only the warning that the binary is not stripped).

### Install

Download the RPM from the releases page and install it:

    devel-su pkcon install-local harbour-asteroid-meteormatch-1.0.0-1.aarch64.rpm

It is aarch64 only. The board and the highscore are stored in
`~/.config/net.mowerk/harbour-asteroid-meteormatch/game.ini`.

### Build

With the Sailfish Platform SDK and a 5.1.0.11 aarch64 target:

    mb2 -t SailfishOS-5.1.0.11-aarch64 build

SailfishOS is on Qt 5.6. The port starts from the QML before the Qt 6
port, replaces `Qt.callLater()` (Qt 5.8) with a small timer, draws the
background with a `RadialGradient`, and uses small `Label` and `Dims`
stand-ins. The Xolonium font ships with the app.

### Disclosure for the port

The port was written by an LLM overnight, following the author's rule
for the tall screen: keep the board, only grow the view. The model
checked it through window grabs on one Jolla C2, and the author played
it there and won a game. He has not read the port's code.

```
Disclosure: LLMGD-2 · origin O0 (LLM-ported to the author's viewport rule; played by the author on one Jolla C2; code not read; self-graded)
LLMGD: v0.2; assurance=A2; flags=T; origin={O0:.7,O1:.3}; origin_headline=O0; scope=port(code+assets+packaging+docs); graded-by=claude-opus-5-5; retrieval=author-side
```

## How to play

The board is a 10 by 12 grid of colored tiles in three colors. Tap any
tile that is connected to at least one neighbor of the same color to
clear the entire connected group. Tiles above cleared spaces fall down
to fill the gaps. Columns with no remaining tiles compact toward the
left side of the board.

## Scoring

Clearing a group of N tiles scores (N-1) squared points. A group of
two scores one point. A group of ten scores eighty-one points. Larger
groups are always worth more than splitting the same tiles into smaller
matches.

If falling tiles form a new matching group of three or more, a chain
reaction triggers automatically and scores additional points by the
same formula. Chain reactions can continue as long as new matches keep
forming.

Clearing the entire board scores a bonus of 100 points on top of
whatever was accumulated during the game.

## Navigation

The board is larger than the screen. Drag to pan. Release with
momentum and the board glides to a stop. When a match includes tiles
outside the current view the board zooms out automatically so you can
see the full effect before panning back.

Long press anywhere on the board to open the reset menu. A confirmation
tap is required to start a new game so accidental long presses do not
destroy progress.

## Saving

Progress is saved automatically after every move. The current score
and board position are restored when the app is reopened. If the app
is interrupted mid-move the last tap is replayed against the saved
board on next launch so no progress is lost.

## Game over

The game ends when no two adjacent tiles of the same color remain.
The final score is shown along with your all-time high score. Tap
anywhere on the result screen to start a new game.

### Pure QML, one package for every phone (1.1.0)

App developer poetaster pointed out in the forum that these ports need no
compiled code. Since 1.1.0 the app is QML only: the system's `sailfish-qml`
launcher runs it, and one `noarch` package serves aarch64, 32 bit ARM and
x86, SailfishOS 3.4 to 5.1. Install with
`devel-su pkcon install-local harbour-asteroid-meteormatch-1.1.0-1.noarch.rpm`;
pkcon brings in the launcher (libsailfishapp-launcher) if it is missing.
The package is compressed with xz, because rpm on SailfishOS 3.4 cannot
unpack the zstd that newer SDKs use by default.

The saved board, score and high score moved from a QSettings file (C++) to dconf under `/apps/harbour-asteroid-meteormatch` (Nemo.Configuration, QML), and the fonts are loaded by QML FontLoaders. A game saved by an earlier version is not carried over.

Checked: installed and started without QML warnings on a Jolla C2 (5.1),
the Jolla Tablet (4.6) and a Jolla 1 (3.4).

```
Disclosure: LLMGD-3 · origin O1 (idea from a forum reply and the author's go; LLM-converted; start-checked by log on three devices; self-graded)
LLMGD: v0.2; assurance=A3; flags=T; origin={O0:.7,O1:.3}; origin_headline=O0; scope=packaging+code; graded-by=claude-opus-5-5; retrieval=author-side
```
