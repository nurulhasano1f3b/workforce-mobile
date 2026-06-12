import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../models/manager_models.dart';
import '../models/message.dart';
import '../widgets/account_menu.dart';
import 'thread_screen.dart';

final _threadsListProvider = StreamProvider<List<Thread>>((ref) {
  final repo = ref.watch(messagesRepositoryProvider);
  final ctrl = StreamController<List<Thread>>(sync: true);
  void listener() => ctrl.add(repo.threads.value);
  repo.threads.addListener(listener);
  ctrl.add(repo.threads.value);
  ref.onDispose(() {
    repo.threads.removeListener(listener);
    ctrl.close();
  });
  return ctrl.stream;
});

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  void _openCompose() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ComposeThreadSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(_threadsListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: const [AccountMenu(), SizedBox(width: 4)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCompose,
        backgroundColor: const Color(0xFF1B8A5A),
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit_outlined),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF1B8A5A),
          onRefresh: () => ref.read(messagesRepositoryProvider).refresh(),
          child: threadsAsync.when(
            data: (threads) => threads.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    itemCount: threads.length,
                    itemBuilder: (_, i) => _ThreadTile(thread: threads[i]),
                  ),
            loading: () => const _EmptyState(),
            error: (_, __) => const _EmptyState(),
          ),
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread});
  final Thread thread;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ThreadScreen(thread: thread),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1B8A5A).withAlpha(22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
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
                    thread.subject.isNotEmpty
                        ? thread.subject
                        : 'No subject',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (thread.lastMessage != null &&
                      thread.lastMessage!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      thread.lastMessage!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9CA3AF)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _ComposeThreadSheet extends ConsumerStatefulWidget {
  const _ComposeThreadSheet();

  @override
  ConsumerState<_ComposeThreadSheet> createState() =>
      _ComposeThreadSheetState();
}

class _ComposeThreadSheetState extends ConsumerState<_ComposeThreadSheet> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final List<StaffMember> _selectedParticipants = [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Message body is required.');
      return;
    }
    if (_selectedParticipants.isEmpty) {
      setState(() => _error = 'Select at least one recipient.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final threadId = await ref.read(messagesRepositoryProvider).createThread(
          participantIds: _selectedParticipants.map((s) => s.id).toList(),
          body: body,
          subject: _subjectCtrl.text.trim().isEmpty
              ? null
              : _subjectCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (threadId == null) {
      setState(() => _error = 'Failed to send. Try again.');
      return;
    }
    Navigator.pop(context);
  }

  void _toggleParticipant(StaffMember member) {
    setState(() {
      final idx = _selectedParticipants.indexWhere((s) => s.id == member.id);
      if (idx >= 0) {
        _selectedParticipants.removeAt(idx);
      } else {
        _selectedParticipants.add(member);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final staffList = ref.read(managerRepositoryProvider).staff.value;

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
                  'New Message',
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
                  const _FieldLabel(label: 'Subject (optional)'),
                  const SizedBox(height: 6),
                  _inputField(
                    controller: _subjectCtrl,
                    hint: 'Subject',
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),

                  const _FieldLabel(label: 'Recipients'),
                  const SizedBox(height: 6),
                  if (staffList.isEmpty)
                    const Text(
                      'No staff available.',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF9CA3AF)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: staffList.map((s) {
                        final selected = _selectedParticipants
                            .any((p) => p.id == s.id);
                        return GestureDetector(
                          onTap: () => _toggleParticipant(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF1B8A5A)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              s.fullName,
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

                  const _FieldLabel(label: 'Message'),
                  const SizedBox(height: 6),
                  _inputField(
                    controller: _bodyCtrl,
                    hint: 'Type your message...',
                    maxLines: 4,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(
                            color: Color(0xFFB91C1C), fontSize: 13)),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _send,
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
                          : const Text('Send',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
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
            Icon(Icons.forum_outlined,
                size: 48, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text(
              'No messages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start a conversation with your team.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
