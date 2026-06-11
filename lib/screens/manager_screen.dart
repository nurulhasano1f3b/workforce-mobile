import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../models/manager_models.dart';
import '../widgets/account_menu.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _dailyViewProvider = StreamProvider<List<StaffDayView>>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  final ctrl = StreamController<List<StaffDayView>>(sync: true);
  void listener() => ctrl.add(repo.dailyView.value);
  repo.dailyView.addListener(listener);
  ctrl.add(repo.dailyView.value);
  ref.onDispose(() {
    repo.dailyView.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

final _selectedDateProvider = StreamProvider<DateTime>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  final ctrl = StreamController<DateTime>(sync: true);
  void listener() => ctrl.add(repo.selectedDate.value);
  repo.selectedDate.addListener(listener);
  ctrl.add(repo.selectedDate.value);
  ref.onDispose(() {
    repo.selectedDate.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

final _loadingProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
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

class ManagerScreen extends ConsumerStatefulWidget {
  const ManagerScreen({super.key});

  @override
  ConsumerState<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends ConsumerState<ManagerScreen> {
  Future<void> _prevDay() async {
    final repo = ref.read(managerRepositoryProvider);
    await repo.setDate(
        repo.selectedDate.value.subtract(const Duration(days: 1)));
  }

  Future<void> _nextDay() async {
    final repo = ref.read(managerRepositoryProvider);
    await repo.setDate(repo.selectedDate.value.add(const Duration(days: 1)));
  }

  Future<void> _pickDate() async {
    final repo = ref.read(managerRepositoryProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: repo.selectedDate.value,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1B8A5A)),
        ),
        child: child!,
      ),
    );
    if (picked != null) await repo.setDate(picked);
  }

  void _openCreateSheet({StaffDayView? forStaff}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateShiftSheet(preselectedStaff: forStaff),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(_selectedDateProvider).valueOrNull ?? DateTime.now();
    final isLoading = ref.watch(_loadingProvider).valueOrNull ?? false;
    final dailyAsync = ref.watch(_dailyViewProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Manager',
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
              onPressed: () => ref.read(managerRepositoryProvider).refresh(),
            ),
          const AccountMenu(),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date selector bar
            _DateBar(
              date: date,
              onPrev: _prevDay,
              onNext: _nextDay,
              onTap: _pickDate,
            ),
            // Staff list
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF1B8A5A),
                onRefresh: () => ref.read(managerRepositoryProvider).refresh(),
                child: dailyAsync.when(
                  data: (views) => views.isEmpty
                      ? const _EmptyState()
                      : _StaffList(
                          views: views,
                          onAddShift: (v) => _openCreateSheet(forStaff: v),
                        ),
                  loading: () => const _EmptyState(),
                  error: (_, __) => const _EmptyState(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(),
        backgroundColor: const Color(0xFF1B8A5A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Shift',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date bar
// ---------------------------------------------------------------------------

class _DateBar extends StatelessWidget {
  const _DateBar({
    required this.date,
    required this.onPrev,
    required this.onNext,
    required this.onTap,
  });

  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: Color(0xFF374151)),
            onPressed: onPrev,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                children: [
                  Text(
                    isToday
                        ? 'Today'
                        : _weekdays[date.weekday % 7],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isToday
                          ? const Color(0xFF1B8A5A)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    '${_months[date.month - 1]} ${date.day}, ${date.year}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF374151)),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }

  static const _weekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
}

// ---------------------------------------------------------------------------
// Staff list
// ---------------------------------------------------------------------------

class _StaffList extends StatelessWidget {
  const _StaffList({required this.views, required this.onAddShift});
  final List<StaffDayView> views;
  final void Function(StaffDayView) onAddShift;

  @override
  Widget build(BuildContext context) {
    final withShifts = views.where((v) => v.shifts.isNotEmpty).toList();
    final withoutShifts = views.where((v) => v.shifts.isEmpty).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (withShifts.isNotEmpty) ...[
          _SectionLabel(
              label: 'Scheduled (${withShifts.length})'),
          const SizedBox(height: 8),
          ...withShifts.map((v) => _StaffCard(
                view: v,
                onAddShift: () => onAddShift(v),
              )),
          const SizedBox(height: 16),
        ],
        _SectionLabel(label: 'Staff (${withoutShifts.length})'),
        const SizedBox(height: 8),
        ...withoutShifts.map((v) => _StaffCard(
              view: v,
              onAddShift: () => onAddShift(v),
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Staff card
// ---------------------------------------------------------------------------

class _StaffCard extends ConsumerStatefulWidget {
  const _StaffCard({required this.view, required this.onAddShift});
  final StaffDayView view;
  final VoidCallback onAddShift;

  @override
  ConsumerState<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends ConsumerState<_StaffCard> {
  bool _publishing = false;
  bool _deleting = false;

  Future<void> _publish(int shiftId) async {
    setState(() => _publishing = true);
    final repo = ref.read(managerRepositoryProvider);
    final result = await repo.publishShift(shiftId);
    if (!mounted) return;
    setState(() => _publishing = false);
    final msg = result == null
        ? 'Failed to publish.'
        : result.status == 'published'
            ? 'Shift published.'
            : 'Shift request sent to staff member.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _delete(int shiftId) async {
    setState(() => _deleting = true);
    final ok = await ref.read(managerRepositoryProvider).deleteShift(shiftId);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to delete.'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Column(
        children: [
          // Staff header row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _AvailDot(available: v.available, isException: v.isException),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      const Color(0xFF1B8A5A).withAlpha(22),
                  child: Text(
                    v.initials,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B8A5A),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.fullName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        _availLabel(v),
                        style: TextStyle(
                          fontSize: 12,
                          color: _availLabelColor(v),
                        ),
                      ),
                    ],
                  ),
                ),
                // Add shift button (only when not scheduled)
                if (v.shifts.isEmpty)
                  GestureDetector(
                    onTap: widget.onAddShift,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B8A5A).withAlpha(18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '+ Shift',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B8A5A),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Shift chips
          if (v.shifts.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(left: 14, right: 14, bottom: 12),
              child: Column(
                children: v.shifts.map((sh) {
                  return _ShiftRow(
                    shift: sh,
                    publishing: _publishing,
                    deleting: _deleting,
                    onPublish: sh.status == 'draft'
                        ? () => _publish(sh.id)
                        : null,
                    onDelete: sh.status != 'published'
                        ? () => _delete(sh.id)
                        : null,
                    onAddAnother: widget.onAddShift,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _availLabel(StaffDayView v) {
    if (v.available == null) return 'No availability set';
    if (!v.available!) {
      return v.isException ? 'Exception: unavailable' : 'Unavailable';
    }
    final from = v.startMin != null ? _fmtMin(v.startMin!) : '';
    final to = v.endMin != null ? _fmtMin(v.endMin!) : '';
    final tag = v.isException ? 'Exception: ' : '';
    return '${tag}Available $from–$to';
  }

  Color _availLabelColor(StaffDayView v) {
    if (v.available == null) return const Color(0xFF9CA3AF);
    if (!v.available!) return const Color(0xFFB91C1C);
    return v.isException
        ? const Color(0xFFD97706)
        : const Color(0xFF1B8A5A);
  }

  String _fmtMin(int m) {
    final h = m ~/ 60;
    final min = (m % 60).toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$min $period';
  }
}

// ---------------------------------------------------------------------------
// Availability dot
// ---------------------------------------------------------------------------

class _AvailDot extends StatelessWidget {
  const _AvailDot({this.available, this.isException = false});
  final bool? available;
  final bool isException;

  @override
  Widget build(BuildContext context) {
    final color = available == null
        ? const Color(0xFFD1D5DB)
        : !available!
            ? const Color(0xFFEF4444)
            : isException
                ? const Color(0xFFF59E0B)
                : const Color(0xFF22C55E);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// Shift row within a staff card
// ---------------------------------------------------------------------------

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({
    required this.shift,
    required this.publishing,
    required this.deleting,
    this.onPublish,
    this.onDelete,
    required this.onAddAnother,
  });

  final TeamShift shift;
  final bool publishing;
  final bool deleting;
  final VoidCallback? onPublish;
  final VoidCallback? onDelete;
  final VoidCallback onAddAnother;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (shift.status) {
      'published' => ('Published', const Color(0xFF1B8A5A)),
      'pending_accept' => ('Pending Accept', const Color(0xFFD97706)),
      'declined' => ('Declined', const Color(0xFFB91C1C)),
      _ => ('Draft', const Color(0xFF9CA3AF)),
    };

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_fmtTime(shift.startsAt)} – ${_fmtTime(shift.endsAt)}  ·  ${shift.department ?? 'General'}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  border:
                      Border.all(color: statusColor.withAlpha(80)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (onPublish != null || onDelete != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onPublish != null)
                  _ActionButton(
                    label: publishing ? 'Publishing…' : 'Publish',
                    color: const Color(0xFF1B8A5A),
                    onTap: publishing ? null : onPublish,
                  ),
                if (onPublish != null && onDelete != null)
                  const SizedBox(width: 8),
                if (onDelete != null)
                  _ActionButton(
                    label: deleting ? 'Deleting…' : 'Delete',
                    color: const Color(0xFFB91C1C),
                    onTap: deleting ? null : onDelete,
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: onAddAnother,
                  child: const Text(
                    '+ Another',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $period';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.label, required this.color, this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          border: Border.all(color: color.withAlpha(80)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
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

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text(
              'No staff data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Pull down to refresh.',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create shift bottom sheet
// ---------------------------------------------------------------------------

class _CreateShiftSheet extends ConsumerStatefulWidget {
  const _CreateShiftSheet({this.preselectedStaff});
  final StaffDayView? preselectedStaff;

  @override
  ConsumerState<_CreateShiftSheet> createState() => _CreateShiftSheetState();
}

class _CreateShiftSheetState extends ConsumerState<_CreateShiftSheet> {
  StaffMember? _selectedStaff;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  String _department = 'general';
  bool _saving = false;
  String? _error;

  static const _departments = [
    'general', 'produce', 'dairy', 'bakery',
    'deli', 'frozen', 'cashier', 'stockroom',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedStaff != null) {
      final s = widget.preselectedStaff!;
      // Pre-fill time from availability if available.
      if (s.startMin != null) {
        _startTime = TimeOfDay(hour: s.startMin! ~/ 60, minute: s.startMin! % 60);
      }
      if (s.endMin != null) {
        _endTime = TimeOfDay(hour: s.endMin! ~/ 60, minute: s.endMin! % 60);
      }
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1B8A5A)),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    final repo = ref.read(managerRepositoryProvider);
    final staffList = repo.staff.value;

    // Resolve staff member.
    StaffMember? member;
    if (widget.preselectedStaff != null) {
      member = staffList
          .where((s) => s.id == widget.preselectedStaff!.userId)
          .firstOrNull;
    } else {
      member = _selectedStaff;
    }
    if (member == null) {
      setState(() => _error = 'Please select a staff member.');
      return;
    }

    final baseDate = repo.selectedDate.value;
    final starts = DateTime(baseDate.year, baseDate.month, baseDate.day,
        _startTime.hour, _startTime.minute);
    var ends = DateTime(baseDate.year, baseDate.month, baseDate.day,
        _endTime.hour, _endTime.minute);
    // Handle overnight shift.
    if (ends.isBefore(starts)) ends = ends.add(const Duration(days: 1));

    if (ends == starts) {
      setState(() => _error = 'Start and end time cannot be the same.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await repo.createAndPublish(
      userId: member.id,
      startsAt: starts,
      endsAt: ends,
      department: _department,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result == null) {
      setState(() => _error = 'Failed to create shift. Try again.');
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.status == 'published'
            ? 'Shift published for ${member.fullName}.'
            : 'Shift request sent to ${member.fullName}.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(managerRepositoryProvider);
    final staffList = repo.staff.value;
    final preStaff = widget.preselectedStaff;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add Shift',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                children: [
                  // Staff picker (only when not preselected)
                  if (preStaff == null) ...[
                    const _FieldLabel(label: 'Staff Member'),
                    const SizedBox(height: 6),
                    _StaffDropdown(
                      staff: staffList,
                      selected: _selectedStaff,
                      onChanged: (s) => setState(() => _selectedStaff = s),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const _FieldLabel(label: 'Staff Member'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        preStaff.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Time range
                  const _FieldLabel(label: 'Time'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeTile(
                          label: 'Start',
                          time: _startTime,
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TimeTile(
                          label: 'End',
                          time: _endTime,
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Department
                  const _FieldLabel(label: 'Department'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _departments.map((d) {
                      final selected = _department == d;
                      return GestureDetector(
                        onTap: () => setState(() => _department = d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF1B8A5A)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _capitalize(d),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                          color: Color(0xFFB91C1C), fontSize: 13),
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B8A5A),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Text(
                              'Create & Publish',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.time, required this.onTap});
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = time.hour;
    final m = time.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 2),
            Text(
              '$hour:$m $period',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffDropdown extends StatelessWidget {
  const _StaffDropdown({
    required this.staff,
    required this.selected,
    required this.onChanged,
  });
  final List<StaffMember> staff;
  final StaffMember? selected;
  final void Function(StaffMember?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StaffMember>(
          isExpanded: true,
          hint: const Text('Select staff member',
              style: TextStyle(color: Color(0xFF9CA3AF))),
          value: selected,
          items: staff
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.fullName),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
