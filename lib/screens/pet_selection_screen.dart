import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/ui_components.dart';
import 'home_screen.dart';

class PetSelectionScreen extends StatelessWidget {
  const PetSelectionScreen({
    super.key,
    required this.store,
    this.returnToPrevious = false,
  });

  final AppStore store;
  final bool returnToPrevious;

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: '选择你的探险伙伴',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              '智慧小探险家',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              '选择一位宠物伙伴，一起去奇妙知识大陆闯关。',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                children: pets.where((pet) => pet.starter).map((pet) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SoftCard(
                        color: Color(pet.primaryColor).withValues(alpha: .18),
                        onTap: () async {
                          await AudioService.playSfx(
                            AppSound.reward,
                            enabled: store.progress.settings['sfx'] ?? true,
                          );
                          await store.selectPet(pet.id);
                          if (!context.mounted) return;
                          if (returnToPrevious) {
                            Navigator.of(context).pop();
                            return;
                          }
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => HomeScreen(store: store),
                            ),
                          );
                        },
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PetAvatar(pet: pet, level: 1, size: 116),
                              const SizedBox(height: 6),
                              Text(
                                '${pet.name}（${pet.role}）',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                pet.description,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF8C42),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  '选它出发',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
