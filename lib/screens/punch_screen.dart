import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/providers.dart';
import '../models/punch.dart';
import '../widgets/account_menu.dart';
import '../widgets/punch_button.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Reactive wrapper around repo.punches (ValueNotifier → AsyncValue).
final punchesProvider = StreamProvider<List<Punch>>((ref) {
  final repo = ref.watch(punchRepositoryProvider);
  // Convert ValueNotifier to a Stream so Riverpod can watch it.
  final controller = StreamController<List<Punch>>(sync: true);
  void listener() => controller.add(repo.punches.value);
  repo.punches.addListener(listener);
  controller.add(repo.punches.value); // emit current value immediately
  ref.onDispose(() {
    repo.punches.removeListener(listener);
    controller.close();
  });
  return controller.stream;
});

final lastPunchTypeProvider = StreamProvider<String>((ref) {
  final repo = ref.watch(punchRepositoryProvider);
  final controller = StreamController<String>(sync: true);
  void listener() => controller.add(repo.lastPunchType.value);
  repo.lastPunchType.addListener(listener);
  controller.add(repo.lastPunchType.value);
  ref.onDispose(() {
    repo.lastPunchType.removeListener(listener);
    controller.close();
  });
  return controller.stream;
});

final isSyncingProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(punchRepositoryProvider);
  final controller = StreamController<bool>(sync: true);
  void listener() => controller.add(repo.isSyncing.value);
  repo.isSyncing.addListener(listener);
  controller.add(repo.isSyncing.value);
  ref.onDispose(() {
    repo.isSyncing.removeListener(listener);
    controller.close();
  });
  return controller.stream;
});

// ---------------------------------------------------------------------------
// Punch Screen
// ---------------------------------------------------------------------------

class PunchScreen extends ConsumerWidget {
  const PunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastTypeAsync = ref.watch(lastPunchTypeProvider);
    final punchesAsync = ref.watch(punchesProvider);
    final isSyncingAsync = ref.watch(isSyncingProvider);

    final lastType = lastTypeAsync.valueOrNull ?? 'none';
    final isSyncing = isSyncingAsync.valueOrNull ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Timecard',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          _SyncIndicator(isSyncing: isSyncing),
          const AccountMenu(),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current status chip
              _StatusChip(lastType: lastType),
              const SizedBox(height: 32),

              // Primary action button — never blocked, never shows a spinner.
              _PrimaryButton(lastType: lastType),
              const SizedBox(height: 12),

              // Secondary action (Start Break) — only shown when clocked in.
              if (hasSecondaryAction(lastType))
                _SecondaryButton(lastType: lastType),

              const SizedBox(height: 36),

              // Today's punch history from the local cache.
              const _HistoryHeader(),
              const SizedBox(height: 8),
              Expanded(
                child: punchesAsync.when(
                  data: (list) => list.isEmpty
                      ? const _EmptyHistory()
                      : _PunchHistoryList(punches: list),
                  loading: () => const _EmptyHistory(),
                  error: (_, __) => const _EmptyHistory(),
                ),
              ),

              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const _FixRequestSheet(),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 14, color: Color(0xFF9CA3AF)),
                    SizedBox(width: 4),
                    Text(
                      'Report an issue with a punch',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.lastType});
  final String lastType;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (lastType) {
      'in' => ('Clocked in', const Color(0xFF1B8A5A)),
      'unpaid_in' => ('On break', const Color(0xFFD97706)),
      'unpaid_out' => ('Break ended', const Color(0xFF1B8A5A)),
      'out' => ('Clocked out', const Color(0xFF6B7280)),
      _ => ('Not clocked in', const Color(0xFF6B7280)),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            border: Border.all(color: color.withAlpha(80)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Primary action button
// ---------------------------------------------------------------------------

class _PrimaryButton extends ConsumerWidget {
  const _PrimaryButton({required this.lastType});
  final String lastType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = primaryActionLabel(lastType);
    final type = primaryNextPunch(lastType);

    return PunchButton(
      label: label,
      punchType: type,
      onPressed: () {
        // Fire-and-forget — the repo updates SQLite + in-memory state
        // synchronously before the awaited HTTP call starts.
        unawaited(
          ref.read(punchRepositoryProvider).recordPunch(type),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Secondary action button (Start Break)
// ---------------------------------------------------------------------------

class _SecondaryButton extends ConsumerWidget {
  const _SecondaryButton({required this.lastType});
  final String lastType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The secondary action is always "Start Break" when lastType == 'in'.
    return SecondaryPunchButton(
      label: 'Start Break',
      punchType: PunchType.breakStart,
      onPressed: () {
        unawaited(
          ref.read(punchRepositoryProvider).recordPunch(PunchType.breakStart),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Punch history
// ---------------------------------------------------------------------------

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return const Text(
      "Today's punches",
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No punches yet today',
        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      ),
    );
  }
}

class _PunchHistoryList extends StatelessWidget {
  const _PunchHistoryList({required this.punches});
  final List<Punch> punches;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: punches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) => _PunchTile(punch: punches[i]),
    );
  }
}

class _PunchTile extends StatelessWidget {
  const _PunchTile({required this.punch});
  final Punch punch;

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(punch.displayTs);
    final isPending = punch.pendingSync;
    final isIrregular = punch.isIrregular;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isIrregular
              ? const Color(0xFFF59E0B)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          // Punch type icon
          _PunchTypeIcon(type: punch.type),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  punch.type.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                if (isIrregular)
                  const Text(
                    'Flagged — manager notified',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
              ],
            ),
          ),
          // Timestamp
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 13,
              color: isPending
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isPending) ...[
            const SizedBox(width: 6),
            const _PendingDot(),
          ],
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
}

class _PunchTypeIcon extends StatelessWidget {
  const _PunchTypeIcon({required this.type});
  final PunchType type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      PunchType.clockIn => (Icons.login_rounded, const Color(0xFF1B8A5A)),
      PunchType.clockOut => (Icons.logout_rounded, const Color(0xFFB03A2E)),
      PunchType.breakStart => (Icons.pause_circle_outline_rounded, const Color(0xFFD97706)),
      PunchType.breakEnd => (Icons.play_circle_outline_rounded, const Color(0xFF1B8A5A)),
    };
    return Icon(icon, color: color, size: 22);
  }
}

class _PendingDot extends StatefulWidget {
  const _PendingDot();

  @override
  State<_PendingDot> createState() => _PendingDotState();
}

class _PendingDotState extends State<_PendingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Color(0xFF9CA3AF),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sync indicator in the AppBar
// ---------------------------------------------------------------------------

class _SyncIndicator extends StatefulWidget {
  const _SyncIndicator({required this.isSyncing});
  final bool isSyncing;

  @override
  State<_SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<_SyncIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isSyncing) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_SyncIndicator old) {
    super.didUpdateWidget(old);
    if (widget.isSyncing && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isSyncing && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSyncing) {
      return Icon(
        Icons.cloud_done_outlined,
        size: 18,
        color: Colors.grey.shade400,
      );
    }
    return RotationTransition(
      turns: _ctrl,
      child: Icon(
        Icons.sync_rounded,
        size: 18,
        color: Colors.grey.shade500,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fix Request bottom sheet
// ---------------------------------------------------------------------------

class _FixRequestSheet extends ConsumerStatefulWidget {
  const _FixRequestSheet();

  @override
  ConsumerState<_FixRequestSheet> createState() => _FixRequestSheetState();
}

class _FixRequestSheetState extends ConsumerState<_FixRequestSheet> {
  String _punchType = 'in';
  DateTime _proposedDt = DateTime.now();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  static const _punchTypes = ['in', 'out', 'unpaid_in', 'unpaid_out'];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _proposedDt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1B8A5A)),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_proposedDt),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1B8A5A)),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _proposedDt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Please enter a reason.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final token = ref.read(punchRepositoryProvider).token;
    try {
      final resp = await http.post(
        Uri.parse('$kBaseUrl/m/timecard/fix-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'punchType': _punchType,
          'proposedTs': _proposedDt.toIso8601String(),
          'reason': reason,
        }),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (resp.statusCode == 201) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fix request submitted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _error = 'Failed to submit. Try again.');
      }
    } on SocketException {
      if (mounted) setState(() => _error = 'No connection. Try again.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to submit. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const Text(
              'Report Punch Issue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Submit a correction request to your manager.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),

            const _SheetFieldLabel(label: 'Punch Type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _punchTypes.map((t) {
                final selected = _punchType == t;
                return GestureDetector(
                  onTap: () => setState(() => _punchType = t),
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
                      _labelPunchType(t),
                      style: TextStyle(
                        fontSize: 12,
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
            const SizedBox(height: 16),

            const _SheetFieldLabel(label: 'Proposed Time'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 16, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 8),
                    Text(
                      _fmtDt(_proposedDt),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const _SheetFieldLabel(label: 'Reason'),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Explain what happened...',
                hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFF1B8A5A), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFB91C1C), fontSize: 13)),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B8A5A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelPunchType(String t) => switch (t) {
        'in' => 'Clock In',
        'out' => 'Clock Out',
        'unpaid_in' => 'Break Start',
        'unpaid_out' => 'Break End',
        _ => t,
      };

  String _fmtDt(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month]}, $hour:$m $period';
  }
}

class _SheetFieldLabel extends StatelessWidget {
  const _SheetFieldLabel({required this.label});
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
