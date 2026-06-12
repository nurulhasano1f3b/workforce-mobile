import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'feed_screen.dart';
import 'manager_screen.dart';
import 'me_screen.dart';
import 'messages_screen.dart';
import 'punch_screen.dart';
import 'shifts_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 1;

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
    ref
        .read(managerRepositoryProvider)
        .isManager
        .removeListener(_onManagerChanged);
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
    final screens = [
      const ShiftsScreen(),
      const PunchScreen(),
      const FeedScreen(),
      const MessagesScreen(),
      const MeScreen(),
      if (_isManager) const ManagerScreen(),
    ];

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
            icon: Icon(Icons.dynamic_feed_outlined),
            activeIcon: Icon(Icons.dynamic_feed_rounded),
            label: 'Feed',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum_rounded),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Me',
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
