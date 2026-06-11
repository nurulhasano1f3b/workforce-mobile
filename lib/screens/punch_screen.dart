import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
