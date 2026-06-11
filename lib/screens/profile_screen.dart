import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../models/user_profile.dart';

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

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_profileProvider);
    final profile = profileAsync.valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF374151)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Color(0xFF9CA3AF), size: 20),
            onPressed: () => ref.read(userRepositoryProvider).refresh(),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + name header
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor:
                                const Color(0xFF1B8A5A).withAlpha(26),
                            child: Text(
                              _initials(profile.fullName),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B8A5A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            profile.fullName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (profile.primaryRole != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              profile.primaryRole!.displayName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Info section
                    _SectionHeader(label: 'Account'),
                    const SizedBox(height: 8),
                    _InfoTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: profile.email,
                    ),
                    _InfoTile(
                      icon: Icons.badge_outlined,
                      label: 'Employee ID',
                      value: '#${profile.id}',
                    ),

                    if (profile.roles.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(label: 'Roles & Access'),
                      const SizedBox(height: 8),
                      ...profile.roles.map((r) => _RoleTile(role: r)),
                    ],
                  ],
                ),
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
        color: Color(0xFF9CA3AF),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1B8A5A).withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 18,
              color: Color(0xFF1B8A5A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                if (role.scopeStore != null)
                  Text(
                    'Store #${role.scopeStore}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
