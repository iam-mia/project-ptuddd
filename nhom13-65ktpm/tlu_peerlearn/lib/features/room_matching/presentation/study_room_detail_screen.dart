import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_profile/data/auth_repository.dart';
import '../../documents/screens/room_documents_tab.dart';
import '../../practice_stats/screens/room_practice_tab.dart';
import '../../sessions/screens/room_sessions_tab.dart';
import '../data/room_matching_repository.dart';
import '../domain/room_member.dart';
import '../domain/study_room.dart';

class StudyRoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;

  const StudyRoomDetailScreen({super.key, required this.roomId});

  @override
  ConsumerState<StudyRoomDetailScreen> createState() =>
      _StudyRoomDetailScreenState();
}

class _StudyRoomDetailScreenState extends ConsumerState<StudyRoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(studyRoomProvider(widget.roomId));
    final profileAsync = ref.watch(currentProfileProvider);
    final userId = profileAsync.value?.id;
    return roomAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Phòng học')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Phòng học')),
        body: Center(child: Text('Không thể tải phòng học: $error')),
      ),
      data: (room) => _buildRoomTabs(room, userId),
    );
  }

  Widget _buildRoomTabs(StudyRoom room, String? userId) {
    final isMentor = room.mentorId == userId;
    return Scaffold(
      appBar: AppBar(
        title: Text(room.name),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Tổng quan / Thành viên'),
            Tab(text: 'Tài liệu'),
            Tab(text: 'Ôn tập'),
            Tab(text: 'Buổi học'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RoomOverview(room: room, currentUserId: userId),
          RoomDocumentsTab(
            roomId: room.id,
            currentUserId: userId,
            isMentor: isMentor,
          ),
          RoomPracticeTab(
            roomId: room.id,
            currentUserId: userId,
            isMentor: isMentor,
          ),
          RoomSessionsTab(
            roomId: room.id,
            currentUserId: userId,
            isMentor: isMentor,
          ),
        ],
      ),
    );
  }
}

class _RoomOverview extends ConsumerWidget {
  final StudyRoom room;
  final String? currentUserId;

  const _RoomOverview({required this.room, required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(roomMembersProvider(room.id));
    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Lỗi tải thành viên: $error')),
      data: (members) {
        final mentor = members.where((member) => member.role == 'mentor');
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(roomMembersProvider(room.id)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if ((room.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(room.description!),
                      ],
                      const SizedBox(height: 8),
                      SelectableText('Mã phòng: ${room.roomCode}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Thành viên (${members.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (members.isEmpty)
                const Card(child: ListTile(title: Text('Chưa có thành viên'))),
              ...members.map(
                (member) => _MemberTile(
                  member: member,
                  canManage:
                      currentUserId == room.mentorId &&
                      member.userId != room.mentorId,
                  onRemove: () => _removeMember(context, ref, member),
                ),
              ),
              if (mentor.isEmpty)
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Thông tin Mentor chưa sẵn sàng'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    RoomMember member,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thành viên?'),
        content: Text(
          'Bạn muốn xóa ${member.fullName ?? 'thành viên này'} khỏi phòng?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(roomMatchingRepositoryProvider)
          .removeMember(roomId: room.id, userId: member.userId);
      ref.invalidate(roomMembersProvider(room.id));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa thành viên: $error')),
        );
      }
    }
  }
}

class _MemberTile extends StatelessWidget {
  final RoomMember member;
  final bool canManage;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.member,
    required this.canManage,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            member.role == 'mentor' ? Icons.school_outlined : Icons.person,
          ),
        ),
        title: Text(member.fullName ?? member.userId),
        subtitle: Text(
          member.role == 'mentor'
              ? 'Mentor'
              : 'Mentee'
                    '${member.studentId == null ? '' : ' • ${member.studentId}'}',
        ),
        trailing: canManage
            ? IconButton(
                tooltip: 'Xóa thành viên',
                onPressed: onRemove,
                icon: const Icon(Icons.person_remove_outlined),
              )
            : null,
      ),
    );
  }
}
