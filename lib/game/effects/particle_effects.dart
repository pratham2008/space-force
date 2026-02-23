import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// Spawns a radial explosion burst of 10–15 particles at [origin].
/// Orange/red palette, fade + shrink, 0.4 s lifetime.
ParticleSystemComponent explosionParticles(Vector2 origin) {
  final rng = Random();
  final count = 10 + rng.nextInt(6); // 10 – 15

  final particles = List<Particle>.generate(count, (_) {
    final angle = rng.nextDouble() * 2 * pi;
    final speed = 40 + rng.nextDouble() * 100; // px/s
    final vx = cos(angle) * speed;
    final vy = sin(angle) * speed;

    // Pick a random orange/red hue
    final color = Color.lerp(
      const Color(0xFFFF6D00), // orange
      const Color(0xFFFF1744), // red
      rng.nextDouble(),
    )!;

    final baseRadius = 2.0 + rng.nextDouble() * 2.5;

    return MovingParticle(
      from: Vector2.zero(),
      to: Vector2(vx * 0.4, vy * 0.4), // distance over lifespan
      child: ComputedParticle(
        renderer: (canvas, particle) {
          final progress = particle.progress; // 0 → 1
          final alpha = (1.0 - progress).clamp(0.0, 1.0);
          final radius = baseRadius * (1.0 - progress * 0.6);
          final paint = Paint()
            ..color = color.withValues(alpha: alpha);
          canvas.drawCircle(Offset.zero, radius, paint);
        },
      ),
    );
  });

  return ParticleSystemComponent(
    position: origin,
    particle: Particle.generate(
      count: particles.length,
      lifespan: 0.4,
      generator: (i) => particles[i],
    ),
  );
}

/// Spawns 4 small spark particles at [origin] on a non-lethal hit.
/// 0.2 s lifetime, small and fast.
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
        renderer: (canvas, particle) {
          final alpha = (1.0 - particle.progress).clamp(0.0, 1.0);
          final paint = Paint()
            ..color = const Color(0xFFFFAB00).withValues(alpha: alpha);
          canvas.drawCircle(Offset.zero, 1.5, paint);
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
