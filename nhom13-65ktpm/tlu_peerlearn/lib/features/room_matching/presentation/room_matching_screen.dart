

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/responsive_container.dart';
import '../../auth_profile/data/auth_repository.dart';
import '../../auth_profile/data/registration_repository.dart';
import '../../auth_profile/domain/program_registration.dart';
import '../data/room_matching_repository.dart';
import '../domain/compatibility_match.dart';
import '../domain/room_invitation.dart';
import '../domain/study_room.dart';
import 'study_room_detail_screen.dart';

class RoomMatchingScreen extends ConsumerStatefulWidget {
  const RoomMatchingScreen({super.key});

  @override
  ConsumerState<RoomMatchingScreen> createState() => _RoomMatchingScreenState();
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 36),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchScore extends StatelessWidget {
  final String label;
  final double score;
  final IconData icon;

  const _MatchScore({
    required this.label,
    required this.score,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final safeScore = score.isFinite ? score.clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          SizedBox(
            width: 76,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: safeScore,
              minHeight: 5,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '${(safeScore * 100).round()}%',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomMatchingScreenState extends ConsumerState<RoomMatchingScreen> {
  String? _selectedRegistrationId;
  Future<List<CompatibilityMatch>>? _matchesFuture;
  bool _isCreatingRoom = false;
  bool _isJoiningRoom = false;
  final Set<String> _workingMatchIds = {};
  final Set<String> _respondingInvitationIds = {};

  ProgramRegistration? _selectedRegistration(
    List<ProgramRegistration> registrations,
  ) {
    for (final registration in registrations) {
      if (registration.id == _selectedRegistrationId) return registration;
    }
    return registrations.isEmpty ? null : registrations.first;
  }

  void _loadMatches(ProgramRegistration registration) {
    setState(() {
      _selectedRegistrationId = registration.id;
      _matchesFuture = ref
          .read(roomMatchingRepositoryProvider)
          .getMatches(current: registration);
    });
  }

  Future<void> _refreshMatches(ProgramRegistration registration) async {
    final future = ref
        .read(roomMatchingRepositoryProvider)
        .getMatches(current: registration);
    setState(() {
      _selectedRegistrationId = registration.id;
      _matchesFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the failure state.
    }
  }

  Future<void> _refreshInvitations(String userId) async {
    ref.invalidate(myInvitationsProvider(userId));
    try {
      await ref.read(myInvitationsProvider(userId).future);
    } catch (_) {
      // The provider exposes the error state in the tab.
    }
  }

  Future<void> _refreshRooms(String userId) async {
    ref.invalidate(myRoomsProvider(userId));
    try {
      await ref.read(myRoomsProvider(userId).future);
    } catch (_) {
      // The provider exposes the error state in the tab.
    }
  }

  Future<void> _createRoom(
    String mentorId,
    ProgramRegistration registration,
  ) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo phòng học'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Tên phòng',
                  counterText: '',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập tên phòng'
                    : null,
              ),
              TextField(
                controller: description,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (không bắt buộc)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      name.dispose();
      description.dispose();
      return;
    }
    if (!mounted) {
      name.dispose();
      description.dispose();
      return;
    }
    if (name.text.trim().isEmpty) {
      _showMessage('Vui lòng nhập tên phòng');
      name.dispose();
      description.dispose();
      return;
    }
    setState(() => _isCreatingRoom = true);
    try {
      final room = await ref
          .read(roomMatchingRepositoryProvider)
          .createRoom(
            courseId: registration.courseId,
            mentorId: mentorId,
            name: name.text,
            description: description.text,
          );
      ref.invalidate(myRoomsProvider(mentorId));
      ref.invalidate(studyRoomProvider(room.id));
      if (mounted) _openRoom(room);
    } catch (error) {
      _showMessage('Không thể tạo phòng: $error');
    } finally {
      name.dispose();
      description.dispose();
      if (mounted) setState(() => _isCreatingRoom = false);
    }
  }

  Future<void> _joinRoom(String userId) async {
    final code = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tham gia phòng học'),
        content: TextField(
          controller: code,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Room Code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tham gia'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      code.dispose();
      return;
    }
    if (code.text.trim().isEmpty) {
      code.dispose();
      _showMessage('Nhập Room Code để tham gia phòng');
      return;
    }
    if (!mounted) {
      code.dispose();
      return;
    }
    setState(() => _isJoiningRoom = true);
    try {
      final room = await ref
          .read(roomMatchingRepositoryProvider)
          .joinRoomByCode(roomCode: code.text, userId: userId);
      ref.invalidate(myRoomsProvider(userId));
      ref.invalidate(roomMembersProvider(room.id));
      if (mounted) _openRoom(room);
    } catch (error) {
      _showMessage('Không thể tham gia phòng: $error');
    } finally {
      code.dispose();
      if (mounted) setState(() => _isJoiningRoom = false);
    }
  }

  Future<void> _sendInvitation({
    required String userId,
    required ProgramRegistration current,
    required CompatibilityMatch match,
  }) async {
    try {
      setState(() => _workingMatchIds.add(match.userId));
      final repository = ref.read(roomMatchingRepositoryProvider);
      final rooms = current.role == 'mentor'
          ? await repository.getOpenRoomsForMentor(
              mentorId: userId,
              courseId: current.courseId,
            )
          : await repository.getOpenRoomsForMentor(
              mentorId: match.userId,
              courseId: current.courseId,
            );
      if (rooms.isEmpty) {
        _showMessage(
          current.role == 'mentor'
              ? 'Vui lòng mở phòng học cho học phần này trước khi mời học viên vào phòng.'
              : 'Mentor này chưa mở phòng học nào cho học phần này.',
        );
        return;
      }
      if (!mounted) return;
      final room = await showDialog<StudyRoom>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(
            current.role == 'mentor'
                ? 'Chọn phòng để mời'
                : 'Chọn phòng để xin tham gia',
          ),
          children: rooms
              .map(
                (room) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, room),
                  child: Text(room.name),
                ),
              )
              .toList(),
        ),
      );
      if (room == null) return;
      if (current.role == 'mentor') {
        await repository.sendInvitation(
          roomId: room.id,
          senderId: userId,
          receiverId: match.userId,
        );
      } else {
        await repository.requestToJoin(roomId: room.id, menteeId: userId);
      }
      _showMessage(
        current.role == 'mentor' ? 'Đã gửi lời mời' : 'Đã gửi yêu cầu tham gia',
      );
      ref.invalidate(myInvitationsProvider(userId));
    } catch (error) {
      _showMessage('Không thể gửi lời mời: $error');
    } finally {
      if (mounted) setState(() => _workingMatchIds.remove(match.userId));
    }
  }

  Future<void> _copyRoomCode(String roomCode) async {
    try {
      await Clipboard.setData(ClipboardData(text: roomCode));
      _showMessage('Đã sao chép mã phòng');
    } catch (error) {
      _showMessage('Không thể sao chép mã phòng: $error');
    }
  }

  void _openRoom(StudyRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyRoomDetailScreen(roomId: room.id),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final registrationsAsync = ref.watch(myRegistrationsProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gợi ý kết nối & Phòng học'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: 'Gợi ý'),
              Tab(text: 'Lời mời'),
              Tab(text: 'Phòng học'),
            ],
          ),
          actions: [
            if (profileAsync.value != null)
              IconButton(
                tooltip: 'Tham gia bằng mã phòng',
                onPressed: _isJoiningRoom
                    ? null
                    : () => _joinRoom(profileAsync.value!.id),
                icon: _isJoiningRoom
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.vpn_key),
              ),
          ],
        ),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadError(
            message: 'Không thể tải hồ sơ: $error',
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Vui lòng đăng nhập'));
            }
            return registrationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _LoadError(
                message: 'Không thể tải đăng ký: $error',
                onRetry: () => ref.invalidate(myRegistrationsProvider),
              ),
              data: (registrations) => ResponsiveContainer(
                maxWidth: 960,
                padding: EdgeInsets.zero,
                child: TabBarView(
                  children: [
                    _buildMatches(profile.id, registrations),
                    _buildInvitations(profile.id),
                    _buildRooms(profile.id),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMatches(String userId, List<ProgramRegistration> registrations) {
    if (registrations.isEmpty) {
      return const Center(
        child: Text('Đăng ký học phần và vai trò để xem gợi ý kết nối'),
      );
    }
    final registration = _selectedRegistration(registrations)!;
    _matchesFuture ??= ref
        .read(roomMatchingRepositoryProvider)
        .getMatches(current: registration);
    final hasMentorRole = registrations.any(
      (item) => item.courseId == registration.courseId && item.role == 'mentor',
    );
    final myRooms =
        ref.watch(myRoomsProvider(userId)).value ?? const <StudyRoom>[];
    final alreadyInCourseRoom =
        registration.role == 'mentee' &&
        myRooms.any((r) => r.courseId == registration.courseId);

    return RefreshIndicator(
      onRefresh: () => _refreshMatches(registration),
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: registration.id,
          decoration: const InputDecoration(labelText: 'Học phần'),
          items: registrations.map((item) {
            final label = [
              if ((item.courseCode ?? '').isNotEmpty) item.courseCode!,
              if ((item.courseName ?? '').isNotEmpty) item.courseName!,
            ].join(' - ');
            return DropdownMenuItem(
              value: item.id,
              child: Text(
                label.isEmpty ? item.courseId : label,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            final next = registrations.firstWhere((item) => item.id == id);
            _loadMatches(next);
          },
        ),
        const SizedBox(height: 8),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  registration.role == 'mentor'
                      ? Icons.school_outlined
                      : Icons.person_outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    registration.role == 'mentor'
                        ? 'Vai trò của bạn: Mentor — Gợi ý Mentee phù hợp để mời vào phòng'
                        : alreadyInCourseRoom
                        ? 'Bạn đã tham gia phòng học cho học phần này'
                        : 'Vai trò của bạn: Mentee — Gợi ý Mentor phù hợp để xin vào phòng',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (hasMentorRole)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _isCreatingRoom
                  ? null
                  : () => _createRoom(userId, registration),
              icon: _isCreatingRoom
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isCreatingRoom ? 'Đang tạo...' : 'Tạo phòng'),
            ),
          ),
        FutureBuilder<List<CompatibilityMatch>>(
          future: _matchesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _LoadError(
                message: 'Không thể tải gợi ý: ${snapshot.error}',
                onRetry: () => _refreshMatches(registration),
              );
            }
            final matches = snapshot.data ?? const <CompatibilityMatch>[];
            if (matches.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Chưa có người học phù hợp cho học phần này'),
                ),
              );
            }
            return Column(
              children: matches
                  .map(
                    (match) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  child: Icon(
                                    match.role == 'mentor'
                                        ? Icons.school_outlined
                                        : Icons.person_outline,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        match.fullName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        match.role == 'mentor'
                                            ? 'Mentor'
                                            : 'Mentee',
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${match.percentage}% phù hợp',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _MatchScore(
                              label: 'Thời gian',
                              score: match.timeScore,
                              icon: Icons.schedule,
                            ),
                            _MatchScore(
                              label: 'Học thuật',
                              score: match.academicScore,
                              icon: Icons.school_outlined,
                            ),
                            _MatchScore(
                              label: 'Sức chứa',
                              score: match.capacityScore,
                              icon: Icons.groups_outlined,
                            ),
                            const SizedBox(height: 8),
                            if (alreadyInCourseRoom)
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Chip(
                                  avatar: Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  label: Text('Đã tham gia phòng học'),
                                ),
                              )
                            else
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonalIcon(
                                  onPressed: _workingMatchIds
                                          .contains(match.userId)
                                      ? null
                                      : () => _sendInvitation(
                                          userId: userId,
                                          current: registration,
                                          match: match,
                                        ),
                                  icon: _workingMatchIds
                                          .contains(match.userId)
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send_outlined),
                                  label: Text(
                                    registration.role == 'mentor'
                                        ? 'Mời vào phòng'
                                        : 'Xin tham gia phòng',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
      ),
    );
  }

  Widget _buildInvitations(String userId) {
    final invitationAsync = ref.watch(myInvitationsProvider(userId));
    return invitationAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LoadError(
        message: 'Không thể tải lời mời: $error',
        onRetry: () => _refreshInvitations(userId),
      ),
      data: (invitations) {
        return RefreshIndicator(
          onRefresh: () => _refreshInvitations(userId),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: invitations.isEmpty
                ? const [
                    SizedBox(
                      height: 240,
                      child: Center(child: Text('Chưa có lời mời nào')),
                    ),
                  ]
                : invitations.map((invitation) {
            final isIncoming = invitation.receiverId == userId;
            final pending = invitation.status == 'pending';
            final statusLabel = switch (invitation.status) {
              'pending' => 'Đang chờ',
              'accepted' => 'Đã chấp nhận',
              'rejected' => 'Đã từ chối',
              _ => invitation.status,
            };
            return Card(
              child: ListTile(
                title: Text(invitation.roomName ?? 'Phòng học'),
                subtitle: Text(
                  '${invitation.type == 'invite' ? 'Lời mời' : 'Yêu cầu tham gia'}'
                  ' • ${isIncoming ? 'Đến' : 'Đã gửi'}'
                  ' • $statusLabel',
                ),
                trailing: isIncoming && pending
                    ? Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Từ chối',
                            onPressed: _respondingInvitationIds
                                    .contains(invitation.id)
                                ? null
                                : () => _respond(userId, invitation, false),
                            icon: _respondingInvitationIds
                                    .contains(invitation.id)
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.close),
                          ),
                          IconButton(
                            tooltip: 'Chấp nhận',
                            onPressed: _respondingInvitationIds
                                    .contains(invitation.id)
                                ? null
                                : () => _respond(userId, invitation, true),
                            icon: const Icon(Icons.check),
                          ),
                        ],
                      )
                    : null,
              ),
            );
                }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _respond(
    String userId,
    RoomInvitation invitation,
    bool accept,
  ) async {
    setState(() => _respondingInvitationIds.add(invitation.id));
    try {
      await ref
          .read(roomMatchingRepositoryProvider)
          .respondToInvitation(
            invitationId: invitation.id,
            responderId: userId,
            accept: accept,
          );
      ref.invalidate(myInvitationsProvider(userId));
      ref.invalidate(myRoomsProvider(userId));
      _showMessage(accept ? 'Đã chấp nhận lời mời' : 'Đã từ chối lời mời');
    } catch (error) {
      _showMessage('Không thể xử lý lời mời: $error');
    } finally {
      if (mounted) {
        setState(() => _respondingInvitationIds.remove(invitation.id));
      }
    }
  }

  Widget _buildRooms(String userId) {
    final roomsAsync = ref.watch(myRoomsProvider(userId));
    return roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LoadError(
        message: 'Không thể tải phòng học: $error',
        onRetry: () => _refreshRooms(userId),
      ),
      data: (rooms) {
        return RefreshIndicator(
          onRefresh: () => _refreshRooms(userId),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: rooms.isEmpty
                ? const [
                    SizedBox(
                      height: 240,
                      child: Center(
                        child: Text('Bạn chưa tham gia phòng học nào'),
                      ),
                    ),
                  ]
                : rooms
                .map(
                  (room) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.meeting_room_outlined),
                      title: Text(room.name),
                      subtitle: Text('Mã phòng: ${room.roomCode}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Sao chép Room Code',
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copyRoomCode(room.roomCode),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => _openRoom(room),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
