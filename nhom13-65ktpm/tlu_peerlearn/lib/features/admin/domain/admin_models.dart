class AdminOverviewStats {
  final int totalMentors;
  final int totalMentees;
  final int totalRooms;
  final int totalSessions;
  final int totalGeneratedSets;
  final int totalQuizAttempts;

  const AdminOverviewStats({
    this.totalMentors = 0,
    this.totalMentees = 0,
    this.totalRooms = 0,
    this.totalSessions = 0,
    this.totalGeneratedSets = 0,
    this.totalQuizAttempts = 0,
  });
}

class AdminRoomSummary {
  final String id;
  final String name;
  final String roomCode;
  final String courseName;
  final String mentorName;
  final bool isOpen;

  const AdminRoomSummary({
    required this.id,
    required this.name,
    required this.roomCode,
    required this.courseName,
    required this.mentorName,
    this.isOpen = true,
  });

  factory AdminRoomSummary.fromJson(Map<String, dynamic> json) {
    final course = json['courses'] as Map<String, dynamic>?;
    final mentor = json['profiles'] as Map<String, dynamic>?;
    return AdminRoomSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      roomCode: json['room_code'] as String? ?? '',
      courseName: course?['name'] as String? ?? 'Chưa rõ học phần',
      mentorName: mentor?['full_name'] as String? ?? 'Chưa rõ Mentor',
      isOpen: json['is_open'] as bool? ?? true,
    );
  }
}
