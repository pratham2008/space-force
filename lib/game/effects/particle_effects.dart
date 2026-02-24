import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

// Hard cap on simultaneous ParticleSystemComponents to prevent memory spikes.
// Call before game.add(explosionParticles(...)) to enforce the limit.
const int kMaxParticleSystems = 30;

/// Spawns a premium explosion at [origin]:
///   - Radial dot burst (10–15 particles)
///   - 8–12 line "raysparks"
///   - Expanding ring fade
///
/// Lifetime: 0.4 s
ParticleSystemComponent explosionParticles(Vector2 origin) {
  final rng = Random();

  // ── Dot burst ──────────────────────────────────────────────────────────────
  final dotCount = 10 + rng.nextInt(6);
  final dots = List<Particle>.generate(dotCount, (_) {
    final angle = rng.nextDouble() * 2 * pi;
    final speed = 40 + rng.nextDouble() * 110;
    final vx = cos(angle) * speed;
    final vy = sin(angle) * speed;
    final color = Color.lerp(
      const Color(0xFFFF6D00),
      const Color(0xFFFF1744),
      rng.nextDouble(),
    )!;
    final baseRadius = 2.0 + rng.nextDouble() * 2.5;

    return MovingParticle(
      from: Vector2.zero(),
      to: Vector2(vx * 0.4, vy * 0.4),
      child: ComputedParticle(
        renderer: (canvas, p) {
          final a = (1.0 - p.progress).clamp(0.0, 1.0);
          final r = baseRadius * (1.0 - p.progress * 0.6);
          canvas.drawCircle(
            Offset.zero,
            r,
            Paint()
              ..color = color.withValues(alpha: a)
              ..blendMode = BlendMode.plus,
          );
        },
      ),
    );
  });

  // ── Ray sparks (short radiating lines) ────────────────────────────────────
  final rayCount = 8 + rng.nextInt(5);
  final rays = List<Particle>.generate(rayCount, (_) {
    final angle = rng.nextDouble() * 2 * pi;
    final length = 12 + rng.nextDouble() * 20;
    final speed = 60 + rng.nextDouble() * 80;
    final vx = cos(angle) * speed;
    final vy = sin(angle) * speed;

    return MovingParticle(
      from: Vector2.zero(),
      to: Vector2(vx * 0.4, vy * 0.4),
      child: ComputedParticle(
        renderer: (canvas, p) {
          final a = (1.0 - p.progress).clamp(0.0, 1.0);
          final endX = cos(angle) * length * (1.0 - p.progress);
          final endY = sin(angle) * length * (1.0 - p.progress);
          canvas.drawLine(
            Offset.zero,
            Offset(endX, endY),
            Paint()
              ..color = const Color(0xFFFFAB00).withValues(alpha: a)
              ..strokeWidth = 1.5
              ..blendMode = BlendMode.plus,
          );
        },
      ),
    );
  });

  // ── Expanding ring ──────────────────────────────────────────────────────────
  final ring = ComputedParticle(
    renderer: (canvas, p) {
      final a = (1.0 - p.progress).clamp(0.0, 1.0);
      final r = 8 + 32 * p.progress;
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * (1.0 - p.progress)
          ..color = const Color(0xFFFF6D00).withValues(alpha: a * 0.7)
          ..blendMode = BlendMode.plus,
      );
    },
  );

  final all = [...dots, ...rays, ring];

  return ParticleSystemComponent(
    position: origin,
    particle: Particle.generate(
      count: all.length,
      lifespan: 0.4,
      generator: (i) => all[i],
    ),
  );
}

/// Spawns 4 small spark particles on a non-lethal hit.
ParticleSystemComponent sparkParticles(Vector2 origin) {
  final rng = Random();
  final particles = List<Particle>.generate(4, (_) {
    final angle = rng.nextDouble() * 2 * pi;
    final speed = 50 + rng.nextDouble() * 60;
    final vx = cos(angle) * speed;
    final vy = sin(angle) * speed;

    return MovingParticle(
      from: Vector2.zero(),
      to: Vector2(vx * 0.2, vy * 0.2),
      child: ComputedParticle(
        renderer: (canvas, p) {
          final a = (1.0 - p.progress).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset.zero,
            1.5,
            Paint()
              ..color = const Color(0xFFFFAB00).withValues(alpha: a)
              ..blendMode = BlendMode.plus,
          );
        },
      ),
    );
  });

  return ParticleSystemComponent(
    position: origin,
    particle: Particle.generate(
      count: particles.length,
      lifespan: 0.2,
      generator: (i) => particles[i],
    ),
  );
}
