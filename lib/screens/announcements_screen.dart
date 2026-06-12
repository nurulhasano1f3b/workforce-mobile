import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../models/announcement.dart';

final _announcementsListProvider = StreamProvider<List<Announcement>>((ref) {
  final repo = ref.watch(announcementsRepositoryProvider);
  final ctrl = StreamController<List<Announcement>>(sync: true);
  void listener() => ctrl.add(repo.announcements.value);
  repo.announcements.addListener(listener);
  ctrl.add(repo.announcements.value);
  ref.onDispose(() {
    repo.announcements.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

final _canPostAnnouncementProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(announcementsRepositoryProvider);
  final ctrl = StreamController<bool>(sync: true);
  void listener() => ctrl.add(repo.canPost.value);
  repo.canPost.addListener(listener);
  ctrl.add(repo.canPost.value);
  ref.onDispose(() {
    repo.canPost.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(_announcementsListProvider);
    final canPost = ref.watch(_canPostAnnouncementProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Announcements',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => _openPostSheet(context, ref),
              backgroundColor: const Color(0xFF1B8A5A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Post',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF1B8A5A),
          onRefresh: () =>
              ref.read(announcementsRepositoryProvider).refresh(),
          child: announcementsAsync.when(
            data: (announcements) => announcements.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    itemCount: announcements.length,
                    itemBuilder: (_, i) =>
                        _AnnouncementCard(announcement: announcements[i]),
                  ),
            loading: () => const _EmptyState(),
            error: (_, __) => const _EmptyState(),
          ),
        ),
      ),
    );
  }

  void _openPostSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PostAnnouncementSheet(),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});
  final Announcement announcement;

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
            color: Colors.black.withAlpha(6),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B8A5A).withAlpha(18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.campaign_outlined,
                    size: 16, color: Color(0xFF1B8A5A)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (announcement.author != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        announcement.author!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                _relativeTime(announcement.createdAt),
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          if (announcement.body != null &&
              announcement.body!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              announcement.body!,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                  height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  String _relativeTime(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month]}';
    } catch (_) {
      return '';
    }
  }
}

class _PostAnnouncementSheet extends ConsumerStatefulWidget {
  const _PostAnnouncementSheet();

  @override
  ConsumerState<_PostAnnouncementSheet> createState() =>
      _PostAnnouncementSheetState();
}

class _PostAnnouncementSheetState
    extends ConsumerState<_PostAnnouncementSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await ref.read(announcementsRepositoryProvider).postAnnouncement(
          title,
          body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      setState(() => _error = 'Failed to post. Try again.');
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Announcement posted.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              'Post Announcement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),
            _inputField(
              controller: _titleCtrl,
              hint: 'Title',
              maxLines: 1,
            ),
            const SizedBox(height: 10),
            _inputField(
              controller: _bodyCtrl,
              hint: 'Body (optional)',
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFB91C1C), fontSize: 13)),
            ],
            const SizedBox(height: 16),
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
                    : const Text('Post Announcement',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF1B8A5A), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
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
            Icon(Icons.campaign_outlined,
                size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text(
              'No announcements',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Announcements from your store will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
