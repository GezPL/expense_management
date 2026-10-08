import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/backup_restore_helper.dart';
import '../viewmodels/home_view_model.dart';

/// Hộp thoại quản lý Sao lưu & Phục hồi dữ liệu ngoại tuyến
class BackupRestoreDialog extends StatefulWidget {
  final HomeViewModel viewModel;

  const BackupRestoreDialog({super.key, required this.viewModel});

  static Future<void> show(BuildContext context, HomeViewModel viewModel) {
    return showDialog(
      context: context,
      builder: (ctx) => BackupRestoreDialog(viewModel: viewModel),
    );
  }

  @override
  State<BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<BackupRestoreDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _pasteController = TextEditingController();
  List<File> _backupFiles = [];
  bool _isLoading = false;
  bool _isOverwrite = false; // Mặc định là Merge (Hợp nhất)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBackupFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _loadBackupFiles() async {
    setState(() => _isLoading = true);
    final files = await BackupRestoreHelper.getExistingBackupFiles();
    if (mounted) {
      setState(() {
        _backupFiles = files;
        _isLoading = false;
      });
    }
  }

  /// Thực hiện xuất file sao lưu
  Future<void> _exportBackup() async {
    setState(() => _isLoading = true);
    try {
      final file = await BackupRestoreHelper.exportBackupToFile();
      await _loadBackupFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất bản sao lưu: ${file.path.split(Platform.pathSeparator).last}'),
            backgroundColor: AppColors.primary,
            action: SnackBarAction(
              label: 'Sao chép JSON',
              textColor: Colors.white,
              onPressed: () async {
                final content = await file.readAsString();
                await Clipboard.setData(ClipboardData(text: content));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi sao lưu: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Sao chép JSON trực tiếp vào Clipboard
  Future<void> _copyJsonToClipboard() async {
    try {
      final json = await BackupRestoreHelper.generateBackupJson();
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã sao chép toàn bộ dữ liệu JSON vào bộ nhớ tạm!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tạo JSON: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Phục hồi dữ liệu từ file được chọn
  Future<void> _restoreFromFile(File file) async {
    final confirmed = await _confirmRestoreDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final content = await file.readAsString();
      final result = await BackupRestoreHelper.restoreFromJsonString(content, overwrite: _isOverwrite);

      if (mounted) {
        if (result.success) {
          await widget.viewModel.loadDashboardData();
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.message), backgroundColor: AppColors.primary),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi phục hồi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Phục hồi dữ liệu từ chuỗi JSON dán vào ô nhập
  Future<void> _restoreFromPastedText() async {
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng dán nội dung JSON sao lưu vào ô nhập')),
      );
      return;
    }

    final confirmed = await _confirmRestoreDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final result = await BackupRestoreHelper.restoreFromJsonString(text, overwrite: _isOverwrite);

      if (mounted) {
        if (result.success) {
          await widget.viewModel.loadDashboardData();
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.message), backgroundColor: AppColors.primary),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi phục hồi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _confirmRestoreDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              _isOverwrite ? 'Xác nhận Ghi đè dữ liệu?' : 'Xác nhận Hợp nhất dữ liệu?',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Text(
              _isOverwrite
                  ? 'CẢNH BÁO: Toàn bộ giao dịch và ngân sách hiện tại trên máy sẽ bị XÓA SẠCH và thay thế bằng dữ liệu từ bản sao lưu!'
                  : 'Ứng dụng sẽ nạp các giao dịch từ bản sao lưu vào danh sách hiện tại (bỏ qua các giao dịch trùng lặp).',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOverwrite ? AppColors.error : AppColors.primary,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(_isOverwrite ? 'Xác nhận Ghi đè' : 'Xác nhận Hợp nhất'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tiêu đề & Đóng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.backup_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Sao lưu & Phục hồi dữ liệu',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Sao lưu (Export)'),
                  Tab(text: 'Phục hồi (Restore)'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildExportTab(),
                        _buildRestoreTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab 1: Xuất dữ liệu sao lưu
  Widget _buildExportTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Toàn bộ lịch sử chi tiêu, danh mục và hạn mức ngân sách được sao lưu 100% trên thiết bị dạng tệp JSON tiêu chuẩn.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Nút tạo tệp sao lưu mới
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.file_download_outlined, size: 20),
            label: const Text('Xuất tệp sao lưu JSON (.json)', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _exportBackup,
          ),
          const SizedBox(height: 10),

          // Nút sao chép JSON vào clipboard
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Sao chép chuỗi JSON vào Clipboard'),
            onPressed: _copyJsonToClipboard,
          ),
          const SizedBox(height: 20),

          // Danh sách các tệp sao lưu đã tạo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CÁC BẢN SAO LƯU TRÊN THIẾT BỊ',
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_backupFiles.length} tệp',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_backupFiles.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Chưa có bản sao lưu nào được tạo', style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            ..._backupFiles.take(5).map((f) {
              final fileName = f.path.split(Platform.pathSeparator).last;
              final modTime = DateFormat('dd/MM/yyyy HH:mm').format(f.lastModifiedSync());
              final sizeKb = (f.lengthSync() / 1024).toStringAsFixed(1);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Colors.white54, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('$modTime • $sizeKb KB', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.restore_page_outlined, color: AppColors.primary, size: 20),
                      tooltip: 'Khôi phục từ tệp này',
                      onPressed: () => _restoreFromFile(f),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Tab 2: Phục hồi dữ liệu
  Widget _buildRestoreTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lựa chọn chế độ phục hồi: Hợp nhất vs Ghi đè
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isOverwrite
                    ? AppColors.error.withValues(alpha: 0.5)
                    : AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chế độ khôi phục:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isOverwrite = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: !_isOverwrite ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !_isOverwrite ? AppColors.primary : Colors.white12,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.call_merge_rounded, color: AppColors.primary, size: 16),
                              SizedBox(width: 6),
                              Text('Hợp nhất (Merge)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isOverwrite = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _isOverwrite ? AppColors.error.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isOverwrite ? AppColors.error : Colors.white12,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                              SizedBox(width: 6),
                              Text('Ghi đè (Overwrite)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isOverwrite
                      ? '⚠️ Xóa sạch dữ liệu cũ và thay thế hoàn toàn.'
                      : '✅ Giữ dữ liệu hiện tại, tự động bỏ qua giao dịch đã tồn tại.',
                  style: TextStyle(
                    color: _isOverwrite ? AppColors.error : Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ô dán nội dung JSON
          const Text('Hoặc dán nội dung JSON từ bộ nhớ tạm:', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _pasteController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0F172A),
              hintText: '{\n  "app": "expense_management",\n  "transactions": [...]\n}',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                icon: const Icon(Icons.paste_rounded, size: 16),
                label: const Text('Dán từ Clipboard', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    setState(() {
                      _pasteController.text = data!.text!;
                    });
                  }
                },
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOverwrite ? AppColors.error : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _restoreFromPastedText,
                child: const Text('Khôi phục từ ô dán', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

