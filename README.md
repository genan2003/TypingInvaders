# Typing Invaders

This is a simple typing game written in x86 assembly language. The game is a DOS-based application where letters fall from the top of the screen, and the player must type the correct character to score points.

## Gameplay

-   Letters fall from the top of the screen one by one.
-   The player must press the corresponding key on the keyboard before the letter reaches the bottom.
-   If the correct key is pressed, the player's score increases.
-   If the letter reaches the bottom or the wrong key is pressed, it may count as a miss.
-   The game keeps track of a high score list.

## Features

-   Classic arcade-style gameplay.
-   High score tracking for the top players.
-   Player name entry (3 characters).
-   Direct interaction with hardware through assembly language.

## How to Assemble and Run

This game is designed to be run in a DOS environment. You will need an x86 assembler like NASM or TASM and a DOS emulator like DOSBox.

1.  **Assemble the code:**
    To create the executable `.COM` file, use your assembler of choice. For example, with NASM:
    ```sh
    nasm type_invaders.asm -f bin -o type_invaders.com
    ```

2.  **Run the game:**
    Mount the directory containing the game in DOSBox and run the `.com` file.
    ```
    mount c .
    c:
    type_invaders.com
    ```

## Code
The game logic is contained in `type_invaders.asm`. It handles screen drawing, player input, scoring, and file I/O for the high score list.
