import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../models/payslip.dart';
import '../widgets/account_menu.dart';

final _payslipsListProvider = StreamProvider<List<Payslip>>((ref) {
  final repo = ref.watch(payslipsRepositoryProvider);
  final ctrl = StreamController<List<Payslip>>(sync: true);
  void listener() => ctrl.add(repo.payslips.value);
  repo.payslips.addListener(listener);
  ctrl.add(repo.payslips.value);
  ref.onDispose(() {
    repo.payslips.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

class PayslipsScreen extends ConsumerWidget {
  const PayslipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payslipsAsync = ref.watch(_payslipsListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Payslips',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: const [AccountMenu(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF1B8A5A),
          onRefresh: () => ref.read(payslipsRepositoryProvider).refresh(),
          child: payslipsAsync.when(
            data: (payslips) => payslips.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    itemCount: payslips.length,
                    itemBuilder: (_, i) => _PayslipCard(payslip: payslips[i]),
                  ),
            loading: () => const _EmptyState(),
            error: (_, __) => const _EmptyState(),
          ),
        ),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({required this.payslip});
  final Payslip payslip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _periodLabel(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Gross: ${payslip.formattedGross}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  payslip.formattedNet,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B8A5A),
                  ),
                ),
                const Text(
                  'Net Pay',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  String _periodLabel() {
    try {
      final start = DateTime.parse(payslip.periodStart);
      final end = DateTime.parse(payslip.periodEnd);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      if (start.year == end.year && start.month == end.month) {
        return '${start.day}–${end.day} ${months[end.month]} ${end.year}';
      }
      return '${start.day} ${months[start.month]} – ${end.day} ${months[end.month]} ${end.year}';
    } catch (_) {
      return '${payslip.periodStart} – ${payslip.periodEnd}';
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayslipDetailSheet(payslip: payslip),
    );
  }
}

class _PayslipDetailSheet extends StatelessWidget {
  const _PayslipDetailSheet({required this.payslip});
  final Payslip payslip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
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
          Text(
            _periodLabel(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Payslip breakdown',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          _DetailRow(label: 'Gross Pay', value: payslip.formattedGross),
          const Divider(height: 24, color: Color(0xFFE5E7EB)),
          _DetailRow(
            label: 'Net Pay',
            value: payslip.formattedNet,
            highlight: true,
          ),
          if (payslip.documentUrl != null &&
              payslip.documentUrl!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.picture_as_pdf_outlined,
                    size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(
                  'Document available',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _periodLabel() {
    try {
      final start = DateTime.parse(payslip.periodStart);
      final end = DateTime.parse(payslip.periodEnd);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      if (start.year == end.year && start.month == end.month) {
        return '${start.day}–${end.day} ${months[end.month]} ${end.year}';
      }
      return '${start.day} ${months[start.month]} – ${end.day} ${months[end.month]} ${end.year}';
    } catch (_) {
      return '${payslip.periodStart} – ${payslip.periodEnd}';
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: highlight
                ? const Color(0xFF111827)
                : const Color(0xFF6B7280),
            fontWeight:
                highlight ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 18 : 14,
            fontWeight: FontWeight.w700,
            color: highlight
                ? const Color(0xFF1B8A5A)
                : const Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

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
            Icon(Icons.receipt_long_outlined,
                size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text(
              'No payslips yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Payslips will appear here once published.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
