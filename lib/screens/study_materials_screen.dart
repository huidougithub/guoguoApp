import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/study_material_models.dart';
import '../services/study_material_service.dart';
import '../widgets/ui_components.dart';

class StudyMaterialsScreen extends StatefulWidget {
  const StudyMaterialsScreen({super.key});

  @override
  State<StudyMaterialsScreen> createState() => _StudyMaterialsScreenState();
}

class _StudyMaterialsScreenState extends State<StudyMaterialsScreen> {
  final StudyMaterialService _service = StudyMaterialService();
  late Future<List<StudyMaterialItem>> _materialsFuture;

  @override
  void initState() {
    super.initState();
    _materialsFuture = _service.loadMaterials();
  }

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: '考试重点',
      actions: [
        IconButton(
          tooltip: '导入资料',
          icon: const Icon(Icons.upload_file_rounded),
          onPressed: _importMaterial,
        ),
      ],
      child: FutureBuilder<List<StudyMaterialItem>>(
        future: _materialsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('资料列表加载失败：${snapshot.error}'));
          }
          final materials = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StudyHeader(onImport: _importMaterial),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    itemCount: materials.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 3.5,
                        ),
                    itemBuilder: (context, index) {
                      return _StudyMaterialCard(
                        item: materials[index],
                        onTap: () => pushScreen(
                          context,
                          StudyMaterialViewerScreen(
                            item: materials[index],
                            service: _service,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _importMaterial() async {
    try {
      final item = await _service.importPdf();
      if (!mounted || item == null) return;
      setState(() => _materialsFuture = _service.loadMaterials());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导入：${item.title}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }
}

class _StudyHeader extends StatelessWidget {
  const _StudyHeader({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: const Color(0xFFFFF8E1),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, size: 34, color: Color(0xFFE85D75)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '考试重点',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  '把复习资料放在这里，点击 PDF 就能查看。',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('导入资料'),
          ),
        ],
      ),
    );
  }
}

class _StudyMaterialCard extends StatelessWidget {
  const _StudyMaterialCard({required this.item, required this.onTap});

  final StudyMaterialItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      color: item.imported ? const Color(0xFFE3F2FD) : const Color(0xFFFFE4B5),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE85D75),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2D2A32), width: 1.2),
            ),
            child: const Center(
              child: Text(
                '资料',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${item.description} · ${_sizeText(item.sizeBytes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 30),
        ],
      ),
    );
  }

  String _sizeText(int sizeBytes) {
    if (sizeBytes <= 0) return 'PDF';
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
  }
}

class StudyMaterialViewerScreen extends StatefulWidget {
  const StudyMaterialViewerScreen({
    super.key,
    required this.item,
    required this.service,
  });

  final StudyMaterialItem item;
  final StudyMaterialService service;

  @override
  State<StudyMaterialViewerScreen> createState() =>
      _StudyMaterialViewerScreenState();
}

class _StudyMaterialViewerScreenState extends State<StudyMaterialViewerScreen> {
  String? _localPath;
  int _pageCount = 0;
  int _pageIndex = 0;
  Future<Uint8List>? _pageFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _enterReadingMode();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: widget.item.title,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ViewerToolbar(
              pageIndex: _pageIndex,
              pageCount: _pageCount,
              onPrevious: _pageIndex > 0
                  ? () => _goToPage(_pageIndex - 1)
                  : null,
              onNext: _pageIndex + 1 < _pageCount
                  ? () => _goToPage(_pageIndex + 1)
                  : null,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SoftCard(
                color: Colors.white,
                padding: const EdgeInsets.all(10),
                child: _buildPageView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView() {
    if (_error != null) {
      return Center(child: Text('资料打开失败：$_error'));
    }
    if (widget.item.pageAssets.isNotEmpty) {
      return _buildImageAssetPageView();
    }
    final pageFuture = _pageFuture;
    if (pageFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<Uint8List>(
          future: pageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(child: Text('页面加载失败：${snapshot.error}'));
            }
            return ClipRect(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 3.5,
                child: Center(
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImageAssetPageView() {
    final asset = widget.item.pageAssets[_pageIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 3.5,
            child: Center(
              child: Image.asset(
                asset,
                key: ValueKey(asset),
                fit: BoxFit.contain,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _enterReadingMode() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      if (widget.item.pageAssets.isNotEmpty) {
        setState(() {
          _pageCount = widget.item.pageAssets.length;
          _pageFuture = null;
        });
        _precacheImagePages(0);
        return;
      }
      final path = await widget.service.prepareLocalPdfPath(widget.item);
      final count = await widget.service.pageCount(path);
      if (!mounted) return;
      setState(() {
        _localPath = path;
        _pageCount = count;
        _pageFuture = _renderPage(path, 0);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  Future<void> _goToPage(int pageIndex) async {
    if (widget.item.pageAssets.isNotEmpty) {
      setState(() => _pageIndex = pageIndex);
      _precacheImagePages(pageIndex);
      return;
    }
    final path = _localPath;
    if (path == null) return;
    setState(() {
      _pageIndex = pageIndex;
      _pageFuture = _renderPage(path, pageIndex);
    });
  }

  Future<Uint8List> _renderPage(String path, int pageIndex) {
    final mediaQuery = MediaQuery.of(context);
    final widthPx = (mediaQuery.size.width * mediaQuery.devicePixelRatio)
        .clamp(900, 1800)
        .round();
    return widget.service.renderPage(
      localPath: path,
      pageIndex: pageIndex,
      widthPx: widthPx,
    );
  }

  void _precacheImagePages(int pageIndex) {
    if (!mounted) return;
    for (final index in [pageIndex - 1, pageIndex, pageIndex + 1]) {
      if (index < 0 || index >= widget.item.pageAssets.length) continue;
      precacheImage(AssetImage(widget.item.pageAssets[index]), context);
    }
  }
}

class _ViewerToolbar extends StatelessWidget {
  const _ViewerToolbar({
    required this.pageIndex,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageIndex;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: const Color(0xFFE3F2FD),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          IconButton(
            tooltip: '上一页',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            pageCount == 0 ? '准备资料中' : '第 ${pageIndex + 1} / $pageCount 页',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          IconButton(
            tooltip: '下一页',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          const Spacer(),
          const Icon(Icons.touch_app_rounded),
          const SizedBox(width: 6),
          const Text('可双指放大查看', style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
