import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'availability_repository.dart';
import 'notifications_repository.dart';
import 'punch_repository.dart';
import 'shifts_repository.dart';
import 'user_repository.dart';

// ---------------------------------------------------------------------------
// Repository providers — one instance each for the lifetime of the app.
// ---------------------------------------------------------------------------

/// The pre-warmed PunchRepository.
/// In main() the provider is overridden with the already-init'd instance so
/// init() is never called twice.
final punchRepositoryProvider = Provider<PunchRepository>((ref) {
  final repo = PunchRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// ShiftsRepository — shares the LocalDb singleton.
final shiftsRepositoryProvider = Provider<ShiftsRepository>((ref) {
  final repo = ShiftsRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// NotificationsRepository — shares the LocalDb singleton.
final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  final repo = NotificationsRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// UserRepository — fetches and caches the /me profile.
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final repo = UserRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// AvailabilityRepository — weekly pattern + exceptions.
final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  final repo = AvailabilityRepository();
  ref.onDispose(repo.dispose);
  return repo;
});
