import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/document_item.dart';
import '../services/document_service.dart';
import '../utils/docx_byte_extractor.dart';
import '../utils/file_downloader.dart';
import '../utils/text_extractor.dart';
import '../utils/topic_keyword_extractor.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final DocumentItem document;
  final String? extractedText;
  final VoidCallback? onGenerateAi;
  final Future<void> Function()? onDownload;

  const DocumentPreviewScreen({
    super.key,
    required this.document,
    this.extractedText,
    this.onGenerateAi,
    this.onDownload,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  String? _loadedText;
  bool _isExtracting = false;
  String? _extractNote;

  @override
  void initState() {
    super.initState();
    if (widget.extractedText != null && widget.extractedText!.trim().isNotEmpty) {
      _loadedText = widget.extractedText;
    } else if (!widget.document.isPdf) {
      _autoExtractDocx();
    }
  }

  Future<void> _autoExtractDocx() async {
    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      client = null;
    }
    if (client == null) return;

    setState(() => _isExtracting = true);
    try {
      final service = DocumentService(client);
      final bytes = await service.downloadDocumentBytes(widget.document.fileUrl);
      if (bytes != null && bytes.isNotEmpty) {
        final extracted = await DocxByteExtractor.extractTextFromDocxBytes(bytes);
        if (mounted) {
          setState(() {
            _loadedText = extracted.isNotEmpty ? extracted : null;
            if (extracted.isEmpty) {
              _extractNote = 'Không tìm thấy đoạn văn bản thuần trong tệp Word này.';
            }
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _extractNote = 'Không thể tự động đọc nội dung tệp. Bạn có thể tải về máy để xem.';
        });
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _handleDownload(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (widget.onDownload != null) {
      await widget.onDownload!();
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('Đang tải "${widget.document.fileName}"...')),
    );

    try {
      final started = await downloadFileFromUrl(
        url: widget.document.fileUrl,
        fileName: widget.document.fileName,
      );
      if (!started) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Không thể tải tệp tự động. Bạn có thể bấm nút sao chép liên kết ở góc trên.'),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Lỗi tải tệp: $e')),
      );
    }
  }

  Future<void> _handleOpenDirect(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await openFileInBrowser(widget.document.fileUrl);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không thể mở tệp trực tiếp. Hãy bấm "Tải về máy".')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doc = widget.document;
    final isPdf = doc.isPdf;
    final displayText = _loadedText;
    final hasText = displayText != null && displayText.trim().isNotEmpty;
    final keywords = TopicKeywordExtractor.extractKeywords(
      hasText ? displayText : '${doc.fileName} ${doc.topic ?? ""}',
      topN: 6,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết tài liệu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Sao chép liên kết tệp',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: doc.fileUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép liên kết tài liệu!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isPdf ? Colors.red.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPdf ? Icons.picture_as_pdf : Icons.description,
                        color: isPdf ? Colors.red.shade700 : Colors.blue.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.fileName,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${doc.fileType.toUpperCase()} • ${doc.formattedFileSize}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          if (doc.topic != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Chủ đề: ${doc.topic}',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick actions
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (isPdf)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Xem trực tiếp PDF'),
                    onPressed: () => _handleOpenDirect(context),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Tải về máy'),
                  onPressed: () => _handleDownload(context),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Tạo đề AI'),
                  onPressed: widget.onGenerateAi,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Keywords chip bar
            if (keywords.isNotEmpty) ...[
              Text(
                'Từ khóa trọng tâm nhận diện:',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: keywords
                    .map(
                      (kw) => Chip(
                        label: Text(kw, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.blue.shade50,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Extracted text preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Nội dung trích xuất (Tối đa 15.000 ký tự cho AI - BR-04):',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (hasText)
                  Text(
                    '${displayText.length} / ${TextExtractor.maxCharacters} ký tự',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              constraints: const BoxConstraints(minHeight: 180),
              child: _isExtracting
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Đang trích xuất nội dung văn bản từ tệp...'),
                          ],
                        ),
                      ),
                    )
                  : hasText
                      ? SelectableText(
                          displayText,
                          style: const TextStyle(
                            color: Colors.black87,
                            height: 1.5,
                            fontSize: 13,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPdf
                                  ? 'Tệp định dạng PDF được hỗ trợ xem nguyên bản trên trình duyệt. Bấm nút "Xem trực tiếp PDF" ở trên để đọc toàn bộ tài liệu, hoặc bấm "Tạo đề AI" để sinh câu hỏi và flashcard ôn tập.'
                                  : (_extractNote ??
                                      'Chưa có nội dung văn bản trích xuất từ tệp này. Nhấn "Tạo đề AI" để trích xuất và sinh câu hỏi tự động.'),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.5,
                                fontSize: 13,
                              ),
                            ),
                            if (isPdf) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                label: const Text('Mở xem tệp PDF trong tab mới'),
                                onPressed: () => _handleOpenDirect(context),
                              ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
