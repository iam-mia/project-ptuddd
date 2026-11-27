import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/responsive_container.dart';
import '../../ai_generator/models/flashcard_item.dart';
import '../../ai_generator/models/generated_set.dart';
import '../../ai_generator/models/quiz_question_item.dart';
import '../../ai_generator/screens/ai_draft_review_screen.dart';
import '../../ai_generator/screens/room_learning_content_screen.dart';
import '../../ai_generator/services/ai_generator_service.dart';
import '../models/quiz_attempt.dart';
import '../services/practice_service.dart';
import 'flashcard_study_screen.dart';
import 'quiz_analytics_screen.dart';
import 'quiz_taking_screen.dart';

class RoomPracticeTab extends ConsumerStatefulWidget {
  final String roomId;
  final String? currentUserId;
  final bool isMentor;

  const RoomPracticeTab({
    super.key,
    required this.roomId,
    this.currentUserId,
    this.isMentor = false,
  });

  @override
  ConsumerState<RoomPracticeTab> createState() => _RoomPracticeTabState();
}

class _RoomPracticeTabState extends ConsumerState<RoomPracticeTab> {
  PersonalPracticeSummary? _personalSummary;
  bool _isLoadingSummary = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isMentor) {
      _loadSummary();
    }
  }

  void _invalidateSets() {
    ref.invalidate(roomGeneratedSetsProvider(widget.roomId));
    ref.invalidate(roomPublishedSetsProvider(widget.roomId));
  }

  Future<void> _loadSummary() async {
    if (widget.isMentor) return;
    final uid = widget.currentUserId;
    if (uid == null) return;

    setState(() => _isLoadingSummary = true);
    final service = ref.read(practiceServiceProvider);
    final summary = await service.fetchPersonalSummary(uid);
    if (mounted) {
      setState(() {
        _personalSummary = summary;
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _openQuiz(GeneratedSet set) async {
    final service = ref.read(practiceServiceProvider);
    final quizData = await service.fetchQuizBySetId(set.id);
    final quizId = quizData != null ? quizData['id'] as String : set.id;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizTakingScreen(
          generatedSet: set,
          quizId: quizId,
          userId: widget.currentUserId ?? 'current_user',
        ),
      ),
    );
    _loadSummary();
  }

  Future<void> _openAnalytics(GeneratedSet set) async {
    final service = ref.read(practiceServiceProvider);
    final quizData = await service.fetchQuizBySetId(set.id);
    final quizId = quizData != null ? quizData['id'] as String : set.id;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizAnalyticsScreen(generatedSet: set, quizId: quizId),
      ),
    );
  }

  Future<void> _openFlashcards(GeneratedSet set) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardStudyScreen(
          generatedSet: set,
          userId: widget.currentUserId ?? 'current_user',
        ),
      ),
    );
    _loadSummary();
  }

  Future<void> _openDraftReview(GeneratedSet set) async {
    final practiceService = ref.read(practiceServiceProvider);
    final aiService = ref.read(aiGeneratorServiceProvider);

    List<FlashcardItem>? flashcards;
    List<QuizQuestionItem>? questions;

    if (set.isFlashcard) {
      final items = await practiceService.fetchFlashcardsWithProgress(
        setId: set.id,
        userId: widget.currentUserId ?? 'current_user',
      );
      flashcards = items.map((e) => e.flashcard).toList();
    } else {
      final quizData = await practiceService.fetchQuizBySetId(set.id);
      if (quizData != null) {
        questions = await practiceService.fetchQuizQuestions(
          quizData['id'] as String,
        );
      }
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiDraftReviewScreen(
          generatedSet: set,
          flashcards: flashcards,
          quizQuestions: questions,
          onPublish: () async {
            await aiService.publishSet(set.id);
            _invalidateSets();
          },
        ),
      ),
    );
    _invalidateSets();
  }

  Future<void> _editSetMetadata(GeneratedSet set) async {
    final titleCtrl = TextEditingController(text: set.title);
    final topicCtrl = TextEditingController(text: set.topic ?? '');
    String difficulty = set.difficulty;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Sửa thông tin bài ôn tập'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: topicCtrl,
                decoration: const InputDecoration(
                  labelText: 'Chủ đề (tuỳ chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: ['easy', 'medium', 'hard'].contains(difficulty)
                    ? difficulty
                    : 'medium',
                decoration: const InputDecoration(
                  labelText: 'Độ khó',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('Dễ (Easy)')),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text('Trung bình (Medium)'),
                  ),
                  DropdownMenuItem(value: 'hard', child: Text('Khó (Hard)')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => difficulty = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && titleCtrl.text.trim().isNotEmpty) {
      await ref.read(aiGeneratorServiceProvider).updateSetMetadata(
            set.id,
            title: titleCtrl.text.trim(),
            difficulty: difficulty,
            topic: topicCtrl.text.trim().isEmpty ? null : topicCtrl.text.trim(),
          );
      _invalidateSets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật bài ôn tập.')),
        );
      }
    }
  }

  Future<void> _deleteSet(GeneratedSet set) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá bài ôn tập'),
        content: Text('Bạn có chắc muốn xoá "${set.title}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(aiGeneratorServiceProvider).deleteSet(set.id);
      _invalidateSets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xoá bài ôn tập.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final setsAsync = widget.isMentor
        ? ref.watch(roomGeneratedSetsProvider(widget.roomId))
        : ref.watch(roomPublishedSetsProvider(widget.roomId));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _invalidateSets();
          if (!widget.isMentor) {
            await _loadSummary();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ResponsiveContainer(
            maxWidth: 860,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Personal practice summary card (PRA-04) — only for mentees/learners
                if (!widget.isMentor &&
                    _personalSummary != null &&
                    !_isLoadingSummary)
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.workspace_premium_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tiến độ tự học cá nhân (PRA-04)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _SummaryItem(
                                label: 'Quiz đã làm',
                                value: '${_personalSummary!.totalQuizzesTaken}',
                              ),
                              _SummaryItem(
                                label: 'Điểm TB Quiz',
                                value: '${_personalSummary!.averageScore}',
                              ),
                              _SummaryItem(
                                label: 'Flashcard thuộc',
                                value:
                                    '${_personalSummary!.rememberedFlashcards}/${_personalSummary!.totalFlashcardsStudied}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                Text(
                  widget.isMentor
                      ? 'Quản lý bài ôn tập (Mentor)'
                      : 'Bài ôn tập đã phát hành trong phòng',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                setsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) =>
                      Center(child: Text('Lỗi tải bài ôn tập: $err')),
                  data: (sets) {
                    if (sets.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.isMentor
                                    ? 'Chưa có bài ôn tập nào trong phòng.'
                                    : 'Chưa có bài ôn tập nào được phát hành.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isMentor
                                    ? 'Hãy tạo bản nháp bằng AI từ tab Tài liệu.'
                                    : 'Mentor sẽ tạo và duyệt bài Flashcard/Quiz từ kho tài liệu.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (widget.isMentor) {
                      final draftSets =
                          sets.where((s) => s.isDraft).toList();
                      final publishedSets =
                          sets.where((s) => s.isPublished).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _SummaryItem(
                                    label: 'Bản nháp',
                                    value: '${draftSets.length}',
                                  ),
                                  _SummaryItem(
                                    label: 'Đã phát hành',
                                    value: '${publishedSets.length}',
                                  ),
                                  _SummaryItem(
                                    label: 'Tổng bộ đề',
                                    value: '${sets.length}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (draftSets.isNotEmpty) ...[
                            Text(
                              'Bản nháp (${draftSets.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...draftSets.map(
                              (s) => _buildMentorSetCard(s),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (publishedSets.isNotEmpty) ...[
                            const Text(
                              'Đã phát hành',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...publishedSets.map(
                              (s) => _buildMentorSetCard(s),
                            ),
                          ],
                        ],
                      );
                    }

                    final flashcardSets = sets
                        .where((s) => s.isFlashcard)
                        .toList();
                    final quizSets = sets.where((s) => s.isQuiz).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (flashcardSets.isNotEmpty) ...[
                          const Text(
                            'Bộ Thẻ Flashcard',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...flashcardSets.map(
                            (s) => _buildSetCard(s, isQuiz: false),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (quizSets.isNotEmpty) ...[
                          const Text(
                            'Bài Trắc Nghiệm (Quiz)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...quizSets.map(
                            (s) => _buildSetCard(s, isQuiz: true),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMentorSetCard(GeneratedSet set) {
    final isQuiz = set.isQuiz;
    final isDraft = set.isDraft;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isQuiz
              ? Colors.deepPurple.shade100
              : Colors.blue.shade100,
          child: Icon(
            isQuiz ? Icons.quiz_outlined : Icons.style_outlined,
            color: isQuiz ? Colors.deepPurple.shade900 : Colors.blue.shade900,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                set.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDraft ? Colors.amber.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isDraft ? 'Bản nháp' : 'Đã phát hành',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDraft
                      ? Colors.amber.shade900
                      : Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${isQuiz ? "Quiz" : "Flashcard"} • Độ khó: ${set.difficulty.toUpperCase()}'
          '${set.topic != null ? ' • Chủ đề: ${set.topic}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDraft && isQuiz)
              IconButton(
                tooltip: 'Tiến độ làm bài',
                icon: const Icon(Icons.bar_chart, color: Colors.orange),
                onPressed: () => _openAnalytics(set),
              ),
            if (isDraft)
              IconButton(
                tooltip: 'Xem & Duyệt phát hành',
                icon: const Icon(Icons.rate_review_outlined, color: Colors.blue),
                onPressed: () => _openDraftReview(set),
              ),
            IconButton(
              tooltip: 'Sửa thông tin',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editSetMetadata(set),
            ),
            IconButton(
              tooltip: 'Xoá',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteSet(set),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetCard(GeneratedSet set, {required bool isQuiz}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isQuiz
              ? Colors.deepPurple.shade100
              : Colors.blue.shade100,
          child: Icon(
            isQuiz ? Icons.quiz_outlined : Icons.style_outlined,
            color: isQuiz ? Colors.deepPurple.shade900 : Colors.blue.shade900,
          ),
        ),
        title: Text(
          set.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Độ khó: ${set.difficulty.toUpperCase()} ${set.topic != null ? '• Chủ đề: ${set.topic}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isQuiz)
              IconButton(
                tooltip: 'Thống kê kết quả phòng',
                icon: const Icon(Icons.bar_chart, color: Colors.orange),
                onPressed: () => _openAnalytics(set),
              ),
            FilledButton.tonal(
              onPressed: () {
                if (isQuiz) {
                  _openQuiz(set);
                } else {
                  _openFlashcards(set);
                }
              },
              child: Text(isQuiz ? 'Làm bài' : 'Học thẻ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        ),
      ],
    );
  }
}
