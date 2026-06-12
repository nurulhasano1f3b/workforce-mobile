import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'announcements_repository.dart';
import 'availability_repository.dart';
import 'feed_repository.dart';
import 'leaves_repository.dart';
import 'manager_repository.dart';
import 'messages_repository.dart';
import 'notifications_repository.dart';
import 'payslips_repository.dart';
import 'punch_repository.dart';
import 'shifts_repository.dart';
import 'user_repository.dart';

// ---------------------------------------------------------------------------
// Repository providers — one instance each for the lifetime of the app.
// ---------------------------------------------------------------------------

final punchRepositoryProvider = Provider<PunchRepository>((ref) {
  final repo = PunchRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final shiftsRepositoryProvider = Provider<ShiftsRepository>((ref) {
  final repo = ShiftsRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  final repo = NotificationsRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final repo = UserRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  final repo = AvailabilityRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final managerRepositoryProvider = Provider<ManagerRepository>((ref) {
  final repo = ManagerRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final leavesRepositoryProvider = Provider<LeavesRepository>((ref) {
  final repo = LeavesRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final payslipsRepositoryProvider = Provider<PayslipsRepository>((ref) {
  final repo = PayslipsRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  final repo = MessagesRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final repo = FeedRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final announcementsRepositoryProvider =
    Provider<AnnouncementsRepository>((ref) {
  final repo = AnnouncementsRepository();
  ref.onDispose(repo.dispose);
  return repo;
});
