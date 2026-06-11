import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../models/notification_item.dart';
import '../widgets/account_menu.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final notificationsListProvider =
    StreamProvider<List<NotificationItem>>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  final ctrl = StreamController<List<NotificationItem>>(sync: true);
  void listener() => ctrl.add(repo.notifications.value);
  repo.notifications.addListener(listener);
  ctrl.add(repo.notifications.value);
  ref.onDispose(() {
    repo.notifications.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

final notificationsLoadingProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  final ctrl = StreamController<bool>(sync: true);
  void listener() => ctrl.add(repo.isLoading.value);
  repo.isLoading.addListener(listener);
  ctrl.add(repo.isLoading.value);
  ref.onDispose(() {
    repo.isLoading.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final isLoading =
        ref.watch(notificationsLoadingProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Color(0xFF9CA3AF), size: 20),
              onPressed: () =>
                  ref.read(notificationsRepositoryProvider).refresh(),
              tooltip: 'Refresh',
            ),
          const AccountMenu(),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: notificationsAsync.when(
          data: (items) => items.isEmpty
              ? const _EmptyNotifications()
              : _NotificationsList(items: items),
          loading: () => const _EmptyNotifications(),
          error: (_, __) => const _EmptyNotifications(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications list
// ---------------------------------------------------------------------------

class _NotificationsList extends ConsumerWidget {
  const _NotificationsList({required this.items});
  final List<NotificationItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _NotificationTile(
        item: items[i],
        onTap: () {
          if (!items[i].isRead) {
            ref
                .read(notificationsRepositoryProvider)
                .markRead(items[i].id);
          }
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread
              ? const Color(0xFFECFDF5)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread
                ? const Color(0xFF6EE7B7)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 10),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnread
                      ? const Color(0xFF1B8A5A)
                      : Colors.transparent,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF111827),
                      fontWeight: isUnread
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(item.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            if (item.pendingRead)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFF9CA3AF),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
