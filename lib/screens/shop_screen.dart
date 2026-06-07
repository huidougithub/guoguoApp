import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../models/app_models.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/ui_components.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? previewCosmeticId;
  String? previewPetId;
  String message = '欢迎来到魔法商店。';

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    if (!_supportsPremiumSkins(store.progress.selectedPet)) {
      previewPetId = 'fifi';
    }
    if (store.progress.settings['music'] ?? false) {
      AudioService.playBgm(AppMusicScene.shop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = store.progress;
    final pet = petById(_displayPetId());
    final shownCosmetics = {
      ...store.equippedCosmeticsForPet(pet.id),
      ?previewCosmeticId,
    };
    return ExplorerScaffold(
      title: '魔法商店',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: SoftCard(
                color: const Color(0xFFFFF8E1),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PetAvatar(
                        pet: pet,
                        level: progress.petLevel,
                        size: 220,
                        cheering: true,
                        cosmeticIds: shownCosmetics,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${pet.name} · ${pet.role}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          StatPill(
                            icon: Icons.energy_savings_leaf,
                            label: '能量果',
                            value: '${progress.energyFruit}',
                            color: const Color(0xFFA7F3D0),
                          ),
                          StatPill(
                            icon: Icons.star,
                            label: '星星',
                            value: '${progress.totalStars}',
                            color: const Color(0xFFFFE08A),
                          ),
                          StatPill(
                            icon: Icons.workspace_premium,
                            label: '勋章',
                            value: '${progress.badges.length}',
                            color: const Color(0xFFBFDBFE),
                          ),
                          StatPill(
                            icon: Icons.diamond,
                            label: '钻石',
                            value: '${progress.diamonds}',
                            color: const Color(0xFFE9D5FF),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '整套试卷一次性全部做对，可获得1颗钻石。',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 7,
              child: DefaultTabController(
                length: 3,
                child: SoftCard(
                  color: const Color(0xFFE3F2FD),
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(icon: Icon(Icons.checkroom), text: '装扮'),
                          Tab(icon: Icon(Icons.auto_awesome), text: '勋章宠物'),
                          Tab(icon: Icon(Icons.inventory_2), text: '钻石兑换'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _CosmeticShopGrid(
                              store: store,
                              previewId: previewCosmeticId,
                              onPreview: (id) => setState(() {
                                previewCosmeticId = id;
                                if (!_supportsPremiumSkins(_displayPetId())) {
                                  previewPetId = 'fifi';
                                }
                              }),
                              onPurchase: _purchaseCosmetic,
                              onToggle: _toggleCosmetic,
                            ),
                            _PetBadgeShop(
                              store: store,
                              previewId: previewPetId,
                              onPreview: (id) =>
                                  setState(() => previewPetId = id),
                              onPurchase: _purchasePet,
                              onUse: _usePet,
                            ),
                            _DiamondExchange(
                              store: store,
                              onRedeem: _redeemRealReward,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseCosmetic(CosmeticDefinition cosmetic) async {
    final ok = await store.purchaseCosmetic(cosmetic);
    await _playResult(ok);
    if (!mounted) return;
    setState(() {
      previewCosmeticId = cosmetic.id;
      if (!_supportsPremiumSkins(_displayPetId())) {
        previewPetId = 'fifi';
      }
      message = ok ? '${cosmetic.name}兑换成功。' : '资源还不够，继续积累奖励吧。';
    });
  }

  Future<void> _toggleCosmetic(String cosmeticId) async {
    await store.toggleCosmetic(cosmeticId);
    await AudioService.playSfx(
      AppSound.tap,
      enabled: store.progress.settings['sfx'] ?? true,
    );
    if (!mounted) return;
    setState(() => message = '装扮状态已更新。');
  }

  Future<void> _purchasePet(PetDefinition pet) async {
    final ok = await store.purchasePetWithBadges(pet);
    await _playResult(ok);
    if (!mounted) return;
    setState(() {
      previewPetId = pet.id;
      message = ok ? '${pet.name}已经加入队伍。' : '勋章数量还不够。';
    });
  }

  Future<void> _usePet(PetDefinition pet) async {
    await store.selectPet(pet.id);
    await AudioService.playSfx(
      AppSound.reward,
      enabled: store.progress.settings['sfx'] ?? true,
    );
    if (!mounted) return;
    setState(() {
      previewPetId = pet.id;
      message = '已切换为${pet.name}。';
    });
  }

  Future<void> _redeemRealReward(_RealReward reward) async {
    final ok = await store.redeemRealReward(reward.id);
    await _playResult(ok);
    if (!mounted) return;
    setState(() {
      message = ok
          ? '已兑换${reward.title}，记得让家长兑现奖励。'
          : '钻石还不够，做对整套试卷可以获得钻石。';
    });
  }

  Future<void> _playResult(bool ok) {
    return AudioService.playSfx(
      ok ? AppSound.reward : AppSound.wrong,
      enabled: store.progress.settings['sfx'] ?? true,
    );
  }

  String _displayPetId() {
    final id = previewPetId ?? store.progress.selectedPet ?? 'fifi';
    if (previewCosmeticId != null && !_supportsPremiumSkins(id)) {
      return 'fifi';
    }
    return id;
  }

  bool _supportsPremiumSkins(String? petId) {
    return const {
      'fifi',
      'magic_star',
      'magic_moon',
      'magic_flower',
    }.contains(petId);
  }
}

class _CosmeticShopGrid extends StatelessWidget {
  const _CosmeticShopGrid({
    required this.store,
    required this.previewId,
    required this.onPreview,
    required this.onPurchase,
    required this.onToggle,
  });

  final AppStore store;
  final String? previewId;
  final ValueChanged<String> onPreview;
  final ValueChanged<CosmeticDefinition> onPurchase;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final sortedCosmetics = [...cosmetics]
      ..sort((a, b) {
        final levelOrder = a.requiredLevel.compareTo(b.requiredLevel);
        if (levelOrder != 0) return levelOrder;
        return cosmetics.indexOf(a).compareTo(cosmetics.indexOf(b));
      });
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3.2,
      children: sortedCosmetics.map((cosmetic) {
        final owned = store.ownsCosmetic(cosmetic);
        final equipped = store.hasCosmeticEquipped(cosmetic.id);
        final canBuy = store.canPurchaseCosmetic(cosmetic);
        final previewing = previewId == cosmetic.id;
        return _ShopTile(
          color: previewing ? const Color(0xFFFFE08A) : Colors.white,
          leading: Text(cosmetic.icon, style: const TextStyle(fontSize: 30)),
          title: cosmetic.name,
          subtitle: owned
              ? (equipped ? '已装备' : '已拥有，可点击装备')
              : 'Lv.${cosmetic.requiredLevel} · ${cosmetic.fruitCost}能量果 · ${cosmetic.starCost}星星',
          actionIcon: owned
              ? (equipped ? Icons.check_circle : Icons.radio_button_unchecked)
              : Icons.shopping_bag,
          actionEnabled: owned || canBuy,
          onTap: () => onPreview(cosmetic.id),
          onAction: owned
              ? () => onToggle(cosmetic.id)
              : canBuy
              ? () => onPurchase(cosmetic)
              : null,
        );
      }).toList(),
    );
  }
}

class _PetBadgeShop extends StatelessWidget {
  const _PetBadgeShop({
    required this.store,
    required this.previewId,
    required this.onPreview,
    required this.onPurchase,
    required this.onUse,
  });

  final AppStore store;
  final String? previewId;
  final ValueChanged<String> onPreview;
  final ValueChanged<PetDefinition> onPurchase;
  final ValueChanged<PetDefinition> onUse;

  @override
  Widget build(BuildContext context) {
    final premiumPets = pets.where((pet) => !pet.starter).toList();
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: .52,
      children: premiumPets.map((pet) {
        final owned = store.ownsPet(pet);
        final selected = store.progress.selectedPet == pet.id;
        final canBuy = store.canPurchasePet(pet);
        return SoftCard(
          color: previewId == pet.id
              ? const Color(0xFFFFE08A)
              : const Color(0xFFFFFBEB),
          padding: const EdgeInsets.all(8),
          onTap: () => onPreview(pet.id),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 64,
                child: Center(
                  child: PetAvatar(
                    pet: pet,
                    level: store.progress.petLevel,
                    size: 62,
                    cheering: selected,
                    cosmeticIds: store.equippedCosmeticsForPet(pet.id),
                  ),
                ),
              ),
              Text(
                pet.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                owned ? (selected ? '当前伙伴' : '已拥有') : '${pet.badgeCost}枚勋章兑换',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 2),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(72, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: owned
                    ? (selected ? null : () => onUse(pet))
                    : canBuy
                    ? () => onPurchase(pet)
                    : null,
                child: Text(owned ? '使用' : '兑换'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DiamondExchange extends StatelessWidget {
  const _DiamondExchange({required this.store, required this.onRedeem});

  final AppStore store;
  final ValueChanged<_RealReward> onRedeem;

  static const rewards = [
    _RealReward(
      id: 'coins_10',
      title: '10个币',
      subtitle: '现实奖励：兑换10个币',
      icon: Icons.monetization_on,
    ),
    _RealReward(
      id: 'milk_tea',
      title: '奶茶一杯',
      subtitle: '现实奖励：请家长兑现一杯奶茶',
      icon: Icons.local_cafe,
    ),
    _RealReward(
      id: 'cake',
      title: '蛋糕一个',
      subtitle: '现实奖励：请家长兑现一个蛋糕',
      icon: Icons.cake,
    ),
    _RealReward(
      id: 'snack',
      title: '零食一份',
      subtitle: '现实奖励：请家长兑现一份零食',
      icon: Icons.fastfood,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: rewards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final reward = rewards[index];
        final redeemed = store.progress.realRewardRedemptions[reward.id] ?? 0;
        final canRedeem = store.canRedeemRealReward(reward.id);
        return _ShopTile(
          color: canRedeem ? const Color(0xFFFFFBEB) : const Color(0xFFF3F4F6),
          leading: Icon(reward.icon, size: 34, color: const Color(0xFF7C3AED)),
          title: reward.title,
          subtitle: '${reward.subtitle} · 已兑 $redeemed 次 · 需要1颗钻石',
          actionIcon: Icons.diamond,
          actionEnabled: canRedeem,
          onTap: null,
          onAction: canRedeem ? () => onRedeem(reward) : null,
        );
      },
    );
  }
}

class _RealReward {
  const _RealReward({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.color,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.actionIcon,
    required this.actionEnabled,
    required this.onTap,
    required this.onAction,
  });

  final Color color;
  final Widget leading;
  final String title;
  final String subtitle;
  final IconData actionIcon;
  final bool actionEnabled;
  final VoidCallback? onTap;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(width: 44, child: Center(child: leading)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: title,
            icon: Icon(actionIcon),
            onPressed: actionEnabled ? onAction : null,
          ),
        ],
      ),
    );
  }
}
