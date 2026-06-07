import 'package:flutter/material.dart';

import '../models/app_models.dart';
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
  _WorksheetCategory? selectedCategory;

  static const categories = [
    _WorksheetCategory(
      id: 'chinese',
      title: '语文试卷',
      subtitle: '拼音、字词、阅读',
      badge: '语',
      icon: Icons.menu_book_rounded,
      color: Color(0xFFFFF8E1),
      accent: Color(0xFFE85D75),
    ),
    _WorksheetCategory(
      id: 'math',
      title: '数学试卷',
      subtitle: '计算、应用、图形',
      badge: '数',
      icon: Icons.calculate_rounded,
      color: Color(0xFFFFD4A3),
      accent: Color(0xFFE0A500),
    ),
    _WorksheetCategory(
      id: 'english',
      title: '英语试卷',
      subtitle: '单词、句型、阅读',
      badge: '英',
      icon: Icons.translate_rounded,
      color: Color(0xFFAEE2FF),
      accent: Color(0xFF2563EB),
    ),
    _WorksheetCategory(
      id: 'exam',
      title: '真题试卷',
      subtitle: '期中、期末、综合',
      badge: '真',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFD9C7FF),
      accent: Color(0xFF7C3AED),
    ),
  ];

  @override
  void initState() {
    super.initState();
    catalogFuture = _loadCatalog();
  }

  @override
  Widget build(BuildContext context) {
    final category = selectedCategory;
    return ExplorerScaffold(
      title: category?.title ?? '试卷练习',
      actions: [
        if (category != null)
          IconButton(
            tooltip: '导入新试卷',
            icon: const Icon(Icons.upload_file),
            onPressed: _importWorksheet,
          ),
      ],
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: category == null
                  ? _CategoryOverview(
                      key: const ValueKey('worksheet-category-overview'),
                      items: items,
                      categories: categories,
                      onSelect: (category) {
                        setState(() => selectedCategory = category);
                      },
                    )
                  : _CategoryWorksheetList(
                      key: ValueKey('worksheet-list-${category.id}'),
                      category: category,
                      items: items
                          .where((item) => _belongsToCategory(item, category))
                          .toList(),
                      onBack: () => setState(() => selectedCategory = null),
                      onImport: _importWorksheet,
                      onOpen: (item) => pushScreen(
                        context,
                        WorksheetPracticeScreen(
                          store: widget.store,
                          catalogItem: item.catalogItem,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  bool _belongsToCategory(_CatalogCardData item, _WorksheetCategory category) {
    final subject = item.catalogItem.subject.trim().toLowerCase();
    final title = item.catalogItem.title;
    final description = item.catalogItem.description;
    return switch (category.id) {
      'chinese' =>
        subject == 'chinese' || subject.contains('语文') || subject.contains('璇'),
      'math' =>
        subject == 'math' || subject.contains('数学') || subject.contains('鏁'),
      'english' =>
        subject == 'english' || subject.contains('英语') || subject.contains('鑻'),
      'exam' =>
        subject.contains('真题') ||
            title.contains('真题') ||
            description.contains('真题'),
      _ => false,
    };
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
          content: Text('请选择由题库脚本生成的 JSON 文件。\n\n$error'),
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
            hintText: '例如：一年级下册语文期中检测卷',
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
    final selectedGrade = normalizeGradeCode(widget.store.progress.selectedGrade);
    final catalog = (await service.loadCatalog())
        .where((item) => _matchesSelectedGrade(item, selectedGrade))
        .toList();
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

  bool _matchesSelectedGrade(WorksheetCatalogItem item, int selectedGrade) {
    final itemGrade = _gradeCodeFromText(item.grade);
    return itemGrade != null && itemGrade == selectedGrade;
  }

  int? _gradeCodeFromText(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), '');
    final isOne = text.contains('一年级') || text.contains('1年级');
    final isTwo = text.contains('二年级') || text.contains('2年级');
    final isUp = text.contains('上册') || text.endsWith('上');
    final isDown = text.contains('下册') || text.endsWith('下');
    if (isOne && isUp) return gradeOneUp;
    if (isOne && isDown) return gradeOneDown;
    if (isTwo && isUp) return gradeTwoUp;
    if (isTwo && isDown) return gradeTwoDown;
    return null;
  }
}

class _CategoryOverview extends StatelessWidget {
  const _CategoryOverview({
    super.key,
    required this.items,
    required this.categories,
    required this.onSelect,
  });

  final List<_CatalogCardData> items;
  final List<_WorksheetCategory> categories;
  final ValueChanged<_WorksheetCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择试卷类型',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          '按学科进入题库，选择一套试卷开始练习。',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 2.35,
            children: [
              for (final category in categories)
                _CategoryCard(
                  category: category,
                  count: _countFor(category),
                  onTap: () => onSelect(category),
                ),
            ],
          ),
        ),
      ],
    );
  }

  int _countFor(_WorksheetCategory category) {
    return items.where((item) {
      final subject = item.catalogItem.subject.trim().toLowerCase();
      final title = item.catalogItem.title;
      final description = item.catalogItem.description;
      return switch (category.id) {
        'chinese' =>
          subject == 'chinese' ||
              subject.contains('语文') ||
              subject.contains('璇'),
        'math' =>
          subject == 'math' || subject.contains('数学') || subject.contains('鏁'),
        'english' =>
          subject == 'english' ||
              subject.contains('英语') ||
              subject.contains('鑻'),
        'exam' =>
          subject.contains('真题') ||
              title.contains('真题') ||
              description.contains('真题'),
        _ => false,
      };
    }).length;
  }
}

class _CategoryWorksheetList extends StatelessWidget {
  const _CategoryWorksheetList({
    super.key,
    required this.category,
    required this.items,
    required this.onBack,
    required this.onImport,
    required this.onOpen,
  });

  final _WorksheetCategory category;
  final List<_CatalogCardData> items;
  final VoidCallback onBack;
  final VoidCallback onImport;
  final ValueChanged<_CatalogCardData> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: category.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFF2D2A32), width: 1.4),
                ),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回分类'),
              onPressed: onBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${category.title} · ${items.length}套',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('导入新试卷'),
              onPressed: onImport,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: items.isEmpty
              ? _EmptyWorksheetList(category: category)
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 208,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _WorksheetSetCard(
                      data: item,
                      category: category,
                      onTap: () => onOpen(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.onTap,
  });

  final _WorksheetCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: category.color,
      onTap: onTap,
      child: Row(
        children: [
          _SubjectBadge(category: category, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CountPill(count: count, color: category.accent),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _WorksheetSetCard extends StatelessWidget {
  const _WorksheetSetCard({
    required this.data,
    required this.category,
    required this.onTap,
  });

  final _CatalogCardData data;
  final _WorksheetCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worksheet = data.worksheet;
    final questions = worksheet.days.expand((day) => day.questions);
    final answered = data.progress.answeredCountFor(questions);
    final correct = data.progress.correctCountFor(questions);
    final percent = worksheet.questionCount == 0
        ? 0.0
        : answered / worksheet.questionCount;

    return SoftCard(
      color: category.color,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SubjectBadge(category: category, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.catalogItem.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_metaText(worksheet)} · ${_practiceType(worksheet)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 9,
            borderRadius: BorderRadius.circular(12),
            backgroundColor: Colors.white,
            color: category.accent,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '已填写 $answered/${worksheet.questionCount}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '批改 $correct/${worksheet.questionCount}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: category.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(96, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF2D2A32), width: 1.2),
                ),
              ),
              onPressed: onTap,
              child: const Text('继续练习'),
            ),
          ),
        ],
      ),
    );
  }

  String _metaText(WorksheetSet worksheet) {
    return '${data.catalogItem.grade} · ${worksheet.days.length}单元 · ${worksheet.questionCount}道';
  }

  String _practiceType(WorksheetSet worksheet) {
    if (worksheet.autoQuestionCount == 0) return '手写练习';
    if (worksheet.autoQuestionCount == worksheet.questionCount) {
      return '自动批改';
    }
    return '手写练习';
  }
}

class _EmptyWorksheetList extends StatelessWidget {
  const _EmptyWorksheetList({required this.category});

  final _WorksheetCategory category;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SoftCard(
        color: category.color,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SubjectBadge(category: category, size: 60),
              const SizedBox(height: 14),
              const Text(
                '暂无试卷',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                '导入新试卷后会出现在这里。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectBadge extends StatelessWidget {
  const _SubjectBadge({required this.category, required this.size});

  final _WorksheetCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: const Color(0xFF2D2A32), width: 1.4),
      ),
      child: Text(
        category.badge,
        style: TextStyle(
          color: category.accent,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2D2A32), width: 1.2),
      ),
      child: Text(
        '$count 套',
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WorksheetCategory {
  const _WorksheetCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.color,
    required this.accent,
  });

  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color color;
  final Color accent;
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
