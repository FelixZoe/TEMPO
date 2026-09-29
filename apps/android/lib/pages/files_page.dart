import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import '../providers/app_provider.dart';
import '../theme/miui_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});
  @override
  State<FilesPage> createState() => _FilesPageState();

  /// Clear the static file cache (call on logout to prevent data leaking between accounts)
  static void clearCache() {
    _FilesPageState._cachedFiles = [];
    _FilesPageState._cachedOnline = false;
    _FilesPageState._lastFetchTime = null;
    _FilesPageState._cachedUserId = null;
  }

  /// Force refresh on next build (call after login to load new user's files)
  static void invalidateCache() {
    _FilesPageState._lastFetchTime = null;
    _FilesPageState._cachedUserId = null;
  }
}

class _FilesPageState extends State<FilesPage> {
  final ApiService _api = ApiService();

  // ===== Static cache: survives page rebuilds =====
  static List<UploadedFile> _cachedFiles = [];
  static bool _cachedOnline = false;
  static DateTime? _lastFetchTime;
  static String? _cachedUserId; // Track which user's files are cached
  static const _cacheDuration = Duration(minutes: 5);

  // Instance state
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadFileName = '';
  int _uploadFileSize = 0; // total bytes of current file
  int _uploadIndex = 0; // 1-based index in batch
  int _uploadTotal = 0; // total files in batch
  String? _uploadError; // last upload error (for toast)
  DateTime? _uploadStartTime; // for speed/ETA calculation
  String? _error;

  bool get _cacheValid {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheDuration;
  }

  @override
  void initState() {
    super.initState();
    // BUG-19: Must be logged in to access files; also invalidate if user changed
    final auth = AuthService();
    if (!auth.isLoggedIn) {
      // Not logged in — clear any stale cache and show login prompt
      _cachedFiles = [];
      _cachedOnline = false;
      _lastFetchTime = null;
      _cachedUserId = null;
      return;
    }
    final currentUserId = ServerConfig.userId;
    if (_cachedUserId != null && _cachedUserId != currentUserId) {
      // Different user logged in — clear old user's data
      _cachedFiles = [];
      _lastFetchTime = null;
      _cachedUserId = null;
    }
    if (_cacheValid &&
        _cachedFiles.isNotEmpty &&
        _cachedUserId == currentUserId) {
      // Use cached data, no server request
    } else {
      _checkServerAndLoad();
    }
  }

  Future<void> _checkServerAndLoad({bool forceRefresh = false}) async {
    // BUG-19: Must be logged in to access files
    if (!AuthService().isLoggedIn) {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
      return;
    }
    // Skip if cache is valid and not forced
    if (!forceRefresh &&
        _cacheValid &&
        _cachedFiles.isNotEmpty &&
        _cachedUserId == ServerConfig.userId) {
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _cachedOnline = await _api.checkHealth();
      if (_cachedOnline) {
        _cachedFiles = await _api.listFiles();
        _lastFetchTime = DateTime.now();
        _cachedUserId = ServerConfig.userId; // Track which user's files
      }
    } catch (e) {
      _error = '连接服务器失败';
    }
    if (mounted)
      setState(() {
        _isLoading = false;
      });
  }

  /// Show upload options: pick file or create text
  void _showUploadOptions() {
    if (!AuthService().requireLogin(context, action: '上传文件')) return;
    // Kick off a health check so the "服务器已连接" banner updates quickly.
    // Upload actions themselves are always enabled — if the server is
    // temporarily offline, the attempt will surface a specific error.
    if (!_cachedOnline) {
      _checkServerAndLoad(forceRefresh: true);
    }
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 5,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: colors.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                '上传到服务器',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            // Server status
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _cachedOnline
                    ? MiuiColors.green.withValues(alpha: 0.1)
                    : MiuiColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _cachedOnline
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    size: 18,
                    color: _cachedOnline ? MiuiColors.green : MiuiColors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _cachedOnline ? '服务器已连接' : '服务器离线',
                      style: TextStyle(
                        fontSize: 12,
                        color: _cachedOnline
                            ? MiuiColors.green
                            : MiuiColors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Option 1: Pick file from device
            _UploadOptionTile(
              icon: Icons.folder_open_rounded,
              iconColor: MiuiColors.blue,
              title: '选择文件',
              subtitle: '从手机中选择图片、文档、视频等文件',
              enabled: true,
              colors: colors,
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadFile();
              },
            ),
            // Option 2: Create text note
            _UploadOptionTile(
              icon: Icons.edit_note_rounded,
              iconColor: MiuiColors.green,
              title: '新建文本',
              subtitle: '手动输入内容并创建文本文件',
              enabled: true,
              colors: colors,
              onTap: () {
                Navigator.pop(ctx);
                _createAndUploadText();
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 24),
          ],
        ),
      ),
    );
  }

  /// Pick real files from device and upload
  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: kIsWeb, // web needs bytes directly
      );
      if (result == null || result.files.isEmpty) return;

      int successCount = 0;
      int failCount = 0;
      final totalFiles = result.files.length;

      for (int fi = 0; fi < totalFiles; fi++) {
        final file = result.files[fi];
        Uint8List? bytes;
        final String fileName = file.name;

        if (kIsWeb) {
          bytes = file.bytes;
        } else {
          if (file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          }
        }

        if (bytes == null || bytes.isEmpty) {
          failCount++;
          continue;
        }

        if (bytes.length > 100 * 1024 * 1024) {
          failCount++;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$fileName 超过 100MB 限制，已跳过'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          continue;
        }

        final fileBytes = bytes; // non-null view after null check above
        // Show progress UI
        if (mounted) {
          setState(() {
            _isUploading = true;
            _uploadProgress = 0.0;
            _uploadFileName = fileName;
            _uploadFileSize = fileBytes.length;
            _uploadIndex = fi + 1;
            _uploadTotal = totalFiles;
            _uploadStartTime = DateTime.now();
            _uploadError = null;
          });
        }

        final res = await _api.uploadFileSafe(
          fileName: fileName,
          fileBytes: fileBytes,
          onProgress: (progress) {
            if (mounted)
              setState(() {
                _uploadProgress = progress;
              });
          },
        );
        if (res.file != null) {
          _cachedFiles.insert(0, res.file!);
          successCount++;
        } else {
          failCount++;
          _uploadError = res.error;
        }
      }

      _lastFetchTime = DateTime.now();
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadFileName = '';
          _uploadFileSize = 0;
          _uploadIndex = 0;
          _uploadTotal = 0;
        });
        final msg = failCount == 0
            ? '已上传 $successCount 个文件'
            : '上传完成: $successCount 成功, $failCount 失败${_uploadError != null ? "\n原因: $_uploadError" : ""}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: failCount == 0 ? MiuiColors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: failCount == 0 ? 2 : 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadFileName = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择文件失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Create a text file and upload
  Future<void> _createAndUploadText() async {
    final colors = AppColors.of(context);
    final nameController = TextEditingController(
      text: 'note_${DateTime.now().millisecondsSinceEpoch ~/ 1000}.txt',
    );
    final contentController = TextEditingController();

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: colors.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Text(
                    '新建文本文件',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                // Filename
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: nameController,
                      style: TextStyle(color: colors.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '文件名',
                        hintStyle: TextStyle(color: colors.textTertiary),
                        border: InputBorder.none,
                        icon: Icon(
                          Icons.description_rounded,
                          color: colors.textTertiary,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: contentController,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: '输入文件内容...',
                        hintStyle: TextStyle(color: colors.textTertiary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                // Submit
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx, {
                          'name': nameController.text,
                          'content': contentController.text,
                        });
                      },
                      icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                      label: const Text(
                        '上传到服务器',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MiuiColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null && result['name']!.isNotEmpty) {
      final bytes = Uint8List.fromList(utf8.encode(result['content'] ?? ''));
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _uploadFileName = result['name']!;
        _uploadFileSize = bytes.length;
        _uploadIndex = 1;
        _uploadTotal = 1;
        _uploadStartTime = DateTime.now();
        _uploadError = null;
      });
      final res = await _api.uploadFileSafe(
        fileName: result['name']!,
        fileBytes: bytes,
        onProgress: (progress) {
          if (mounted)
            setState(() {
              _uploadProgress = progress;
            });
        },
      );
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadFileName = '';
          _uploadFileSize = 0;
          _uploadIndex = 0;
          _uploadTotal = 0;
        });
        if (res.file != null) {
          _cachedFiles.insert(0, res.file!);
          _lastFetchTime = DateTime.now();
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '已上传: ${res.file!.name} (${res.file!.sizeFormatted})',
              ),
              backgroundColor: MiuiColors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.error ?? '上传失败，请检查网络'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteServerFile(UploadedFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(context);
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('删除文件', style: TextStyle(color: colors.textPrimary)),
          content: Text(
            '确定要从服务器删除 "${file.name}" 吗？',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _showLoadingSnackBar('正在删除...');
      final res = await _api.deleteFileSafe(file.savedName, fileUrl: file.url);
      // Fire-and-forget local cleanup
      unawaited(_deleteLocalCopy(file.name));
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (res.success) {
        setState(() {
          _cachedFiles.removeWhere((f) => f.savedName == file.savedName);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除: ${file.name}'),
            backgroundColor: MiuiColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Re-sync in background
        _checkServerAndLoad(forceRefresh: true);
      } else {
        // DELETE failed — keep the file in the list so the user doesn't lose sight of it
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: ${res.error ?? "未知错误"}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: () => _deleteServerFile(file),
            ),
          ),
        );
      }
    }
  }

  // ═══ Download file to local storage ═══
  Future<String?> _downloadToLocal(UploadedFile file) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${dir.path}/downloads');
      if (!downloadDir.existsSync()) downloadDir.createSync(recursive: true);
      final savePath = '${downloadDir.path}/${file.name}';

      // Check if already downloaded
      final localFile = File(savePath);
      if (localFile.existsSync() && localFile.lengthSync() == file.size) {
        return savePath;
      }

      final response = await http
          .get(
            Uri.parse(Uri.encodeFull(file.downloadUrl)),
            headers: ServerConfig.signedHeaders(file.url),
          )
          .timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        return savePath;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Download error: $e');
      return null;
    }
  }

  /// Delete local cached copy of a file
  Future<void> _deleteLocalCopy(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/downloads/$fileName');
      if (await localFile.exists()) {
        await localFile.delete();
      }
    } catch (_) {}
  }

  // ═══ Show file action bottom sheet ═══
  void _showFileActions(UploadedFile file) {
    final colors = AppColors.of(context);
    final ext = file.name.split('.').last.toLowerCase();
    final isPreviewable = [
      'txt',
      'md',
      'json',
      'csv',
      'log',
      'xml',
      'html',
      'css',
      'js',
      'dart',
      'py',
      'yaml',
      'yml',
    ].contains(ext);
    final isImage = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(ext);
    final isMedia = [
      'pdf',
      'mp4',
      'mp3',
      'wav',
      'flac',
      'aac',
      'avi',
      'mkv',
      'mov',
    ].contains(ext);
    final isArchive = [
      'zip',
      'rar',
      '7z',
      'tar',
      'gz',
      'bz2',
      'xz',
    ].contains(ext);

    // File type label for info card
    String fileTypeLabel() {
      if (isImage) return '图片文件';
      if (['mp4', 'avi', 'mkv', 'mov'].contains(ext)) return '视频文件';
      if (['mp3', 'wav', 'flac', 'aac'].contains(ext)) return '音频文件';
      if (ext == 'pdf') return 'PDF 文档';
      if (['doc', 'docx'].contains(ext)) return 'Word 文档';
      if (['xls', 'xlsx'].contains(ext)) return 'Excel 表格';
      if (['ppt', 'pptx'].contains(ext)) return 'PPT 演示文稿';
      if (isArchive) return '压缩包';
      if (isPreviewable) return '文本文件';
      return '文件';
    }

    IconData fileTypeIcon() {
      if (isImage) return Icons.image_rounded;
      if (['mp4', 'avi', 'mkv', 'mov'].contains(ext))
        return Icons.videocam_rounded;
      if (['mp3', 'wav', 'flac', 'aac'].contains(ext))
        return Icons.audiotrack_rounded;
      if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
      if (['doc', 'docx'].contains(ext)) return Icons.article_rounded;
      if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart_rounded;
      if (isArchive) return Icons.folder_zip_rounded;
      if (isPreviewable) return Icons.description_rounded;
      return Icons.insert_drive_file_rounded;
    }

    Color fileTypeColor() {
      if (isImage) return MiuiColors.purple;
      if (['mp4', 'avi', 'mkv', 'mov'].contains(ext)) return MiuiColors.red;
      if (['mp3', 'wav', 'flac', 'aac'].contains(ext)) return MiuiColors.teal;
      if (ext == 'pdf') return MiuiColors.red;
      if (['doc', 'docx'].contains(ext)) return MiuiColors.blue;
      if (isArchive) return MiuiColors.orange;
      if (isPreviewable) return MiuiColors.blue;
      return MiuiColors.teal;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // ── 文件信息卡片 (inline preview) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: fileTypeColor().withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: fileTypeColor().withValues(alpha: 0.12),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: fileTypeColor().withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              fileTypeIcon(),
                              size: 24,
                              color: fileTypeColor(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fileTypeLabel(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: fileTypeColor(),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Meta info row
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _fileInfoChip(
                              Icons.storage_rounded,
                              file.sizeFormatted,
                              colors,
                            ),
                            Container(
                              width: 1,
                              height: 16,
                              color: colors.divider,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            _fileInfoChip(
                              Icons.text_snippet_rounded,
                              '.${ext.toUpperCase()}',
                              colors,
                            ),
                            Container(
                              width: 1,
                              height: 16,
                              color: colors.divider,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            _fileInfoChip(
                              Icons.cloud_done_rounded,
                              '云端',
                              colors,
                            ),
                          ],
                        ),
                      ),
                      // Inline image thumbnail preview
                      if (isImage) ...[
                        const SizedBox(height: 12),
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: colors.surface,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            file.downloadUrl,
                            headers: ServerConfig.signedHeaders(file.url),
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) =>
                                progress == null
                                ? child
                                : Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: MiuiColors.purple,
                                    ),
                                  ),
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                size: 40,
                                color: colors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Hint for non-previewable types
                      if (isMedia) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: colors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ext == 'pdf'
                                    ? '下载后可查看 PDF 内容'
                                    : ['mp4', 'avi', 'mkv', 'mov'].contains(ext)
                                    ? '下载后可播放视频'
                                    : '下载后可播放音频',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (isArchive) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: colors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '下载后可解压查看压缩包内容',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Preview (text files)
              if (isPreviewable)
                _FileActionTile(
                  icon: Icons.visibility_rounded,
                  iconColor: MiuiColors.purple,
                  title: '预览',
                  subtitle: '查看文件内容',
                  colors: colors,
                  onTap: () {
                    Navigator.pop(ctx);
                    _previewTextFile(file);
                  },
                ),

              // Preview (image files) - fullscreen
              if (isImage)
                _FileActionTile(
                  icon: Icons.fullscreen_rounded,
                  iconColor: MiuiColors.purple,
                  title: '全屏预览',
                  subtitle: '查看原图',
                  colors: colors,
                  onTap: () {
                    Navigator.pop(ctx);
                    _previewImageFile(file);
                  },
                ),

              // Download
              _FileActionTile(
                icon: Icons.download_rounded,
                iconColor: MiuiColors.blue,
                title: '下载',
                subtitle: '保存到本地存储',
                colors: colors,
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadAndOpen(file);
                },
              ),

              // Share with settings (expiry, download limit) → generates link and opens system share
              _FileActionTile(
                icon: Icons.share_rounded,
                iconColor: MiuiColors.green,
                title: '分享',
                subtitle: '设置下载次数和有效期，生成分享链接',
                colors: colors,
                onTap: () {
                  Navigator.pop(ctx);
                  _shareFile(file);
                },
              ),

              // Open with...
              _FileActionTile(
                icon: Icons.open_in_new_rounded,
                iconColor: MiuiColors.orange,
                title: '用其他应用打开',
                subtitle: '选择打开方式',
                colors: colors,
                onTap: () {
                  Navigator.pop(ctx);
                  _openWithExternal(file);
                },
              ),

              // Delete
              _FileActionTile(
                icon: Icons.delete_outline_rounded,
                iconColor: MiuiColors.red,
                title: '删除',
                subtitle: '从服务器删除',
                colors: colors,
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteServerFile(file);
                },
              ),

              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileInfoChip(IconData icon, String label, AppColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ═══ Preview text file content ═══
  Future<void> _previewTextFile(UploadedFile file) async {
    final colors = AppColors.of(context);
    _showLoadingSnackBar('加载中...');

    try {
      final response = await http
          .get(
            Uri.parse(Uri.encodeFull(file.downloadUrl)),
            headers: ServerConfig.signedHeaders(file.url),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        final content = utf8.decode(response.bodyBytes, allowMalformed: true);
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            builder: (ctx, scrollController) => Container(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: colors.textTertiary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_rounded,
                          size: 20,
                          color: MiuiColors.blue,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            file.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          file.sizeFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: colors.divider, height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                        content,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          fontFamily: 'monospace',
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        _showErrorSnackBar('加载失败 (${response.statusCode})');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('加载失败: $e');
    }
  }

  // ═══ Preview image file ═══
  Future<void> _previewImageFile(UploadedFile file) async {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: colors.card,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          file.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.6,
                  ),
                  child: Image.network(
                    file.downloadUrl,
                    headers: ServerConfig.signedHeaders(file.url),
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                : null,
                            color: MiuiColors.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (ctx, err, stack) => SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_rounded,
                              size: 48,
                              color: colors.textTertiary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '加载失败',
                              style: TextStyle(color: colors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══ Download and open file ═══
  Future<void> _downloadAndOpen(UploadedFile file) async {
    _showLoadingSnackBar('下载中...');
    final path = await _downloadToLocal(file);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已保存: ${file.name}'),
          backgroundColor: MiuiColors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '打开',
            textColor: Colors.white,
            onPressed: () => OpenFilex.open(path),
          ),
        ),
      );
    } else {
      _showErrorSnackBar('下载失败');
    }
  }

  // ═══ Share file via link (with settings) ═══
  Future<void> _shareFile(UploadedFile file) async {
    final colors = AppColors.of(context);
    int selectedDownloads = 0; // 0 = unlimited
    int selectedExpireIdx = 0; // 0 = never
    final downloadOptions = [
      {'label': '不限', 'value': -1},
      {'label': '1 次', 'value': 1},
      {'label': '3 次', 'value': 3},
      {'label': '5 次', 'value': 5},
      {'label': '10 次', 'value': 10},
      {'label': '50 次', 'value': 50},
    ];
    final expireOptions = [
      {'label': '永不过期', 'hours': 0},
      {'label': '1 小时', 'hours': 1},
      {'label': '6 小时', 'hours': 6},
      {'label': '1 天', 'hours': 24},
      {'label': '3 天', 'hours': 72},
      {'label': '7 天', 'hours': 168},
      {'label': '30 天', 'hours': 720},
    ];

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Row(
                  children: [
                    Icon(Icons.link_rounded, color: MiuiColors.green, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '分享设置',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Text(
                  file.name,
                  style: TextStyle(fontSize: 13, color: colors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              // Download limit
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '下载次数限制',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(downloadOptions.length, (i) {
                        final selected = selectedDownloads == i;
                        return GestureDetector(
                          onTap: () => setBS(() => selectedDownloads = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? MiuiColors.primary
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              downloadOptions[i]['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Expiration
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '有效期',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(expireOptions.length, (i) {
                        final selected = selectedExpireIdx == i;
                        return GestureDetector(
                          onTap: () => setBS(() => selectedExpireIdx = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? MiuiColors.primary
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              expireOptions[i]['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, {
                      'max_downloads':
                          downloadOptions[selectedDownloads]['value'] as int,
                      'expire_hours':
                          expireOptions[selectedExpireIdx]['hours'] as int,
                    }),
                    icon: const Icon(Icons.link_rounded, size: 20),
                    label: const Text(
                      '生成分享链接',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MiuiColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 24),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    _showLoadingSnackBar('生成分享链接...');

    final res = await _api.createShareLinkSafe(
      savedName: file.savedName,
      originalName: file.name,
      fileUserId: file.fileUserId,
      maxDownloads: result['max_downloads']!,
      expireHours: result['expire_hours']!,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (res.data != null) {
      final shareUrl = (res.data!['full_url'] ?? '').toString();
      if (shareUrl.isEmpty) {
        _showErrorSnackBar('服务器返回的分享链接为空');
        return;
      }

      // Build a friendly share message with limits info
      final maxDl = result['max_downloads']!;
      final expHrs = result['expire_hours']!;
      final limitText = maxDl == -1 ? '不限次数' : '限 $maxDl 次';
      final expireText = expHrs == 0
          ? '永久有效'
          : expHrs < 24
          ? '$expHrs 小时内有效'
          : '${expHrs ~/ 24} 天内有效';
      final shareText =
          '📎 ${file.name}\n'
          '🔗 $shareUrl\n'
          '⏱ $expireText · $limitText';

      await Clipboard.setData(ClipboardData(text: shareUrl));

      // Show a preview dialog so user can verify the link before sharing
      final confirmed = await _showShareLinkPreview(
        file,
        shareUrl,
        expireText,
        limitText,
      );
      if (confirmed == true) {
        await SharePlus.instance.share(
          ShareParams(text: shareText, subject: '分享文件：${file.name}'),
        );
      }
    } else {
      _showErrorSnackBar('生成分享链接失败: ${res.error ?? "未知错误"}');
    }
  }

  /// Preview the generated share link before opening system share sheet.
  Future<bool?> _showShareLinkPreview(
    UploadedFile file,
    String shareUrl,
    String expireText,
    String limitText,
  ) async {
    final colors = AppColors.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 5,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: colors.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MiuiColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: MiuiColors.green,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '分享链接已生成',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$expireText · $limitText',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Link card
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: MiuiColors.green.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '链接',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    shareUrl,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textPrimary,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '✓ 已复制到剪贴板',
                style: TextStyle(
                  fontSize: 12,
                  color: MiuiColors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('完成'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.divider),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('分享到...'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MiuiColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  // ═══ Open with external app ═══
  Future<void> _openWithExternal(UploadedFile file) async {
    _showLoadingSnackBar('下载中...');
    final path = await _downloadToLocal(file);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (path != null) {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        _showErrorSnackBar('无法打开此文件类型');
      }
    } else {
      _showErrorSnackBar('下载失败');
    }
  }

  void _showLoadingSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(msg),
          ],
        ),
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return SafeArea(
          bottom: false,
          child: NestedScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    32,
                    Breathing.pagePaddingH,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '文件',
                        style: TextStyle(
                          fontSize: provider.titleSize,
                          fontWeight: provider.titleWeight,
                          color: colors.textPrimary,
                          letterSpacing: -0.8,
                        ),
                      ),
                      Row(
                        children: [
                          _HeaderBtn(
                            icon: Icons.refresh_rounded,
                            onTap: () =>
                                _checkServerAndLoad(forceRefresh: true),
                            colors: colors,
                          ),
                          const SizedBox(width: 10),
                          _HeaderBtn(
                            icon: Icons.cloud_upload_rounded,
                            onTap: _showUploadOptions,
                            colors: colors,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Server status bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    16,
                    Breathing.pagePaddingH,
                    0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _cachedOnline
                          ? MiuiColors.green.withValues(alpha: 0.08)
                          : MiuiColors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _cachedOnline
                                ? MiuiColors.green
                                : MiuiColors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _cachedOnline
                                ? '服务器在线 · ${_cachedFiles.length} 个文件'
                                : '服务器离线',
                            style: TextStyle(
                              fontSize: 13,
                              color: _cachedOnline
                                  ? MiuiColors.green
                                  : MiuiColors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_isUploading)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MiuiColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // ═══ Upload progress card ═══
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Breathing.pagePaddingH,
                    12,
                    Breathing.pagePaddingH,
                    0,
                  ),
                  child: _UploadProgressCard(
                    fileName: _uploadFileName,
                    progress: _uploadProgress,
                    fileSize: _uploadFileSize,
                    batchIndex: _uploadIndex,
                    batchTotal: _uploadTotal,
                    startTime: _uploadStartTime,
                    colors: colors,
                  ),
                ),
            ],
            body: _buildServerFilesTab(colors),
          ),
        );
      },
    );
  }

  Widget _buildServerFilesTab(AppColors colors) {
    // BUG-19: Must be logged in to see files
    if (!AuthService().isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: MiuiColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 32,
                color: MiuiColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '登录后使用云端文件',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '登录后即可上传、管理、分享文件',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  AuthService().requireLogin(context, action: '使用云端文件'),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('去登录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MiuiColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      // Shimmer skeleton loading for files
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          Breathing.pagePaddingH,
          16,
          Breathing.pagePaddingH,
          100,
        ),
        itemCount: 6,
        itemBuilder: (_, i) => _buildFileShimmerRow(colors),
      );
    }

    if (!_cachedOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: colors.textTertiary),
            const SizedBox(height: 16),
            Text(
              '服务器离线',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '无法连接到远程服务器',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _checkServerAndLoad,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MiuiColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    if (_cachedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_queue_rounded,
              size: 56,
              color: colors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无云端文件',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右上角上传文件到服务器',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showUploadOptions,
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: const Text('上传文件'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MiuiColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _checkServerAndLoad(forceRefresh: true),
      color: MiuiColors.primary,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          Breathing.pagePaddingH,
          16,
          Breathing.pagePaddingH,
          100,
        ),
        itemCount: _cachedFiles.length,
        itemBuilder: (_, i) {
          final file = _cachedFiles[i];
          final ext = file.name.split('.').last.toLowerCase();
          return _ServerFileRow(
            file: file,
            colors: colors,
            onTap: () => _showFileActions(file),
            onDelete: () => _deleteServerFile(file),
            onPreview: _ServerFileRow.isPreviewable(ext)
                ? () {
                    final isImage = [
                      'png',
                      'jpg',
                      'jpeg',
                      'gif',
                      'webp',
                      'bmp',
                    ].contains(ext);
                    if (isImage) {
                      _previewImageFile(file);
                    } else if (_ServerFileRow.isMediaFile(ext)) {
                      _downloadAndOpen(file);
                    } else {
                      _previewTextFile(file);
                    }
                  }
                : null,
          );
        },
      ),
    );
  }

  Widget _buildFileShimmerRow(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _FileShimmerBox(
            width: 44,
            height: 44,
            borderRadius: 14,
            colors: colors,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FileShimmerBox(
                  width: 160,
                  height: 14,
                  borderRadius: 6,
                  colors: colors,
                ),
                const SizedBox(height: 8),
                _FileShimmerBox(
                  width: 100,
                  height: 10,
                  borderRadius: 4,
                  colors: colors,
                ),
              ],
            ),
          ),
          _FileShimmerBox(
            width: 20,
            height: 20,
            borderRadius: 10,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _FileShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final AppColors colors;
  const _FileShimmerBox({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.colors,
  });
  @override
  State<_FileShimmerBox> createState() => _FileShimmerBoxState();
}

class _FileShimmerBoxState extends State<_FileShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final s = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                widget.colors.surface,
                widget.colors.card,
                widget.colors.surface,
              ],
              stops: [
                (s - 0.3).clamp(0.0, 1.0),
                s.clamp(0.0, 1.0),
                (s + 0.3).clamp(0.0, 1.0),
              ],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(2.0, 0.3),
            ),
          ),
        );
      },
    );
  }
}

class _ServerFileRow extends StatelessWidget {
  final UploadedFile file;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onPreview;
  const _ServerFileRow({
    required this.file,
    required this.colors,
    required this.onTap,
    required this.onDelete,
    this.onPreview,
  });

  static bool isPreviewable(String ext) {
    return const {
      'txt',
      'md',
      'json',
      'csv',
      'log',
      'xml',
      'html',
      'css',
      'js',
      'dart',
      'py',
      'yaml',
      'yml',
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
      'pdf',
      'mp4',
      'mp3',
      'wav',
      'flac',
      'aac',
      'avi',
      'mkv',
      'mov',
    }.contains(ext);
  }

  static bool isMediaFile(String ext) {
    return const {
      'pdf',
      'mp4',
      'mp3',
      'wav',
      'flac',
      'aac',
      'avi',
      'mkv',
      'mov',
    }.contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final ext = file.name.split('.').last.toLowerCase();
    final iconData = _iconForExt(ext);
    final iconColor = _colorForExt(ext);
    final canPreview = isPreviewable(ext);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_done_rounded,
                        size: 12,
                        color: MiuiColors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${file.sizeFormatted} · 云端',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                      if (canPreview) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: MiuiColors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '可预览',
                            style: TextStyle(
                              fontSize: 9,
                              color: MiuiColors.purple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (canPreview && onPreview != null)
              GestureDetector(
                onTap: onPreview,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color:
                        (isMediaFile(ext) ? MiuiColors.blue : MiuiColors.purple)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isMediaFile(ext)
                        ? Icons.open_in_new_rounded
                        : Icons.visibility_rounded,
                    size: 16,
                    color: isMediaFile(ext)
                        ? MiuiColors.blue
                        : MiuiColors.purple,
                  ),
                ),
              ),
            Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForExt(String ext) {
    switch (ext) {
      case 'txt':
      case 'md':
        return Icons.description_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return Icons.image_rounded;
      case 'doc':
      case 'docx':
        return Icons.article_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _colorForExt(String ext) {
    switch (ext) {
      case 'txt':
      case 'md':
        return MiuiColors.blue;
      case 'pdf':
        return MiuiColors.red;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return MiuiColors.purple;
      case 'doc':
      case 'docx':
        return MiuiColors.blue;
      default:
        return MiuiColors.teal;
    }
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final AppColors colors;
  const _HeaderBtn({
    required this.icon,
    required this.onTap,
    required this.colors,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: colors.textSecondary),
    ),
  );
}

class _UploadOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final AppColors colors;
  final VoidCallback onTap;

  const _UploadOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 炫酷上传进度卡片 v2 — 流体波纹 + 粒子喷射 + 轨道光环
/// - 流体波纹背景随进度涌动
/// - 粒子从进度条头部喷射飞散
/// - 轨道光环绕图标旋转
/// - 数字滚动计数器
/// - 完成时爆炸粒子庆祝
class _UploadProgressCard extends StatefulWidget {
  final String fileName;
  final double progress;
  final int fileSize;
  final int batchIndex;
  final int batchTotal;
  final DateTime? startTime;
  final AppColors colors;
  const _UploadProgressCard({
    required this.fileName,
    required this.progress,
    required this.fileSize,
    required this.batchIndex,
    required this.batchTotal,
    required this.startTime,
    required this.colors,
  });
  @override
  State<_UploadProgressCard> createState() => _UploadProgressCardState();
}

class _UploadProgressCardState extends State<_UploadProgressCard>
    with TickerProviderStateMixin {
  late AnimationController _waveCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _sparkCtrl;
  late AnimationController _progressCtrl;
  late AnimationController _celebCtrl;
  double _displayedProgress = 0;
  double _easedStart = 0;
  double _easedTarget = 0;
  final List<_SparkParticle> _sparks = [];
  bool _wasDone = false;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _sparkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    )..repeat();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _displayedProgress = widget.progress;
    _sparkCtrl.addListener(_tickSparks);
    _progressCtrl.addListener(() {
      final t = Curves.easeOutCubic.transform(_progressCtrl.value);
      if (mounted)
        setState(() {
          _displayedProgress = _easedStart + (_easedTarget - _easedStart) * t;
        });
    });
  }

  void _tickSparks() {
    if (_displayedProgress >= 0.999) return;
    // Spawn sparks near the progress head
    if (_rng.nextDouble() < 0.4) {
      final headX = _displayedProgress.clamp(0.0, 0.96);
      _sparks.add(
        _SparkParticle(
          x: headX + (_rng.nextDouble() - 0.5) * 0.03,
          y: 0.72,
          vx: (_rng.nextDouble() - 0.5) * 0.012,
          vy: -(_rng.nextDouble() * 0.018 + 0.008),
          life: 0,
          maxLife: 0.4 + _rng.nextDouble() * 0.5,
          size: 1.5 + _rng.nextDouble() * 3,
          color: [
            MiuiColors.primary,
            MiuiColors.blue,
            Colors.white,
            MiuiColors.teal,
          ][_rng.nextInt(4)],
        ),
      );
    }
    for (final s in _sparks) {
      s.life += 0.025;
      s.x += s.vx;
      s.y += s.vy;
      s.vy += 0.0015; // gravity
    }
    _sparks.removeWhere((s) => s.life >= s.maxLife);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _UploadProgressCard old) {
    super.didUpdateWidget(old);
    if ((widget.progress - _displayedProgress).abs() > 0.001) {
      _easedStart = _displayedProgress;
      _easedTarget = widget.progress;
      _progressCtrl.forward(from: 0);
    }
    if (widget.progress >= 0.999 && !_wasDone) {
      _wasDone = true;
      _burstCelebration();
      _celebCtrl.forward(from: 0);
    }
  }

  void _burstCelebration() {
    for (int i = 0; i < 24; i++) {
      final angle = (i / 24) * 2 * math.pi + _rng.nextDouble() * 0.3;
      final speed = 0.02 + _rng.nextDouble() * 0.04;
      _sparks.add(
        _SparkParticle(
          x: 0.15,
          y: 0.5,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 0.01,
          life: 0,
          maxLife: 0.8 + _rng.nextDouble() * 0.7,
          size: 3 + _rng.nextDouble() * 5,
          color: [
            MiuiColors.green,
            Colors.white,
            MiuiColors.primary,
            Colors.yellow.shade300,
            Colors.tealAccent,
          ][_rng.nextInt(5)],
        ),
      );
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _glowCtrl.dispose();
    _sparkCtrl.dispose();
    _progressCtrl.dispose();
    _celebCtrl.dispose();
    super.dispose();
  }

  String _fmtBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _speedEta() {
    if (widget.startTime == null || widget.fileSize <= 0) return '';
    final ms = DateTime.now().difference(widget.startTime!).inMilliseconds;
    if (ms < 300) return '准备中...';
    final done = (widget.fileSize * widget.progress).round();
    if (done <= 0) return '准备中...';
    final bps = done * 1000.0 / ms;
    String spd;
    if (bps < 1024)
      spd = '${bps.toStringAsFixed(0)} B/s';
    else if (bps < 1048576)
      spd = '${(bps / 1024).toStringAsFixed(1)} KB/s';
    else
      spd = '${(bps / 1048576).toStringAsFixed(1)} MB/s';
    final rem = widget.fileSize - done;
    if (rem <= 0 || bps <= 0) return spd;
    final eta = (rem / bps).round();
    final etaStr = eta < 60
        ? '${eta}s'
        : eta < 3600
        ? '${eta ~/ 60}m${eta % 60}s'
        : '${eta ~/ 3600}h${(eta % 3600) ~/ 60}m';
    return '$spd · 剩 $etaStr';
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final isDone = widget.progress >= 0.999;
    final pct = (_displayedProgress * 100).clamp(0, 100).toInt();
    final accentColor = isDone ? MiuiColors.green : MiuiColors.primary;
    final bytesDone = (widget.fileSize * _displayedProgress).round();

    return AnimatedBuilder(
      animation: Listenable.merge([
        _waveCtrl,
        _glowCtrl,
        _sparkCtrl,
        _celebCtrl,
      ]),
      builder: (ctx, _) {
        return Container(
          height: 108,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDone
                  ? [
                      MiuiColors.green.withValues(alpha: 0.18),
                      MiuiColors.teal.withValues(alpha: 0.08),
                    ]
                  : [
                      MiuiColors.primary.withValues(alpha: 0.16),
                      MiuiColors.blue.withValues(alpha: 0.07),
                    ],
            ),
            border: Border.all(
              color: accentColor.withValues(
                alpha: 0.35 + _glowCtrl.value * 0.25,
              ),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(
                  alpha: 0.22 + _glowCtrl.value * 0.15,
                ),
                blurRadius: 20 + _glowCtrl.value * 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _UploadWavePainter(
              progress: _displayedProgress,
              wave: _waveCtrl.value,
              sparks: List.from(_sparks),
              isDone: isDone,
              glow: _glowCtrl.value,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Neon icon
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.15),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(
                                alpha: 0.4 + _glowCtrl.value * 0.3,
                              ),
                              blurRadius: 14,
                              spreadRadius: 0,
                            ),
                          ],
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: isDone
                            ? Icon(
                                Icons.check_rounded,
                                color: MiuiColors.green,
                                size: 22,
                              )
                            : Transform.rotate(
                                angle: _waveCtrl.value * math.pi * 0.15,
                                child: Icon(
                                  Icons.cloud_upload_rounded,
                                  color: MiuiColors.primary,
                                  size: 20,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.fileName.isEmpty
                                        ? '上传中...'
                                        : widget.fileName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.batchTotal > 1) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MiuiColors.primary.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${widget.batchIndex}/${widget.batchTotal}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: MiuiColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.fileSize > 0
                                  ? '${_fmtBytes(bytesDone)} / ${_fmtBytes(widget.fileSize)}  ·  ${_speedEta()}'
                                  : isDone
                                  ? '上传完成 ✓'
                                  : '正在上传...',
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Pct counter with neon glow
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Text(
                          isDone ? '✓' : '$pct%',
                          key: ValueKey(isDone ? 'done' : pct),
                          style: TextStyle(
                            fontSize: isDone ? 24 : 22,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                            shadows: [
                              Shadow(
                                color: accentColor.withValues(
                                  alpha: 0.6 + _glowCtrl.value * 0.4,
                                ),
                                blurRadius: 10,
                              ),
                            ],
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Progress bar with liquid head
                  SizedBox(
                    height: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _displayedProgress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDone
                                      ? [MiuiColors.green, MiuiColors.teal]
                                      : [
                                          MiuiColors.primary,
                                          MiuiColors.blue,
                                          MiuiColors.primary.withValues(
                                            alpha: 0.85,
                                          ),
                                        ],
                                  begin: Alignment(_waveCtrl.value * 2 - 1, 0),
                                  end: Alignment(_waveCtrl.value * 2 + 1, 0),
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.7),
                                    blurRadius: 6,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Liquid glow head
                          if (!isDone)
                            Positioned(
                              left:
                                  (_displayedProgress.clamp(0.0, 0.97)) *
                                      (MediaQuery.of(ctx).size.width - 64) -
                                  8,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 16,
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.95),
                                      Colors.transparent,
                                    ],
                                    radius: 1.0,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Spark particle data
class _SparkParticle {
  double x, y, vx, vy, life, maxLife, size;
  Color color;
  _SparkParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.size,
    required this.color,
  });
}

/// Wave background + spark painter
class _UploadWavePainter extends CustomPainter {
  final double progress;
  final double wave;
  final List<_SparkParticle> sparks;
  final bool isDone;
  final double glow;

  _UploadWavePainter({
    required this.progress,
    required this.wave,
    required this.sparks,
    required this.isDone,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawWave(canvas, size);
    _drawSparks(canvas, size);
  }

  void _drawWave(Canvas canvas, Size size) {
    if (progress <= 0.01) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final fillLevel = progress.clamp(0.02, 1.0);
    final baseY = size.height * (1 - fillLevel * 0.4);
    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 1.5) {
      final t = x / size.width;
      final w1 = math.sin(t * 2 * math.pi + wave * 2 * math.pi) * 5;
      final w2 =
          math.sin(t * 3.7 * math.pi + wave * 2 * math.pi * 1.5 + 0.8) * 3;
      path.lineTo(x, baseY + w1 + w2);
    }
    path.lineTo(size.width, size.height);
    path.close();

    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDone
          ? [
              MiuiColors.green.withValues(alpha: 0.18),
              MiuiColors.green.withValues(alpha: 0.06),
            ]
          : [
              MiuiColors.primary.withValues(alpha: 0.14),
              MiuiColors.blue.withValues(alpha: 0.05),
            ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);
  }

  void _drawSparks(Canvas canvas, Size size) {
    for (final s in sparks) {
      if (s.life >= s.maxLife) continue;
      final t = s.life / s.maxLife;
      final opacity = (1 - t) * (1 - t);
      final sSize = s.size * (1 - t * 0.6);
      final paint = Paint()
        ..color = s.color.withValues(alpha: opacity.clamp(0.0, 0.9))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sSize * 0.7);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        sSize.clamp(0.5, 8.0),
        paint,
      );
      // Inner bright core
      final corePaint = Paint()
        ..color = Colors.white.withValues(
          alpha: (opacity * 0.8).clamp(0.0, 0.8),
        );
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        (sSize * 0.35).clamp(0.2, 3.0),
        corePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UploadWavePainter old) => true;
}

class _FileActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final AppColors colors;
  final VoidCallback onTap;

  const _FileActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
