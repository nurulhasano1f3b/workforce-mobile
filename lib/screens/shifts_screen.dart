import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../models/shift.dart';
import '../widgets/account_menu.dart';

// ---------------------------------------------------------------------------
// Providers
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

final shiftRequestsProvider = StreamProvider<List<ShiftRequest>>((ref) {
  final repo = ref.watch(shiftsRepositoryProvider);
  final ctrl = StreamController<List<ShiftRequest>>(sync: true);
  void listener() => ctrl.add(repo.requests.value);
  repo.requests.addListener(listener);
  ctrl.add(repo.requests.value);
  ref.onDispose(() {
    repo.requests.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

final shiftPeersProvider = StreamProvider<List<ShiftPeer>>((ref) {
  final repo = ref.watch(shiftsRepositoryProvider);
  final ctrl = StreamController<List<ShiftPeer>>(sync: true);
  void listener() => ctrl.add(repo.peers.value);
  repo.peers.addListener(listener);
  ctrl.add(repo.peers.value);
  ref.onDispose(() {
    repo.peers.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ShiftsScreen extends ConsumerStatefulWidget {
  const ShiftsScreen({super.key});

  @override
  ConsumerState<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends ConsumerState<ShiftsScreen> {
  Future<void> _respond(int requestId, bool accept) async {
    final repo = ref.read(shiftsRepositoryProvider);
    final ok = await repo.respondToRequest(requestId, accept);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? accept
                ? 'Shift accepted.'
                : 'Shift declined.'
            : 'Failed to respond. Try again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(shiftsListProvider);
    final isLoading = ref.watch(shiftsLoadingProvider).valueOrNull ?? false;
    final featureOn = ref.watch(shiftsFeatureProvider).valueOrNull ?? true;
    final requests = ref.watch(shiftRequestsProvider).valueOrNull ?? [];
    final peers = ref.watch(shiftPeersProvider).valueOrNull ?? [];

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
              onPressed: () => ref.read(shiftsRepositoryProvider).refresh(),
              tooltip: 'Refresh',
            ),
          const AccountMenu(),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: !featureOn
            ? const _FeatureUnavailable()
            : RefreshIndicator(
                color: const Color(0xFF1B8A5A),
                onRefresh: () => ref.read(shiftsRepositoryProvider).refresh(),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  children: [
                    // Pending requests — shown prominently at top.
                    if (requests.isNotEmpty) ...[
                      _SectionHeader(
                        label: 'Pending Requests',
                        badge: requests.length,
                      ),
                      const SizedBox(height: 8),
                      ...requests.map((r) => _RequestCard(
                            request: r,
                            onAccept: () => _respond(r.id, true),
                            onDecline: () => _respond(r.id, false),
                          )),
                      const SizedBox(height: 20),
                    ],

                    // My shifts
                    const _SectionHeader(label: 'Upcoming Shifts'),
                    const SizedBox(height: 8),
                    shiftsAsync.when(
                      data: (shifts) => shifts.isEmpty
                          ? const _EmptyShifts()
                          : _ShiftsGroup(shifts: shifts),
                      loading: () => const _EmptyShifts(),
                      error: (_, __) => const _EmptyShifts(),
                    ),

                    // Peers
                    if (peers.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const _SectionHeader(label: 'On shift with you'),
                      const SizedBox(height: 8),
                      _PeersRow(peers: peers),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.badge});
  final String label;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.8,
          ),
        ),
        if (badge != null && badge! > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Request card — tappable; opens detail sheet on tap
// ---------------------------------------------------------------------------

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });
  final ShiftRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ShiftRequestDetailSheet(
          request: r,
          onAccept: onAccept,
          onDecline: onDecline,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFBBF24).withAlpha(120)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFBBF24).withAlpha(30),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Shift Request',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  r.department ?? 'General',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: Color(0xFF9CA3AF)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Text(
                  _dateLabel(r.startsAt),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time_rounded,
                    size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  '${_fmt(r.startsAt)} – ${_fmt(r.endsAt)}',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _durationLabel(r.duration),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.touch_app_outlined, size: 13, color: Color(0xFFD97706)),
                SizedBox(width: 4),
                Text(
                  'Tap to review and respond',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${_weekday(dt.weekday)}, ${dt.day} ${_month(dt.month)}';
  }

  String _fmt(DateTime dt) {
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

  String _weekday(int w) =>
      const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w];

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

// ---------------------------------------------------------------------------
// Peers row
// ---------------------------------------------------------------------------

class _PeersRow extends StatelessWidget {
  const _PeersRow({required this.peers});
  final List<ShiftPeer> peers;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: peers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _PeerChip(peer: peers[i]),
      ),
    );
  }
}

class _PeerChip extends StatelessWidget {
  const _PeerChip({required this.peer});
  final ShiftPeer peer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1B8A5A).withAlpha(26),
            child: Text(
              peer.initials,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B8A5A),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            peer.fullName.split(' ').first,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shifts group (grouped by day)
// ---------------------------------------------------------------------------

class _ShiftsGroup extends StatelessWidget {
  const _ShiftsGroup({required this.shifts});
  final List<Shift> shifts;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Shift>>{};
    for (final shift in shifts) {
      final key = _dayLabel(shift.startsAt);
      grouped.putIfAbsent(key, () => []).add(shift);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayHeader(label: entry.key),
            const SizedBox(height: 8),
            ...entry.value.map((s) => _ShiftCard(shift: s)),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
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

  String _weekday(int w) => const [
        '', 'Monday', 'Tuesday', 'Wednesday',
        'Thursday', 'Friday', 'Saturday', 'Sunday'
      ][w];

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

// ---------------------------------------------------------------------------
// Shift card
// ---------------------------------------------------------------------------

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
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
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
                      fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          if (shift.status != 'published') _StatusBadge(status: shift.status),
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

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'draft' => ('Draft', const Color(0xFF9CA3AF)),
      'pending_accept' => ('Pending', const Color(0xFFD97706)),
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

// ---------------------------------------------------------------------------
// Day header
// ---------------------------------------------------------------------------

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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No upcoming shifts',
          style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shift request detail sheet — shows full info + both Accept / Decline
// ---------------------------------------------------------------------------

class _ShiftRequestDetailSheet extends StatefulWidget {
  const _ShiftRequestDetailSheet({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final ShiftRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<_ShiftRequestDetailSheet> createState() =>
      _ShiftRequestDetailSheetState();
}

class _ShiftRequestDetailSheetState extends State<_ShiftRequestDetailSheet> {
  bool _loading = false;

  Future<void> _respond(bool accepting) async {
    setState(() => _loading = true);
    accepting ? widget.onAccept() : widget.onDecline();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            r.isEdit ? 'Shift Change Request' : 'Shift Request',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            r.isEdit
                ? 'Your shift has been updated. Review the change, then accept or decline.'
                : 'Review the details below, then accept or decline.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),

          // Before / after cards (edit case) or single card (new shift)
          if (r.isEdit)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ShiftMiniCard(
                    label: 'Before',
                    startsAt: r.prevStartsAt!,
                    endsAt: r.prevEndsAt!,
                    department: r.prevDepartment,
                    accent: const Color(0xFF6B7280),
                    bgAlpha: 14,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 18, color: Colors.grey.shade400),
                ),
                Expanded(
                  child: _ShiftMiniCard(
                    label: 'After',
                    startsAt: r.startsAt,
                    endsAt: r.endsAt,
                    department: r.department,
                    accent: const Color(0xFF1B8A5A),
                    bgAlpha: 14,
                  ),
                ),
              ],
            )
          else
            _ShiftDetailCard(request: r),

          const SizedBox(height: 24),

          if (_loading)
            const Center(
              child: SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF1B8A5A),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respond(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Decline',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respond(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B8A5A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Accept',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${_weekday(dt.weekday)}, ${dt.day} ${_month(dt.month)}';
  }

  String _fmt(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $period';
  }

  String _weekday(int w) =>
      const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w];

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

// ---------------------------------------------------------------------------
// Single shift detail card (new-shift request)
// ---------------------------------------------------------------------------

class _ShiftDetailCard extends StatelessWidget {
  const _ShiftDetailCard({required this.request});
  final ShiftRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final d = r.duration;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final durationLabel = m == 0 ? '${h}h shift' : '${h}h ${m}m shift';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFBBF24).withAlpha(80), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              Text(
                _dateLabel(r.startsAt),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(
                '${_fmt(r.startsAt)} – ${_fmt(r.endsAt)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  size: 13, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 5),
              Text(
                '$durationLabel  ·  ${r.department ?? 'General'}',
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${_weekday(dt.weekday)}, ${dt.day} ${_month(dt.month)}';
  }

  String _fmt(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $period';
  }

  String _weekday(int w) =>
      const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w];

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

// ---------------------------------------------------------------------------
// Mini shift card used in before/after comparison
// ---------------------------------------------------------------------------

class _ShiftMiniCard extends StatelessWidget {
  const _ShiftMiniCard({
    required this.label,
    required this.startsAt,
    required this.endsAt,
    required this.accent,
    required this.bgAlpha,
    this.department,
  });

  final String label;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? department;
  final Color accent;
  final int bgAlpha;

  @override
  Widget build(BuildContext context) {
    final d = endsAt.difference(startsAt);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final durationLabel = m == 0 ? '${h}h' : '${h}h ${m}m';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withAlpha(bgAlpha),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(60), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _dateLabel(startsAt),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmt(startsAt)} –\n${_fmt(endsAt)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$durationLabel  ·  ${department ?? 'General'}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${_weekday(dt.weekday)}, ${dt.day} ${_month(dt.month)}';
  }

  String _fmt(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $period';
  }

  String _weekday(int w) =>
      const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w];

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}
