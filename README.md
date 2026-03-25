# Meteor Match

A color-matching puzzle game for AsteroidOS watches.

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
