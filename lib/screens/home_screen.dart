import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications_screen.dart';
import 'punch_screen.dart';
import 'shifts_screen.dart';

/// HomeScreen — the main scaffold after login.
///
/// Three tabs via BottomNavigationBar:
///   0 — My Shifts
///   1 — Punch (the primary action, centre)
///   2 — Notifications
///
/// Each tab is kept alive via IndexedStack so switching tabs doesn't rebuild
/// or lose scroll position.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 1; // Start on the Punch tab.

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        ref.watch(notificationsListProvider).valueOrNull
                ?.where((n) => !n.isRead)
                .length ??
            0;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          ShiftsScreen(),
          PunchScreen(),
          NotificationsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1B8A5A),
        unselectedItemColor: const Color(0xFF9CA3AF),
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        elevation: 8,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'Shifts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.fingerprint_outlined),
            activeIcon: Icon(Icons.fingerprint),
            label: 'Punch',
          ),
          BottomNavigationBarItem(
            icon: unreadCount > 0
                ? Badge(
                    label: Text('$unreadCount'),
                    child: const Icon(
                        Icons.notifications_none_rounded),
                  )
                : const Icon(Icons.notifications_none_rounded),
            activeIcon: unreadCount > 0
                ? Badge(
                    label: Text('$unreadCount'),
                    child: const Icon(Icons.notifications_rounded),
                  )
                : const Icon(Icons.notifications_rounded),
            label: 'Notifications',
          ),
        ],
      ),
    );
  }
}
