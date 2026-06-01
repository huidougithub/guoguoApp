import 'dart:math';

import 'package:flutter/material.dart';

Future<bool> showParentGate(BuildContext context) async {
  final random = Random();
  final a = random.nextInt(6) + 2;
  final b = random.nextInt(6) + 2;
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('家长验证'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请输入 $a + $b = ?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(controller.text.trim() == '${a + b}');
            },
            child: const Text('确认'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result ?? false;
}
