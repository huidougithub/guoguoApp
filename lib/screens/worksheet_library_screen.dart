import 'package:flutter/material.dart';

import '../models/worksheet_models.dart';
import '../services/app_store.dart';
import '../services/worksheet_service.dart';
import '../widgets/ui_components.dart';
import 'worksheet_practice_screen.dart';

class WorksheetLibraryScreen extends StatefulWidget {
  const WorksheetLibraryScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<WorksheetLibraryScreen> createState() => _WorksheetLibraryScreenState();
}

class _WorksheetLibraryScreenState extends State<WorksheetLibraryScreen> {
  final WorksheetService service = WorksheetService();
  late Future<List<_CatalogCardData>> catalogFuture;

  @override
  void initState() {
    super.initState();
    catalogFuture = _loadCatalog();
  }

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: '试卷练习',
      child: FutureBuilder<List<_CatalogCardData>>(
        future: catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('练习列表加载失败：${snapshot.error}'));
          }
          final items = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '已导入题库',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '电脑端导入 Word 后，题集会出现在这里，孩子可以按天完成并获得奖励。',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('导入新试卷'),
                      onPressed: _importWorksheet,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 430,
                          mainAxisExtent: 230,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _WorksheetSetCard(
                        data: item,
                        onTap: () => pushScreen(
                          context,
                          WorksheetPracticeScreen(
                            store: widget.store,
                            catalogItem: item.catalogItem,
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

  Future<void> _importWorksheet() async {
    try {
      final raw = await service.pickWorksheetJson();
      if (!mounted || raw == null) return;
      final preview = service.previewWorksheet(raw);
      final title = await _askWorksheetTitle(preview.title);
      if (!mounted || title == null) return;
      final item = await service.importWorksheetFromJson(raw, title: title);
      if (!mounted) return;
      setState(() {
        catalogFuture = _loadCatalog();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导入：${item.title}')));
    } catch (error) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入失败'),
          content: Text('请选择由 Word 导入脚本生成的题库 JSON 文件。\n\n$error'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  Future<String?> _askWorksheetTitle(String suggestedTitle) async {
    final controller = TextEditingController(text: suggestedTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('给试卷取个名字'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '试卷名称',
            hintText: '例如：一年级上册语文期中检测卷',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(context).pop(value);
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<List<_CatalogCardData>> _loadCatalog() async {
    final catalog = await service.loadCatalog();
    final result = <_CatalogCardData>[];
    for (final item in catalog) {
      final worksheet = await service.loadWorksheet(item.asset);
      final progress = await service.loadProgress(worksheet.id);
      result.add(
        _CatalogCardData(
          catalogItem: item,
          worksheet: worksheet,
          progress: progress,
        ),
      );
    }
    return result;
  }
}

class _WorksheetSetCard extends StatelessWidget {
  const _WorksheetSetCard({required this.data, required this.onTap});

  final _CatalogCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worksheet = data.worksheet;
    final answered = data.progress.answeredCountFor(
      worksheet.days.expand((day) => day.questions),
    );
    final correct = data.progress.correctCountFor(
      worksheet.days.expand((day) => day.questions),
    );
    final percent = worksheet.questionCount == 0
        ? 0.0
        : answered / worksheet.questionCount;
    return SoftCard(
      color: const Color(0xFFFFF8E1),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFFFD166),
                child: Icon(
                  Icons.edit_note,
                  size: 34,
                  color: Color(0xFF2D2A32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.catalogItem.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${data.catalogItem.grade} · ${data.catalogItem.subject}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.catalogItem.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          const Spacer(),
          LinearProgressIndicator(
            value: percent.clamp(0, 1),
            minHeight: 10,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$answered/${worksheet.questionCount} 已填写',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$correct/${worksheet.autoQuestionCount} 正确',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogCardData {
  const _CatalogCardData({
    required this.catalogItem,
    required this.worksheet,
    required this.progress,
  });

  final WorksheetCatalogItem catalogItem;
  final WorksheetSet worksheet;
  final WorksheetProgress progress;
}
