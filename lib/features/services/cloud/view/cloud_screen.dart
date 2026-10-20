import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '../data/cloud_api.dart';

class CloudScreen extends StatefulWidget {
  const CloudScreen({super.key});

  @override
  State<CloudScreen> createState() => _CloudScreenState();
}

class _CloudScreenState extends State<CloudScreen> {
  final CloudApi _cloudApi = CloudApi();
  final TextEditingController _searchController = TextEditingController();

  List<CloudFile> _files = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _loadFiles();

    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CloudFile> get _filteredFiles {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _files;
    }

    return _files.where((file) {
      return file.name.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _loadFiles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final files = await _cloudApi.getFiles();

      if (!mounted) return;

      setState(() {
        _files = files;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    if (_isUploading) return;

    try {
      final file = await FilePicker.pickFile();

      if (file == null) {
        return;
      }

      final path = file.path;

      if (path == null) {
        _showMessage('Не удалось получить путь к файлу');
        return;
      }

      setState(() {
        _isUploading = true;
      });

      await _cloudApi.uploadFile(path);

      if (!mounted) return;

      _showMessage('Файл загружен');

      await _loadFiles();
    } catch (error) {
      if (!mounted) return;

      _showMessage('Ошибка загрузки: ${_cleanError(error)}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _openFile(CloudFile file) async {
    if (!file.available) {
      _showMessage('Файл отсутствует на сервере', isError: true);

      return;
    }

    _showMessage('Загружаем ${file.name}...');

    try {
      await _cloudApi.downloadAndOpenFile(file);
    } catch (error) {
      if (!mounted) return;

      _showMessage(_cleanError(error), isError: true);
    }
  }

  Future<void> _deleteFile(CloudFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить файл?'),
          content: Text('«${file.name}» будет удалён из Cloud Campus.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                'Удалить',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _cloudApi.deleteFile(file.id);

      if (!mounted) return;

      _showMessage('Файл удалён');

      await _loadFiles();
    } catch (error) {
      if (!mounted) return;

      _showMessage(_cleanError(error), isError: true);
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.redAccent : null,
        ),
      );
  }

  IconData _getFileIcon(String filename) {
    final extension = filename.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;

      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return Icons.image_outlined;

      case 'doc':
      case 'docx':
        return Icons.description_outlined;

      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_outlined;

      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;

      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_outlined;

      case 'mp3':
      case 'wav':
        return Icons.audio_file_outlined;

      case 'mp4':
      case 'mov':
        return Icons.video_file_outlined;

      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cloud Campus',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUploadFile,
        backgroundColor: AppTheme.pink,
        foregroundColor: Colors.white,
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add),
        label: Text(
          _isUploading ? 'Загрузка...' : 'Добавить файл',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _loadFiles,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
          children: [
            Text(
              'Все учебные материалы в одном месте',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
            ),

            const SizedBox(height: 22),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск файлов',
                prefixIcon: const Icon(Icons.search),

                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Мои файлы',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),

                if (!_isLoading)
                  Text(
                    '${_filteredFiles.length}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.45),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 70),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.pink),
                ),
              )
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _loadFiles)
            else if (_filteredFiles.isEmpty)
              _EmptyState(
                hasSearch: _searchController.text.isNotEmpty,
                onUpload: _pickAndUploadFile,
              )
            else
              ..._filteredFiles.map(
                (file) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FileCard(
                    file: file,
                    icon: _getFileIcon(file.name),
                    onOpen: () => _openFile(file),
                    onDelete: () => _deleteFile(file),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.file,
    required this.icon,
    required this.onOpen,
    required this.onDelete,
  });

  final CloudFile file;
  final IconData icon;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.pink.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppTheme.pink, size: 27),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          file.available
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          size: 15,
                          color: file.available
                              ? Colors.green
                              : Colors.redAccent,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          file.available ? 'В облаке' : 'Недоступен',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'open') {
                    onOpen();
                  }

                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.download_outlined),
                        SizedBox(width: 12),
                        Text('Скачать и открыть'),
                      ],
                    ),
                  ),

                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent),
                        SizedBox(width: 12),
                        Text(
                          'Удалить',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearch, required this.onUpload});

  final bool hasSearch;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppTheme.pink.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_outlined,
              size: 40,
              color: AppTheme.pink,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            hasSearch ? 'Ничего не найдено' : 'Облако пока пустое',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            hasSearch
                ? 'Попробуй изменить запрос'
                : 'Загрузи первый файл в Cloud Campus',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),

          if (!hasSearch) ...[
            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.add),
              label: const Text('Добавить файл'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 54,
            color: Colors.redAccent,
          ),

          const SizedBox(height: 16),

          Text(
            'Не удалось загрузить облако',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),

          const SizedBox(height: 18),

          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
