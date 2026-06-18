# 果果向前冲项目交接文档

更新时间：2026-06-18  
项目路径：`E:\Program Files\果果向前冲\guoguo_forward`  
Git 仓库：`https://github.com/huidougithub/guoguoApp.git`  
当前主要分支：`main`

## 1. 项目定位

这是一个面向儿童平板横屏使用的 Flutter Android APP。核心体验是：

- 学习关卡：数学、语文、英语、数独、自我挑战、试卷练习。
- 成长激励：宠物、能量果、星星、勋章、金币、钻石、商店兑换、现实奖励兑换。
- 试卷练习：通过 JSON 题库把 Word/PDF/图片试卷转为线上练习。
- 休闲乐园：找不同、记忆翻牌、五子棋。

APP 主要用于离线或弱联网环境，优先保证安卓平板横屏稳定体验。用户会频繁通过截图反馈 UI 差异，视觉还原和真实模拟器效果比抽象方案更重要。

## 2. 固定工作规则

- 用户没有明确说“打包”，不要做正式 APK 交付。
- 普通代码改动默认先本地验证；用户明确说“直连更新/直连测试/更新到模拟器”才安装到模拟器。
- 休闲乐园这类较大界面或玩法改动，用户曾要求“完成后就直连更新”，完成验证后可直接更新到模拟器。
- 直连更新优先用 `flutter run -d emulator-5554 --no-resident --no-pub`；debug APK 安装作为稳定兜底，不走 release。
- 用户后续如果没有主动说，不用频繁直连模拟器更新测试；但上条的休闲乐园大改动例外。
- 下载速度慢、多次失败或下载文件超过 100MB 时，停下来让用户协助下载。
- 下载的安装包放到 `D:\software\AI`。
- 文件安装如非必要，尽量安装到 `D:\Program Files (x86)`。
- 不要把安装包、系统组件、通用软件放进项目目录。
- 终端中文乱码通常只是控制台编码问题，不代表文件损坏，不要因此重写整份业务文件。
- 不要回滚或删除用户改动；要清理大批量文件前先确认。

## 2026-06-18 最新补充

- 新建轻量测试模拟器：`Guoguo_Test_Tablet`，路径 `E:\Program\.android\avd\Guoguo_Test_Tablet.avd`，Android 35 x86_64，`1280x800`，`160dpi`，`1536MB` RAM，2 CPU，2G data partition，无 Play Store，音频输出开启。
- 快捷启动脚本已放在 `E:\Program Files\果果向前冲\start_guoguo_test_emulator.bat`。
- 当前本机 JDK 固定用 `E:\Program Files\果果向前冲\.tools\jdk17`，后续跑 Flutter/Gradle 前建议设置 `JAVA_HOME`。
- 已把模拟器里找不同手动标记坐标写回项目默认关卡，涉及关卡：`2, 3, 5-24, 28, 37, 38, 39, 41, 43`；其中第 8 关保存 4 个点、第 9 关保存 6 个点，按 APP 内实际保存结果保留。
- 管理页已改为二级菜单 `家长管理`，里面包含 `家长批改模式`、`找不同标记模式`、`显示已标记/不显示已标记`；默认不显示已标记找不同图片。
- 试卷列表已改为紧凑列表样式，一页能显示更多试卷；主界面 `休闲乐园` 入口已调整到最后。
- 近期排查过一次模拟器无声：Android 侧显示 `MediaPlayer` 已在播放、`STREAM_MUSIC` 未静音、AVD 音频输出开启；当时未改代码，若再复现，优先排查宿主机/模拟器音频链路，其次再查 `AudioService` 生命周期。

## 3. 当前开发环境

Android SDK 固定路径：

```powershell
D:\Android\android-sdk
```

当前项目在中文路径下，部分 Flutter/Git/Gradle 工具有时不稳定。推荐使用 `subst` 映射到 `W:`：

```powershell
if (-not (Get-PSDrive -Name W -ErrorAction SilentlyContinue)) { subst W: 'E:\Program Files\果果向前冲' }
$env:JAVA_HOME='E:\Program Files\果果向前冲\.tools\jdk17'
$env:ANDROID_HOME='D:\Android\android-sdk'
$env:ANDROID_SDK_ROOT='D:\Android\android-sdk'
$env:Path="$env:JAVA_HOME\bin;W:\.tools\flutter\bin\mingit\cmd;D:\Android\android-sdk\platform-tools;D:\Android\android-sdk\emulator;W:\.tools\flutter\bin;" + $env:Path
Set-Location 'W:\guoguo_forward'
```

当前模拟器：

- AVD：`Guoguo_Test_Tablet`
- AVD 路径：`E:\Program\.android\avd\Guoguo_Test_Tablet.avd`
- 规格：Android 35 x86_64，`1280x800`，`160dpi`，`1536MB` RAM，2 CPU。
- 常见设备号：`emulator-5554`
- 若设备 `offline` 或 Activity Manager 报 `Broken pipe`，先执行 `adb kill-server; adb start-server`；仍不行就重启模拟器或 `adb reboot`。

快速启动模拟器：

```powershell
Start-Process "D:\Android\android-sdk\emulator\emulator.exe" -ArgumentList "-avd Guoguo_Test_Tablet -no-snapshot -no-boot-anim"
```

BAT 快捷启动建议：

```bat
@echo off
start "" "D:\Android\android-sdk\emulator\emulator.exe" -avd Guoguo_Test_Tablet -no-snapshot -no-boot-anim
exit
```

## 4. 常用验证与直连命令

当前局部验证基线：

```powershell
& 'W:\.tools\flutter\bin\dart.bat' analyze lib/screens/leisure_playground_screen.dart lib/services/audio_service.dart
& 'W:\.tools\flutter\bin\flutter.bat' build apk --debug --no-tree-shake-icons
```

直连安装并启动：

优先方式：

```powershell
& 'W:\.tools\flutter\bin\flutter.bat' run -d emulator-5554 --no-resident --no-pub
```

兜底方式：

```powershell
adb wait-for-device
adb install -r 'W:\guoguo_forward\build\app\outputs\flutter-apk\app-debug.apk'
adb shell am force-stop com.guoguo.guoguo_forward
adb shell monkey -p com.guoguo.guoguo_forward 1
adb shell pidof com.guoguo.guoguo_forward
```

APP 包名：

```text
com.guoguo.guoguo_forward
```

## 5. 最近重点：休闲乐园

主要文件：

- `lib/screens/leisure_playground_screen.dart`
- `lib/services/audio_service.dart`
- `lib/models/app_models.dart`
- `lib/services/app_store.dart`
- `android/app/src/main/res/raw/`
- `assets/leisure/`

当前休闲乐园已经拆成多级子界面：先进入小游戏选择界面，再进入具体游戏。

已有小游戏：

- 找不同
- 记忆翻牌
- 五子棋

小游戏选择界面卡片使用图片资源，卡片右下角向右箭头已取消。

## 6. 找不同当前规则

素材目录：

```text
assets/leisure/spot/ai/
```

当前规则：

- 顺序关卡，不再随机。
- 已完成通过的关卡不再出现；全部完成后重新开始一轮。
- 顶部信息栏尽量减少，核心目标是最大化展示左右图片。
- 每关 90 秒倒计时，超时失败并播放失败音效。
- 正确点中显示小型绿色对勾标记，不再使用大圆环。
- 错误点中播放错误音效。
- 当前关卡完成后播放通关音效，等待音效播放完成后再跳下一关。
- 通关后有类似礼花/彩纸的轻量胜利特效。

手动标记模式：

- 用于解决找不同点击位置偏差。
- 标记工具条应放在右侧空白区域，不能遮挡图片。
- 手动保存坐标后，APP 内立即生效，不需要重新打包。
- 标记模式只显示未手动标记过的图组。
- 已手动保存坐标的图，不再在标记模式中出现。

找不同音频：

- BGM：`bgm_spot_difference.mp3`，来源 `D:\BGM\YZ3.MP3`
- 点中正确：`ui_spot_correct.wav`，来源 `D:\BGM\音效\DANG.WAV`
- 点错：`ui_spot_wrong.mp3`，来源 `D:\BGM\音效\error.mp3`
- 通关：统一 `ui_game_complete.mp3`，来源 `D:\BGM\音效\TG2.mp3`
- 失败：`ui_game_fail.mp3`，来源 `D:\BGM\音效\fail1.mp3`

## 7. 记忆翻牌当前规则

当前规则：

- 20 张牌，10 对。
- 右上角有步数计数和重新开始按钮。
- 步数上限为 30 步。
- 步数用完还未通关，判定失败，棋盘锁定并播放失败音效。
- 通关播放统一通关音效和彩纸特效。
- 棋盘尽量放大，顶部无关信息栏和按钮应尽量减少。

音频：

- BGM：`bgm_memory_flip.mp3`，来源 `D:\BGM\YZ2.MP3`
- 通关：`ui_game_complete.mp3`
- 失败：`ui_game_fail.mp3`

## 8. 五子棋当前规则与设计方向

当前规则：

- 进入前先选择难度：简单、普通、困难。
- AI 有进攻、防守评分逻辑，会优先胜利、阻挡对方胜利，并根据连子形态评分。
- 我方落子音效：`ui_gomoku_player_stone.mp3`，来源 `D:\BGM\音效\luozi1.mp3`
- 电脑落子音效：`ui_gomoku_ai_stone.mp3`，来源 `D:\BGM\音效\luozi2.mp3`
- 失败播放 `ui_game_fail.mp3`。
- BGM：`bgm_gomoku.mp3`。历史来源曾用 `YZ1/或YZ`，如需追溯以 `android/app/src/main/res/raw/bgm_gomoku.mp3` 为准。

最新设计决策：

- 用户曾希望接近一张高质量设计图，但整张底图方案会和交互元素重叠。
- 当前采用“方案 B”：纯 Flutter 绘制高质量 UI，而不是整图底图叠按钮。
- 顶部内部“五子棋”装饰条取消，用来扩大棋盘空间。
- 下方提示栏取消，提示文字“连成五颗就胜利”放到右侧宠物下方。
- 棋盘不必死守正方形外框，优先扩大可操作区域，左右空白尽量利用。
- 胜负后中心弹出结果提示，类似找不同的中心提示：
  - 玩家赢：`哇~真厉害！`
  - 玩家输：`你输了，下次加油`
  - 平局：`平局啦，再来一局！`
- 胜负后宠物图切换为对应笑脸/哭脸结果图。

宠物结果图：

- `assets/pets/fifi_result_happy.png`
- `assets/pets/fifi_result_sad.png`
- `assets/pets/magic_star_result_happy.png`
- `assets/pets/magic_star_result_sad.png`
- `assets/pets/magic_moon_result_happy.png`
- `assets/pets/magic_moon_result_sad.png`
- `assets/pets/magic_flower_result_happy.png`
- `assets/pets/magic_flower_result_sad.png`

## 9. 试卷练习与题库

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
- 试卷按当前年级/册别筛选。
- 当前重点导入过一年级下册语文 21 天复习冲刺题库。
- 支持分组标题、示例卡、填空、手写练习状态、家长批改、配对题等。
- 语文试卷练习题目字号曾调大，适配平板阅读。

题库解析规则：

- 结构标题如“一、看拼音写词语。”放在题组外面，一个结构标题只出现一次。
- 示例内容放示例卡，不作为答题题目；不是每个题组都有示例卡。
- “看拼音写词语”仍按填写格子拆分。
- “动词搭配”按原规则拆分，可选量词放示例卡。
- “形近字组词”按大括号拆分，一个大括号是一题；如果文字表达困难，可考虑图片展示。
- 其他语文题原则上按原试卷序号组织，不要因为有多个空就拆成多题。
- 解析出来的小题不需要保留原小序号，因为 APP 会生成连续序号。
- 不再使用旧 `answer` 字段，统一使用 `answers` 数组。
- 废弃 `displayPrompt` 字段。

试卷交互规则：

- 底部“手写练习”按钮已取消。
- “清空本页”改为“清空答题”。
- “清除”改为“擦除”。
- 家长模式开启后，才显示并启用“对/错”批改按钮。
- 错误状态通过题目背景色展示，类似数学试卷练习。
- 点击“下一题”时，如果当前题目超出展示区域，应自动滚动展示出来。

## 10. 学习册别与主界面

年级/册别选择已按实际情况拆成：

- 一年级上册
- 一年级下册
- 二年级上册
- 二年级下册
- 三至六年级上/下册占位卡

三至六年级卡片暂不响应点击，后续逐步完善内容。设置里的“切换年级”功能已去掉，不保留。

用户偏好：

- 设计要接近之前生成的高质量效果图，不要退回普通 Material 大白卡。
- 所有卡片必须同屏展示时，优先解决 `BOTTOM OVERFLOWED`。
- 视觉风格：可爱、纸张质感、柔和色彩、儿童友好。

## 11. 奖励系统

当前已知规则方向：

- 一颗能量果只加一点经验。
- 能量果：通关得 1 个，全对得 3 个，破记录得 10 个。
- 星星：根据通关评价获取对应数量。
- 勋章：仅能从数独和今日挑战里获取。
- 装扮不能共用，每个宠物都需要单独兑换。
- 装扮兑换价格要偏高，不能太容易获得。
- 商店负责所有兑换；勋章兑换物品已预留。
- 钻石通过试卷答题获取，一套试卷一次性全部做对可得一颗钻石。
- 钻石兑换是现实奖励，历史道具包括：`10个币`、`奶茶一杯`、`蛋糕一个`、`零食一份`。

## 12. 宠物与素材

重点宠物：

- 菲菲，小狐狸。
- 三个勋章宠物：星愿露露、以及另外两个魔法女孩类宠物。

已有重点素材包括：

- 宠物主形象。
- 菲菲与勋章宠物的笑脸/哭脸结算图。
- 宠物装扮图，包括帽子、披风、光环、终极形态等。
- BOSS 图。
- 休闲乐园卡片图。
- 找不同左右图素材。

用户很在意素材质量。若形象“变回原始形态”或装扮预览不跟随当前宠物，是高优先级 BUG。

## 13. 音频系统

主要文件：

- `lib/services/audio_service.dart`
- `android/app/src/main/res/raw/`
- `BGM/`

已知要求：

- APP 不是当前活动窗口时，音乐和音效应暂停或进入休眠状态。
- 用户曾反馈声音偶尔只响一下，后续如再出现，优先排查 AppLifecycleState 和 AudioService 生命周期。
- 主界面宠物声音曾改为启动第一次进入主界面时播放一次。
- 宠物点击声音、胜利声音、数独胜利声音等均已有过资源集成。

休闲乐园新增 raw 资源当前包括：

- `bgm_spot_difference.mp3`
- `bgm_memory_flip.mp3`
- `bgm_gomoku.mp3`
- `ui_game_complete.mp3`
- `ui_game_fail.mp3`
- `ui_gomoku_player_stone.mp3`
- `ui_gomoku_ai_stone.mp3`
- `ui_gomoku_stone.mp3`
- `ui_spot_correct.wav`
- `ui_spot_wrong.mp3`
- `ui_spot_complete.wav`

## 14. 已知提醒

- `pubspec.yaml` 仍引用缺失目录 `assets/worksheets/images/`，构建会提示：

```text
Error: unable to find directory entry in pubspec.yaml: W:\guoguo_forward\assets\worksheets\images\
```

目前不影响 debug APK 构建成功，后续可单独清理。

- 当前 git 工作区有大量未提交代码改动和新增素材。接手前务必先看：

```powershell
git status --short
```

- 不要使用旧的 `Guoguo_Tablet_Lite` 或 `Medium_Tablet` 模拟器说明；当前按 `Guoguo_Test_Tablet`。
- `flutter test` 过去不稳定；若用户只是要快速验证，优先局部 `dart analyze` 和 `flutter run -d emulator-5554 --no-resident --no-pub` 直连。
- 不要主动升级依赖，避免环境变化。

## 15. 最近验证基线

最近通过：

```powershell
dart analyze lib/screens/leisure_playground_screen.dart lib/services/audio_service.dart
flutter build apk --debug --no-tree-shake-icons
```

最近直连安装成功，APP 包名：

```text
com.guoguo.guoguo_forward
```

## 16. 下一步常见方向

用户可能继续提出：

- 继续把五子棋界面做得更接近设计图，同时保持交互不重叠。
- 继续优化找不同关卡、坐标标记和图片难度。
- 补充更多高质量找不同图片素材。
- 继续完善记忆翻牌和五子棋玩法平衡。
- 优化试卷练习 UI 或继续解析新试卷题库。
- 调整奖励、宠物装扮、商店兑换。
- 明确要求后打包 APK 或直连更新模拟器。

推荐流程：

1. 先判断用户是在讨论设计，还是明确要求开始改。
2. 修改前读对应文件和现有实现，不要凭历史印象改。
3. 修改后跑最小必要验证。
4. 只有用户明确要求或休闲乐园大改完成时，再直连更新。
