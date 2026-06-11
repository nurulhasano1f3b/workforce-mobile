import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';

class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_Action>(
      icon: const Icon(
        Icons.person_outline_rounded,
        color: Color(0xFF6B7280),
        size: 22,
      ),
      onSelected: (action) async {
        switch (action) {
          case _Action.profile:
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          case _Action.signOut:
            final punchRepo = ref.read(punchRepositoryProvider);
            final shiftsRepo = ref.read(shiftsRepositoryProvider);
            final notifRepo = ref.read(notificationsRepositoryProvider);
            final availRepo = ref.read(availabilityRepositoryProvider);
            final userRepo = ref.read(userRepositoryProvider);

            final managerRepo = ref.read(managerRepositoryProvider);

            await punchRepo.logout();
            shiftsRepo.updateToken(null);
            notifRepo.updateToken(null);
            availRepo.updateToken(null);
            managerRepo.updateToken(null);
            userRepo.clear();

            if (context.mounted) {
              unawaited(Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              ));
            }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _Action.profile,
          child: Row(
            children: [
              Icon(Icons.person_rounded, size: 18, color: Color(0xFF374151)),
              SizedBox(width: 10),
              Text('My profile',
                  style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _Action.signOut,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: Color(0xFF374151)),
              SizedBox(width: 10),
              Text('Sign out',
                  style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Action { profile, signOut }
