import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../models/user_profile.dart';
import '../widgets/account_menu.dart';
import 'availability_screen.dart';
import 'leaves_screen.dart';
import 'notifications_screen.dart' show NotificationsScreen, notificationsListProvider;
import 'payslips_screen.dart';

final _profileProvider = StreamProvider<UserProfile?>((ref) {
  final repo = ref.watch(userRepositoryProvider);
  final ctrl = StreamController<UserProfile?>(sync: true);
  void listener() => ctrl.add(repo.profile.value);
  repo.profile.addListener(listener);
  ctrl.add(repo.profile.value);
  ref.onDispose(() {
    repo.profile.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(_profileProvider).valueOrNull;
    final unreadCount =
        ref.watch(notificationsListProvider).valueOrNull
                ?.where((n) => !n.isRead)
                .length ??
            0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Me',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: const [AccountMenu(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            if (profile != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          const Color(0xFF1B8A5A).withAlpha(22),
                      child: Text(
                        _initials(profile.fullName),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B8A5A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            profile.primaryRole?.displayName ?? 'Team Member',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            const _SectionHeader(label: 'My Info'),
            const SizedBox(height: 8),

            _MenuTile(
              icon: Icons.beach_access_outlined,
              label: 'Leave Requests',
              subtitle: 'View and submit leave',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeavesScreen()),
              ),
            ),
            _MenuTile(
              icon: Icons.receipt_long_outlined,
              label: 'Payslips',
              subtitle: 'View your pay history',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PayslipsScreen()),
              ),
            ),
            _MenuTile(
              icon: Icons.event_available_outlined,
              label: 'Availability',
              subtitle: 'Manage your weekly availability',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AvailabilityScreen()),
              ),
            ),
            _MenuTile(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              subtitle: unreadCount > 0
                  ? '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}'
                  : 'View your notifications',
              badge: unreadCount,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const NotificationsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1B8A5A).withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF1B8A5A)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                ],
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
