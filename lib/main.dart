import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/zero_vector_game.dart';
import 'game/overlays/hud_overlay.dart';
import 'game/overlays/game_over_overlay.dart';
import 'game/overlays/start_menu_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final game = ZeroVectorGame();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: GameWidget(
          game: game,
          overlayBuilderMap: {
            Overlays.hud: (context, g) => HudOverlay(game: g as ZeroVectorGame),
            Overlays.gameOver: (context, g) => GameOverOverlay(game: g as ZeroVectorGame),
            Overlays.startMenu: (context, g) => StartMenuOverlay(game: g as ZeroVectorGame),
          },
          initialActiveOverlays: const [Overlays.startMenu],
        ),
      ),
    ),
  );
}
