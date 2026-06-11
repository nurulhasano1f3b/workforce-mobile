import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'availability_screen.dart';
import 'manager_screen.dart';
import 'notifications_screen.dart' show NotificationsScreen, notificationsListProvider;
import 'punch_screen.dart';
import 'shifts_screen.dart';

/// HomeScreen — the main scaffold after login.
///
/// Tabs:
///   0 — My Shifts
///   1 — Punch (the primary action, centre)
///   2 — Availability
///   3 — Notifications
///   4 — Manager (only visible to users with roster.edit access)
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

  bool _isManager = false;

  @override
  void initState() {
    super.initState();
    final managerRepo = ref.read(managerRepositoryProvider);
    _isManager = managerRepo.isManager.value;
    managerRepo.isManager.addListener(_onManagerChanged);
  }

  @override
  void dispose() {
    ref.read(managerRepositoryProvider).isManager.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onManagerChanged() {
    final val = ref.read(managerRepositoryProvider).isManager.value;
    if (val != _isManager) {
      setState(() => _isManager = val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        ref.watch(notificationsListProvider).valueOrNull
                ?.where((n) => !n.isRead)
                .length ??
            0;

    // Tab index mapping: 0=Shifts, 1=Punch, 2=Avail, 3=Notif, [4=Manager if isManager]
    final screens = [
      const ShiftsScreen(),
      const PunchScreen(),
      const AvailabilityScreen(),
      const NotificationsScreen(),
      if (_isManager) const ManagerScreen(),
    ];

    // Clamp tab index in case manager tab disappears.
    final safeTab = _tab.clamp(0, screens.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: safeTab,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeTab,
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
        type: BottomNavigationBarType.fixed,
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.event_available_outlined),
            activeIcon: Icon(Icons.event_available_rounded),
            label: 'Availability',
          ),
          BottomNavigationBarItem(
            icon: unreadCount > 0
                ? Badge(
                    label: Text('$unreadCount'),
                    child: const Icon(Icons.notifications_none_rounded),
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
          if (_isManager)
            const BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts_outlined),
              activeIcon: Icon(Icons.manage_accounts_rounded),
              label: 'Manager',
            ),
        ],
      ),
    );
  }
}
