import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../models/shift.dart';
import '../widgets/account_menu.dart';

// ---------------------------------------------------------------------------
// Providers (defined here, imported by home_screen via punch_repository)
// ---------------------------------------------------------------------------

final shiftsListProvider = StreamProvider<List<Shift>>((ref) {
  final repo = ref.watch(shiftsRepositoryProvider);
  final ctrl = StreamController<List<Shift>>(sync: true);
  void listener() => ctrl.add(repo.shifts.value);
  repo.shifts.addListener(listener);
  ctrl.add(repo.shifts.value);
  ref.onDispose(() {
    repo.shifts.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

final shiftsLoadingProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(shiftsRepositoryProvider);
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

final shiftsFeatureProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(shiftsRepositoryProvider);
  final ctrl = StreamController<bool>(sync: true);
  void listener() => ctrl.add(repo.featureAvailable.value);
  repo.featureAvailable.addListener(listener);
  ctrl.add(repo.featureAvailable.value);
  ref.onDispose(() {
    repo.featureAvailable.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(shiftsListProvider);
    final isLoading = ref.watch(shiftsLoadingProvider).valueOrNull ?? false;
    final featureOn = ref.watch(shiftsFeatureProvider).valueOrNull ?? true;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Shifts',
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
                  ref.read(shiftsRepositoryProvider).refresh(),
              tooltip: 'Refresh',
            ),
          const AccountMenu(),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: !featureOn
            ? const _FeatureUnavailable()
            : shiftsAsync.when(
                data: (shifts) => shifts.isEmpty
                    ? const _EmptyShifts()
                    : _ShiftsList(shifts: shifts),
                loading: () => const _EmptyShifts(),
                error: (_, __) => const _EmptyShifts(),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feature unavailable
// ---------------------------------------------------------------------------

class _FeatureUnavailable extends StatelessWidget {
  const _FeatureUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text(
              'Roster feature not available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This feature is not enabled for your store yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyShifts extends StatelessWidget {
  const _EmptyShifts();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text(
              'No upcoming shifts',
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
// Shifts list
// ---------------------------------------------------------------------------

class _ShiftsList extends StatelessWidget {
  const _ShiftsList({required this.shifts});
  final List<Shift> shifts;

  @override
  Widget build(BuildContext context) {
    // Group by day
    final grouped = <String, List<Shift>>{};
    for (final shift in shifts) {
      final key = _dayLabel(shift.startsAt);
      grouped.putIfAbsent(key, () => []).add(shift);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: grouped.length,
      itemBuilder: (context, i) {
        final day = grouped.keys.elementAt(i);
        final dayShifts = grouped[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayHeader(label: day),
            const SizedBox(height: 8),
            ...dayShifts.map((s) => _ShiftCard(shift: s)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shiftDay = DateTime(dt.year, dt.month, dt.day);
    final diff = shiftDay.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${_weekday(dt.weekday)}, ${dt.day} ${_month(dt.month)}';
  }

  String _weekday(int w) {
    const names = [
      '', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return names[w];
  }

  String _month(int m) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[m];
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift});
  final Shift shift;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time block
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B8A5A).withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _formatTime(shift.startsAt),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B8A5A),
                  ),
                ),
                const Text(
                  'to',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  _formatTime(shift.endsAt),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B8A5A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.department ?? 'General',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _durationLabel(shift.duration),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          if (shift.status != 'published')
            _StatusBadge(status: shift.status),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $period';
  }

  String _durationLabel(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (mins == 0) return '${hours}h shift';
    return '${hours}h ${mins}m shift';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'draft' => ('Draft', const Color(0xFF9CA3AF)),
      'pending' => ('Pending', const Color(0xFFD97706)),
      _ => (status, const Color(0xFF6B7280)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        border: Border.all(color: color.withAlpha(80)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
