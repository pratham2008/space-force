# Gemini Project: Zero Vector

This document provides a comprehensive overview of the "Zero Vector" project, a cinematic arcade space shooter built with Flutter and the Flame engine.

## Project Overview

"Zero Vector" is a fast-paced, visually-rich space shooter game. It features dynamic wave transitions, a variety of enemy types (including mini-bosses and bosses), and a layered UI. The game is built using the Flutter framework and the Flame game engine, with Firebase integrated for backend services like leaderboards and user authentication.

### Key Technologies:

*   **Game Engine:** Flame
*   **Framework:** Flutter
*   **Backend:** Firebase (Authentication, Firestore)
*   **State Management:** The game's state is managed within the `ZeroVectorGame` class, using a state machine to handle different game phases (menu, playing, game over, etc.).

### Architecture:

The project follows a component-based architecture, typical of Flame games.

*   **`lib/main.dart`**: The entry point of the application, responsible for initializing Firebase and setting up the main game widget.
*   **`lib/game/zero_vector_game.dart`**: The core of the game, this class manages game state, entities, and game logic.
*   **`lib/game/components/`**: This directory contains the various game entities, such as the player, enemies, bosses, and UI components.
*   **`lib/game/managers/`**: This directory contains manager classes, such as the `EnemySpawnManager`, which encapsulates specific game logic.
*   **`lib/game/overlays/`**: This directory contains the UI overlays that are displayed on top of the game, such as the start menu, HUD, and game over screen.

## Building and Running

To build and run the project, you will need to have Flutter installed.

1.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

2.  **Run the game:**
    ```bash
    flutter run
    ```

### Testing

The project includes a basic widget test. To run the tests, use the following command:

```bash
flutter test
```

## Development Conventions

*   **State Management:** Game state is managed in the `ZeroVectorGame` class. Changes to the game state should be handled through methods in this class.
*   **Component-Based Architecture:** New game entities should be created as `Component` classes and added to the game world.
*   **Overlays:** UI elements that are not part of the game world should be implemented as overlays.
*   **Firebase Integration:** The game uses Firebase for leaderboards and user authentication. The `lib/game/services/` directory contains the services that interact with Firebase.
*   **Audio:** The game's audio is managed by the `AudioManager` class, which can be found in `lib/game/audio/audio_manager.dart`.
