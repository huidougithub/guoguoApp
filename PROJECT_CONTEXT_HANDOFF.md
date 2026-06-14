# 果果向前冲项目交接文档

更新时间：2026-06-14  
项目路径：`D:\ProJects\guoguo\guoguo_forward`  
Git 仓库：`https://github.com/huidougithub/guoguoApp.git`  
当前主要分支：`main`

## 1. 项目定位

这是一个面向儿童平板横屏使用的 Flutter Android APP。核心体验是：

- 学习关卡：数学、语文、英语、数独、自我挑战、试卷练习。
- 成长激励：宠物、金币、钻石、商店兑换、现实奖励兑换。
- 试卷练习：通过 JSON 题库把 Word/PDF 试卷转为线上练习。
- 休闲乐园：找不同、记忆翻牌、五子棋。

APP 主要用于离线或弱联网环境，优先保证平板稳定验证和真实安装体验。

## 2. 用户工作规则

- 用户没有明确说“直连更新/直连测试/更新到模拟器”，不要主动安装到模拟器。
- 用户没有明确说“打包”，不要主动构建 APK。
- 下载软件或组件时，需要先让用户指定存储位置。
- 项目目录只放项目相关文件，不要把安装包、系统组件、通用软件放进项目。
- 系统组件可放 C 盘；通用软件放 `D:\Program`。
- Android SDK 路径固定为 `D:\Android\android-sdk`。
- 默认验证命令优先使用 `dart analyze lib test`。
- 终端中文可能显示乱码，不代表文件本身损坏；不要因为 PowerShell 显示乱码就重写整份文件。

## 3. 当前开发环境

常用环境变量：

```powershell
$env:ANDROID_HOME='D:\Android\android-sdk'
$env:ANDROID_SDK_ROOT='D:\Android\android-sdk'
$env:Path='D:\Android\android-sdk\platform-tools;D:\Android\android-sdk\emulator;' + $env:Path
```

当前轻量平板模拟器：

- AVD 名称：`Guoguo_Tablet_Lite`
- 常用设备号：`emulator-5554`
- 模拟器尺寸：`1280 x 800`
- 密度：`160 dpi`
- RAM：约 `1536 MB`

常用命令：

```powershell
dart analyze lib test
flutter run -d emulator-5554 --no-resident
flutter build apk --release
```

最近一次 release APK：

```text
D:\ProJects\guoguo\guoguo_forward\build\app\outputs\flutter-apk\app-release.apk
```

最近一次构建结果：`138.23 MB`。

## 4. 最近完成的重点功能

### 4.1 休闲乐园

新增入口：主界面进入 `休闲乐园`。

文件：

- `lib/screens/leisure_playground_screen.dart`
- `assets/leisure/spot/ai/`
- `pubspec.yaml`

当前小游戏：

- 找不同
- 记忆翻牌
- 五子棋

已移除：

- 迷宫小路

### 4.2 找不同

当前找不同已经改为 AI 生图成品素材方案：

- 共 20 关。
- 每关左右两张成品图。
- 不再运行时往右图贴星星、爱心或明显答案图标。
- 每关右图的不同点是图像本身的自然变化，例如颜色变化、物品缺失、位置变化、图案变化。
- 点击前不显示答案标记。
- 点中后显示绿色圆圈和对勾。
- 热点大小已调为 `82`，适合儿童手指点击。

素材目录：

```text
assets/leisure/spot/ai/
```

素材统计：

- 40 张 JPG。
- 20 关，每关左右各一张。
- 总大小约 `6.04 MB`。
- PNG 数量为 `0`。

旧素材：

- 旧 PNG 已转换为 JPG 后删除。
- 旧 `assets/leisure/spot/real/` 已删除。

### 4.3 记忆翻牌

记忆翻牌改为动态素材池：

- 从 Flutter 资源清单读取项目图片资源。
- 素材来源包括 `assets/pets/`、`assets/pets/cosmetics/`、`assets/bosses/`、`assets/money/`。
- 排除 sheet、preview、concept、lineup、source 等不适合作为翻牌小图的大图。
- 每局随机抽取 8 对，共 16 张牌。
- 图片显示使用 `BoxFit.contain`，避免卡片内图案被裁掉。

### 4.4 五子棋

五子棋已做过体验增强：

- 去掉右侧和顶部说明栏，棋盘尽量放大。
- 自绘棋盘和棋子，棋子有阴影、高光和立体感。
- 右上角保留“新一局”按钮。
- AI 有进攻和防守评分逻辑，会优先胜利、阻挡对方胜利，并根据连子形态评分。

## 5. 试卷练习与题库

主要文件：

- `lib/screens/worksheet_library_screen.dart`
- `lib/screens/worksheet_practice_screen.dart`
- `lib/models/worksheet_models.dart`
- `lib/services/worksheet_service.dart`
- `assets/worksheets/index.json`
- `assets/worksheets/generated/`
- `tool/worksheet_format_spec_v1.md`

当前试卷功能重点：

- 支持语文、数学、英语、真题试卷分类。
- 试卷按当前年级筛选。
- 当前已导入试卷主要是一年级下册。
- 支持家长批改、手写练习、填空题、配对题。
- JSON 题库格式使用 v1.0 标准。

重要规则：

- 不再使用旧 `answer` 字段，统一使用 `answers` 数组。
- 废弃 `displayPrompt` 字段。
- 合法 `type` 控制在规范内。
- 配对题使用 `left`、`right`、`answers`。
- 语文填空可使用 `/r` 标记。

用户特别在意：

- 试卷一份对应 APP 里一套试卷，不要拆成很多套。
- 每份导入试卷希望由用户命名。
- 后续如果从 Word/PDF 继续解析，需要先给设计或拆分结果让用户确认。

## 6. 奖励系统

已新增钻石奖励方向：

- 钻石通过试卷答题获取。
- 一套试卷一次性全部做对，获得一颗钻石。
- 商店中“预留兑换”应为“钻石兑换”。
- 钻石兑换是现实奖励，道具包括：`10个币`、`奶茶一杯`、`蛋糕一个`、`零食一份`。
- 一颗钻石兑换一次。

## 7. UI 与体验要求

用户偏好：

- 设计要和现有 APP 风格一致。
- 可爱、儿童友好、纸张质感、柔和色彩。
- 不要普通 Material 风格的大白卡。
- 用户经常会用图片附件表达希望达到的视觉效果，应尽量按图还原。
- 如果设计差距大，可以考虑直接用图片资产做底图，再叠加点击区域。

主界面当前要求历史：

- 顶部积分栏左移到宠物栏上方，宽度和宠物栏一致。
- 右侧主要放练习入口。
- “错题秘境”放到“自我挑战”里。
- 去掉“家长挑战”。
- “每日练习”改为“试卷练习”。
- “宠物小屋”改为“果果加油！”。
- 语文岛、英语岛目前锁住，后续用户说开放再开放。

## 8. 音频

主要文件：

- `lib/services/audio_service.dart`
- `BGM/`
- `assets/audio_licenses/`

已知需求：

- APP 不是当前活动窗口时要进入休眠状态，音乐和音效要暂停。
- 用户曾反馈进入 APP 音乐和音效响一下就没有，后续如再次出现需优先排查音频生命周期和 AppLifecycleState。

## 9. 最近验证记录

2026-06-14 最近验证：

```powershell
dart analyze lib test
```

结果：`No issues found!`

直连更新：

```powershell
flutter run -d emulator-5554 --no-resident
```

已成功安装到模拟器。

Release APK：

```powershell
flutter build apk --release
```

已成功构建：

```text
build\app\outputs\flutter-apk\app-release.apk
```

## 10. 已知提醒

- `shared_preferences_android` 会提示 Kotlin Gradle Plugin 未来兼容性 warning，目前不影响构建。
- `flutter pub outdated` 会提示部分依赖有新版本，但当前不要主动升级，避免环境变化。
- `flutter test` 过去不稳定，优先用 `dart analyze lib test`。
- 如果要推送 Git，先看 `git status -sb`，不要回滚用户改动。
- 当前仓库有历史累积改动，提交前要确保把项目需要的文件都包含进去。

## 11. 下一步可能方向

用户可能继续提出：

- 继续优化找不同热点位置或图片难度。
- 给找不同继续增加更多关卡。
- 继续完善休闲乐园其它小游戏。
- 优化试卷练习 UI。
- 继续解析 Word/PDF 试卷为 JSON 题库。
- 调整年级、题库、奖励规则。
- 打包 APK 给真实平板安装。

推荐流程：

1. 先明确用户是否只是讨论，还是要求开始修改。
2. 修改前读对应文件和现有模式。
3. 修改后跑 `dart analyze lib test`。
4. 只有用户明确要求时才直连更新或打包。
