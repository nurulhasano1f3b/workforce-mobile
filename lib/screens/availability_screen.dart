import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/availability_repository.dart';
import '../data/providers.dart';
import '../models/availability.dart';
import '../widgets/account_menu.dart';

// ---------------------------------------------------------------------------
// Stream provider — mirrors the repository ValueNotifier.
// ---------------------------------------------------------------------------

final _availProvider = StreamProvider<AvailabilityData>((ref) {
  final repo = ref.watch(availabilityRepositoryProvider);
  final ctrl = StreamController<AvailabilityData>(sync: true);
  void listener() => ctrl.add(repo.data.value);
  repo.data.addListener(listener);
  ctrl.add(repo.data.value);
  ref.onDispose(() {
    repo.data.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  // Local edits to the weekly pattern: index = weekday (0=Sun).
  // null means the day is marked unavailable.
  final List<AvailPattern?> _edited = List.filled(7, null);
  bool _initialised = false;

  void _initFromData(AvailabilityData data) {
    if (_initialised) return;
    _initialised = true;
    for (int d = 0; d < 7; d++) {
      final match = data.pattern.where((p) => p.weekday == d);
      _edited[d] = match.isNotEmpty ? match.first : null;
    }
  }

  bool _hasChanges(AvailabilityData original) {
    for (int d = 0; d < 7; d++) {
      final orig =
          original.pattern.where((p) => p.weekday == d).firstOrNull;
      final edit = _edited[d];
      if (orig == null && edit == null) continue;
      if (orig == null || edit == null) return true;
      if (orig.startMin != edit.startMin || orig.endMin != edit.endMin) {
        return true;
      }
    }
    return false;
  }

  Future<void> _save(AvailabilityRepository repo) async {
    final pattern = _edited
        .asMap()
        .entries
        .where((e) => e.value != null)
        .map((e) => e.value!)
        .toList();
    final ok = await repo.updatePattern(pattern);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Availability saved.' : 'Failed to save. Try again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) setState(() => _initialised = false);
  }

  Future<void> _pickTime(
    BuildContext context,
    int weekday,
    bool isStart,
    AvailPattern current,
  ) async {
    final initial = isStart
        ? minutesToTimeOfDay(current.startMin)
        : minutesToTimeOfDay(current.endMin);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final minutes = timeOfDayToMinutes(picked);
    setState(() {
      _edited[weekday] = isStart
          ? current.copyWith(startMin: minutes)
          : current.copyWith(endMin: minutes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final availAsync = ref.watch(_availProvider);
    final repo = ref.read(availabilityRepositoryProvider);
    final avail = availAsync.valueOrNull ?? AvailabilityData.empty;

    _initFromData(avail);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Availability',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_hasChanges(avail))
            ValueListenableBuilder<bool>(
              valueListenable: repo.isSaving,
              builder: (_, saving, __) => TextButton(
                onPressed: saving ? null : () => _save(repo),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF1B8A5A)),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: Color(0xFF1B8A5A),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          const AccountMenu(),
          const SizedBox(width: 4),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: repo.isLoading,
        builder: (_, loading, __) {
          return RefreshIndicator(
            color: const Color(0xFF1B8A5A),
            onRefresh: repo.refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (loading)
                  const LinearProgressIndicator(
                    color: Color(0xFF1B8A5A),
                    backgroundColor: Color(0xFFD1FAE5),
                  ),
                if (loading) const SizedBox(height: 12),
                _SectionHeader(label: 'Weekly Schedule'),
                const SizedBox(height: 10),
                _WeeklySchedule(
                  edited: _edited,
                  onToggle: (day, enabled) {
                    setState(() {
                      _edited[day] = enabled
                          ? AvailPattern(
                              weekday: day,
                              startMin: 540,  // 9:00 AM default
                              endMin: 1020,   // 5:00 PM default
                            )
                          : null;
                    });
                  },
                  onPickTime: (day, isStart) {
                    final p = _edited[day];
                    if (p != null) _pickTime(context, day, isStart, p);
                  },
                ),
                const SizedBox(height: 28),
                _SectionHeader(label: 'Exceptions'),
                const SizedBox(height: 10),
                if (avail.exceptions.isEmpty)
                  _EmptyHint(text: 'No upcoming exceptions.'),
                ...avail.exceptions.map((ex) => _ExceptionTile(ex: ex)),
                const SizedBox(height: 80), // FAB clearance
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddException(context, repo),
        backgroundColor: const Color(0xFF1B8A5A),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Exception',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _showAddException(
      BuildContext context, AvailabilityRepository repo) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddExceptionSheet(repo: repo),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly schedule widget
// ---------------------------------------------------------------------------

class _WeeklySchedule extends StatelessWidget {
  const _WeeklySchedule({
    required this.edited,
    required this.onToggle,
    required this.onPickTime,
  });

  final List<AvailPattern?> edited;
  final void Function(int day, bool enabled) onToggle;
  final void Function(int day, bool isStart) onPickTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(7, (day) {
        final pattern = edited[day];
        final available = pattern != null;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: available
                  ? const Color(0xFF1B8A5A).withAlpha(80)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              // Day header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        kWeekdayNames[day],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: available
                              ? const Color(0xFF111827)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: available,
                        onChanged: (v) => onToggle(day, v),
                        activeColor: const Color(0xFF1B8A5A),
                      ),
                    ),
                  ],
                ),
              ),
              // Time range row (only when available)
              if (available) ...[
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 16, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 8),
                      _TimeChip(
                        label: formatMinutes(pattern.startMin),
                        onTap: () => onPickTime(day, true),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('–',
                            style: TextStyle(color: Color(0xFF6B7280))),
                      ),
                      _TimeChip(
                        label: formatMinutes(pattern.endMin),
                        onTap: () => onPickTime(day, false),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1B8A5A).withAlpha(18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B8A5A),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exception tile
// ---------------------------------------------------------------------------

class _ExceptionTile extends StatelessWidget {
  const _ExceptionTile({required this.ex});
  final AvailException ex;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(ex.day);
    final dateLabel = date != null
        ? '${_monthName(date.month)} ${date.day}'
        : ex.day;

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
          const Icon(Icons.event_outlined, size: 18, color: Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                if (ex.available &&
                    ex.startMin != null &&
                    ex.endMin != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${formatMinutes(ex.startMin!)} – ${formatMinutes(ex.endMin!)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ex.available
                  ? const Color(0xFF1B8A5A).withAlpha(20)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ex.available ? 'Available' : 'Unavailable',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ex.available
                    ? const Color(0xFF1B8A5A)
                    : const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][month];
}

// ---------------------------------------------------------------------------
// Add exception bottom sheet
// ---------------------------------------------------------------------------

class _AddExceptionSheet extends ConsumerStatefulWidget {
  const _AddExceptionSheet({required this.repo});
  final AvailabilityRepository repo;

  @override
  ConsumerState<_AddExceptionSheet> createState() =>
      _AddExceptionSheetState();
}

class _AddExceptionSheetState extends ConsumerState<_AddExceptionSheet> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _available = false;
  int _startMin = 540;
  int _endMin = 1020;
  bool _saving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1B8A5A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart
        ? minutesToTimeOfDay(_startMin)
        : minutesToTimeOfDay(_endMin);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startMin = timeOfDayToMinutes(picked);
      } else {
        _endMin = timeOfDayToMinutes(picked);
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final ex = AvailException(
      day:
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
      available: _available,
      startMin: _available ? _startMin : null,
      endMin: _available ? _endMin : null,
    );
    final ok = await widget.repo.addException(ex);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Exception saved.' : 'Failed to save. Try again.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add Exception',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 20),

          // Date picker row
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: Color(0xFF6B7280)),
                  const SizedBox(width: 12),
                  Text(
                    '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF111827)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Available toggle
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Text('Available on this day',
                    style:
                        TextStyle(fontSize: 15, color: Color(0xFF374151))),
                const Spacer(),
                Switch(
                  value: _available,
                  onChanged: (v) => setState(() => _available = v),
                  activeColor: const Color(0xFF1B8A5A),
                ),
              ],
            ),
          ),

          // Time range (only when available)
          if (_available) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 8),
                _TimeChip(
                  label: formatMinutes(_startMin),
                  onTap: () => _pickTime(true),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child:
                      Text('–', style: TextStyle(color: Color(0xFF6B7280))),
                ),
                _TimeChip(
                  label: formatMinutes(_endMin),
                  onTap: () => _pickTime(false),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B8A5A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor:
                    const Color(0xFF1B8A5A).withAlpha(120),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Save Exception',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
      ),
    );
  }
}
