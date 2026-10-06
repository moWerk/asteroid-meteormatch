# Review and architecture hints: Meteor Match for SailfishOS

For anyone reviewing the `sailfishos` branch: where the code comes from, how it is laid out, what is worth reading and what is boilerplate.

## Where the code comes from

The app is the AsteroidOS watch app on `main`. This branch forks from it at `3a59704`, and its commits are the SailfishOS port. The reliable view of what the port changed:

    git diff 3a59704 sailfishos -- qml src rpm '*.pro' '*.desktop'

Many port edits carry a `SailfishOS:` comment, but not all of them. Each commit message says what changed, why, and what was not checked, and ends with an LLMGD line grading it.

The port was written by an LLM (Claude), directed and tested by the author, who has not read the code. Everything here is a prototype until a reviewer owns it. That is the point of this file.

## Architecture

- `qml/harbour-asteroid-meteormatch.qml`: the Silica `ApplicationWindow`. It sizes `Dims` from the screen width, then loads the app (`game/main.qml`). When the app goes to the background, the same item is moved into the cover and scaled down, so the home screen tile shows it live. The same shell is used in all eight ports.
- `qml/game/Dims.qml`, `Label.qml`, `HighlightBar.qml`, `Icon.qml`, `PageHeader.qml`, `ValueCycler.qml`, `IntSelector.qml`, `DeviceSpecs.qml` (whichever exist here): small stand-ins for AsteroidOS's `org.asteroid.controls` and `org.asteroid.utils`, so the watch QML runs unchanged where possible. Each is a few dozen lines.
- `qml/game/main.qml` (about 250 lines): app frame, score, game over.
- `qml/game/GameBoard.qml` (about 800 lines) is the game: board model (~105), flood fill (~192), gravity as a pure computation (~267) and its animation (~352), cascades (~444), the death wave (~451), the tap handler (~541), zoom and viewport (~567, ~603), pan and tap input (~685).
- `qml/game/Tile.qml`: one meteor.
- `qml/game/GameStorage.qml`: QML singleton, kept in dconf (`/apps/harbour-asteroid-meteormatch`). Board, score, pan and a pending tap are saved on every change, so a game survives the app being killed. It replaced a C++ QSettings class with the same API.
- Packaging: pure QML, no binary. `Exec=sailfish-qml harbour-asteroid-meteormatch` (package `libsailfishapp-launcher`), the `.pro` is `TEMPLATE = aux` with plain `INSTALLS`, and the spec is `BuildArch: noarch` with an xz payload (rpm 4.14 on SailfishOS 3.4 can not unpack the zstd of newer SDKs).

## Read these first

1. `GameBoard.qml`, flood fill and gravity: the core rules.
2. The save path: `GameStorage` is written on every change, including during cascades. Check whether the write rate to dconf is acceptable or should be batched.
3. Pan and tap input: the phone shows more rows of the same board. There is deliberately no pinch zoom, because the collapsing mechanic would make the game trivial.

## Skim

Stand-ins, icons, translations, packaging.

## Worth questioning

- The only one of the eight that passed the Jolla Store validator from the start (no sensors).
- A game saved by a version before 1.1.0 is not migrated.

## How it was tested

By the author, by playing it on a Jolla C2 (SailfishOS 5.1), the Jolla Tablet (4.6, x86) and a Jolla 1 (3.4, 32-bit ARM), with the same noarch package on all three. Before each handover, the LLM checked builds, package contents and start logs on those devices.

There are no automated tests; the on-device checks are listed in the commit messages.
