/// Hittable mixin — applied to all damageable game entities.
///
/// This allows [Bullet] (and any future projectile) to call `hit(damage)`
/// on any entity via a single `other is Hittable` check, without requiring
/// them to share a common superclass.
mixin Hittable {
  void hit(int damage);
}
