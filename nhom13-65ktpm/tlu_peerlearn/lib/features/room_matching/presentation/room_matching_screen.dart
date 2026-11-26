import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  ConsumerState<RoomMatchingScreen> createState() =>
      _RoomMatchingScreenState();
}

class _RoomMatchingScreenState extends ConsumerState<RoomMatchingScreen> {
  String? _selectedRegistrationId;
  Future<List<CompatibilityMatch>>? _matchesFuture;
  bool _isCreatingRoom = false;
  bool _isJoiningRoom = false;

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

  Future<void> _createRoom(
    String mentorId,
    ProgramRegistration registration,
  ) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo phòng học'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên phòng'),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
    if (name.text.trim().isEmpty) {
      _showMessage('Vui lòng nhập tên phòng');
      name.dispose();
      description.dispose();
      return;
    }
    setState(() => _isCreatingRoom = true);
    try {
      final room = await ref.read(roomMatchingRepositoryProvider).createRoom(
            courseId: registration.courseId,
            mentorId: mentorId,
            name: name.text,
            description: description.text,
          );
      ref.invalidate(myRoomsProvider(mentorId));
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
    if (confirmed != true || code.text.trim().isEmpty) {
      code.dispose();
      return;
    }
    setState(() => _isJoiningRoom = true);
    try {
      final room = await ref
          .read(roomMatchingRepositoryProvider)
          .joinRoomByCode(roomCode: code.text, userId: userId);
      ref.invalidate(myRoomsProvider(userId));
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
        _showMessage('Chưa có phòng học đang mở cho học phần này');
        return;
      }
      if (!mounted) return;
      final room = await showDialog<StudyRoom>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(current.role == 'mentor' ? 'Chọn phòng để mời' : 'Chọn phòng để xin tham gia'),
          children: rooms
              .map((room) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, room),
                    child: Text(room.name),
                  ))
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
      _showMessage(current.role == 'mentor' ? 'Đã gửi lời mời' : 'Đã gửi yêu cầu tham gia');
      ref.invalidate(myInvitationsProvider(userId));
    } catch (error) {
      _showMessage('Không thể gửi lời mời: $error');
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
          error: (error, _) => Center(child: Text('Lỗi hồ sơ: $error')),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Vui lòng đăng nhập'));
            }
            return registrationsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Lỗi đăng ký: $error')),
              data: (registrations) => TabBarView(
                children: [
                  _buildMatches(profile.id, registrations),
                  _buildInvitations(profile.id),
                  _buildRooms(profile.id),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMatches(
    String userId,
    List<ProgramRegistration> registrations,
  ) {
    if (registrations.isEmpty) {
      return const Center(
        child: Text('Đăng ký học phần và vai trò để xem gợi ý kết nối'),
      );
    }
    final registration = _selectedRegistration(registrations)!;
    _matchesFuture ??= ref
        .read(roomMatchingRepositoryProvider)
        .getMatches(current: registration);
    final hasMentorRole = registrations.any((item) =>
        item.courseId == registration.courseId && item.role == 'mentor');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: registration.id,
          decoration: const InputDecoration(labelText: 'Học phần'),
          items: registrations
              .map((item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.courseCode ?? item.courseName ?? item.courseId),
                  ))
              .toList(),
          onChanged: (id) {
            final next = registrations.firstWhere((item) => item.id == id);
            _loadMatches(next);
          },
        ),
        const SizedBox(height: 8),
        if (hasMentorRole)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _isCreatingRoom
                  ? null
                  : () => _createRoom(userId, registration),
              icon: const Icon(Icons.add),
              label: const Text('Tạo phòng'),
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
              return Text('Lỗi tải gợi ý: ${snapshot.error}');
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
                  .map((match) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text('${match.percentage}%'),
                          ),
                          title: Text(match.fullName),
                          subtitle: Text(
                            '${match.role == 'mentor' ? 'Mentor' : 'Mentee'}'
                            ' • Khung giờ trùng: ${(match.timeScore * 100).round()}%',
                          ),
                          trailing: IconButton(
                            tooltip: registration.role == 'mentor'
                                ? 'Mời vào phòng'
                                : 'Xin tham gia phòng',
                            icon: const Icon(Icons.send_outlined),
                            onPressed: () => _sendInvitation(
                              userId: userId,
                              current: registration,
                              match: match,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInvitations(String userId) {
    final invitationAsync = ref.watch(myInvitationsProvider(userId));
    return invitationAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Lỗi tải lời mời: $error')),
      data: (invitations) {
        if (invitations.isEmpty) {
          return const Center(child: Text('Chưa có lời mời nào'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: invitations.map((invitation) {
            final isIncoming = invitation.receiverId == userId;
            final pending = invitation.status == 'pending';
            return Card(
              child: ListTile(
                title: Text(invitation.roomName ?? 'Phòng học'),
                subtitle: Text(
                  '${invitation.type == 'invite' ? 'Lời mời' : 'Yêu cầu tham gia'}'
                  ' • ${isIncoming ? 'Đến' : 'Đã gửi'}'
                  ' • ${invitation.status}',
                ),
                trailing: isIncoming && pending
                    ? Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Từ chối',
                            onPressed: () => _respond(userId, invitation, false),
                            icon: const Icon(Icons.close),
                          ),
                          IconButton(
                            tooltip: 'Chấp nhận',
                            onPressed: () => _respond(userId, invitation, true),
                            icon: const Icon(Icons.check),
                          ),
                        ],
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _respond(
    String userId,
    RoomInvitation invitation,
    bool accept,
  ) async {
    try {
      await ref.read(roomMatchingRepositoryProvider).respondToInvitation(
            invitationId: invitation.id,
            accept: accept,
          );
      ref.invalidate(myInvitationsProvider(userId));
      ref.invalidate(myRoomsProvider(userId));
      _showMessage(accept ? 'Đã chấp nhận lời mời' : 'Đã từ chối lời mời');
    } catch (error) {
      _showMessage('Không thể xử lý lời mời: $error');
    }
  }

  Widget _buildRooms(String userId) {
    final roomsAsync = ref.watch(myRoomsProvider(userId));
    return roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Lỗi tải phòng học: $error')),
      data: (rooms) {
        if (rooms.isEmpty) {
          return const Center(child: Text('Bạn chưa tham gia phòng học nào'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myRoomsProvider(userId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: rooms
                .map((room) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.meeting_room_outlined),
                        title: Text(room.name),
                        subtitle: Text('Mã phòng: ${room.roomCode}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openRoom(room),
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}
