# 换电脑继续开发快速交接

更新时间：2026-06-18  
仓库：`https://github.com/huidougithub/guoguoApp.git`  
当前本机项目目录：`E:\Program Files\果果向前冲\guoguo_forward`

## 新电脑第一步

另一台电脑已有项目时，优先进入项目目录后拉取：

```powershell
git pull origin main
```

没有仓库时：

```powershell
git clone https://github.com/huidougithub/guoguoApp.git
```

进入项目后先读：

```text
PROJECT_CONTEXT_HANDOFF.md
NEXT_COMPUTER_HANDOFF.md
```

## 当前固定规则

- 用户没说“打包”，不要做正式打包交付。
- 普通改动默认先本地验证；用户明确说“直连更新/直连测试”才安装到模拟器。
- 休闲乐园这类较大界面/玩法改动，用户曾要求“完成后就直连更新”，可在完成验证后直连。
- 直连更新优先用 `flutter run -d emulator-5554 --no-resident --no-pub`；debug APK 安装作为稳定兜底，不走 release。
- Android SDK 固定使用：`D:\Android\android-sdk`。
- 当前本机 JDK 固定使用：`E:\Program Files\果果向前冲\.tools\jdk17`。
- 当前项目中文路径有时会影响工具，必要时使用 `subst W: 'E:\Program Files\果果向前冲'` 映射。
- PowerShell 显示中文乱码不代表文件损坏，不要因此重写整份文件。
- 下载速度慢、多次失败或下载超过 100MB 的文件时，先让用户协助下载。
- 下载安装包放到 `D:\software\AI`；文件安装如非必要，尽量安装到 `D:\Program Files (x86)`。

## 常用命令

```powershell
if (-not (Get-PSDrive -Name W -ErrorAction SilentlyContinue)) { subst W: 'E:\Program Files\果果向前冲' }
$env:JAVA_HOME='E:\Program Files\果果向前冲\.tools\jdk17'
$env:ANDROID_HOME='D:\Android\android-sdk'
$env:ANDROID_SDK_ROOT='D:\Android\android-sdk'
$env:Path="$env:JAVA_HOME\bin;W:\.tools\flutter\bin\mingit\cmd;D:\Android\android-sdk\platform-tools;D:\Android\android-sdk\emulator;W:\.tools\flutter\bin;" + $env:Path
Set-Location 'W:\guoguo_forward'
```

验证：

```powershell
& 'W:\.tools\flutter\bin\dart.bat' analyze lib/screens/leisure_playground_screen.dart lib/services/audio_service.dart
& 'W:\.tools\flutter\bin\flutter.bat' build apk --debug --no-tree-shake-icons
```

直连更新优先方式：

```powershell
& 'W:\.tools\flutter\bin\flutter.bat' run -d emulator-5554 --no-resident --no-pub
```

直连安装兜底方式：

```powershell
adb wait-for-device
adb install -r 'W:\guoguo_forward\build\app\outputs\flutter-apk\app-debug.apk'
adb shell am force-stop com.guoguo.guoguo_forward
adb shell monkey -p com.guoguo.guoguo_forward 1
adb shell pidof com.guoguo.guoguo_forward
```

## 当前模拟器

- AVD：`Guoguo_Test_Tablet`
- AVD 路径：`E:\Program\.android\avd\Guoguo_Test_Tablet.avd`
- 规格：Android 35 x86_64，`1280x800`，`160dpi`，`1536MB` RAM，2 CPU，2G data partition，无 Play Store，音频输出开启。
- 常见设备号：`emulator-5554`
- 若模拟器 `offline` 或 Activity Manager 报 `Broken pipe`，通常是模拟器系统服务卡住：
  - 先 `adb kill-server; adb start-server`
  - 仍不行就重启模拟器或 `adb reboot`
- 快速后台启动模拟器：

```powershell
Start-Process "D:\Android\android-sdk\emulator\emulator.exe" -ArgumentList "-avd Guoguo_Test_Tablet -no-snapshot -no-boot-anim"
```

BAT 启动建议：

```bat
@echo off
start "" "D:\Android\android-sdk\emulator\emulator.exe" -avd Guoguo_Test_Tablet -no-snapshot -no-boot-anim
exit
```

## 当前最新重点

### 2026-06-18 近期补充

- 找不同手动标记坐标已从模拟器写回项目默认关卡，涉及关卡：`2, 3, 5-24, 28, 37, 38, 39, 41, 43`。第 8 关保存 4 个点、第 9 关保存 6 个点，按 APP 内实际标记结果保留。
- 管理页已整理为二级菜单 `家长管理`，包含 `家长批改模式`、`找不同标记模式`、`显示已标记/不显示已标记`；默认不显示已标记找不同图片。
- 试卷列表已改成紧凑列表，一页显示更多试卷；主界面 `休闲乐园` 入口已移到最后。
- 近期排查过一次模拟器无声：Android 侧显示 `MediaPlayer` 正在播放、音乐流未静音、AVD 音频输出开启；当时未改代码，若复现优先查宿主机/模拟器音频链路，再查 `AudioService`。
- 快捷启动脚本：`E:\Program Files\果果向前冲\start_guoguo_test_emulator.bat`。

### 休闲乐园

文件：`lib/screens/leisure_playground_screen.dart`

已有小游戏：

- 找不同
- 记忆翻牌
- 五子棋

当前休闲乐园结构：

- 先进入小游戏选择界面，再进入具体游戏。
- 找不同、记忆翻牌、五子棋分别有自己的 BGM。
- 最近重点都在这三个小游戏，特别是找不同和五子棋。

### 找不同

素材目录：

```text
assets/leisure/spot/ai/
```

当前规则：

- 顺序关卡，不再随机。
- 已完成通过的关卡不再出现；全部完成后重新开始一轮。
- 支持手动标记模式；手动保存的坐标会直接写入本地进度，APP 内立即生效。
- 标记模式只显示未手动标记过的图组。
- 正确点中显示小型绿色对勾标记。
- 错误点中播放错误音效。
- 每关 90 秒倒计时，超时失败并播放失败音效。
- 通关后播放通关音效，等待音效结束后才切到下一关。

当前音频：

- 找不同 BGM：`bgm_spot_difference.mp3`，来源 `D:\BGM\YZ3.MP3`
- 点中正确：`ui_spot_correct.wav`，来源 `D:\BGM\音效\DANG.WAV`
- 点错：`ui_spot_wrong.mp3`，来源 `D:\BGM\音效\error.mp3`
- 通关：统一 `ui_game_complete.mp3`，来源 `D:\BGM\音效\TG2.mp3`
- 失败：`ui_game_fail.mp3`，来源 `D:\BGM\音效\fail1.mp3`

### 记忆翻牌

当前规则：

- 20 张牌，10 对。
- 有右上角步数计数和重新开始按钮。
- 步数上限为 30 步。
- 步数用完未通关则失败，锁定棋盘并播放失败音效。
- 通关播放统一通关音效和彩纸。
- BGM：`bgm_memory_flip.mp3`，来源 `D:\BGM\YZ2.MP3`

### 五子棋

当前规则：

- 进入前先选难度：简单、普通、困难。
- AI 有进攻、防守评分逻辑。
- 我方落子音效：`ui_gomoku_player_stone.mp3`，来源 `D:\BGM\音效\luozi1.mp3`
- 电脑落子音效：`ui_gomoku_ai_stone.mp3`，来源 `D:\BGM\音效\luozi2.mp3`
- 保留旧 `ui_gomoku_stone.mp3`，但五子棋当前已改用双方独立音效。
- BGM：`bgm_gomoku.mp3`，当前来源历史上曾用 `YZ1/或YZ`，如需确认以项目 raw 文件为准。

当前界面方向：

- 已放弃整张设计图底图方案，改为高质量纯 Flutter 绘制，避免底图与交互元素重叠。
- 内部顶部“五子棋”装饰条已取消。
- 底部提示栏已取消。
- 棋盘外框内边距缩小，棋盘区域尽量放大。
- “连成五颗就胜利”移动到右侧宠物下方。
- 棋盘不必死守正方形外框，优先扩大可操作区域，左右空白尽量利用。
- 胜负后中心弹出结果提示：
  - 我方赢：`哇~真厉害！`
  - 电脑赢：`你输了，下次加油`
  - 平局：`平局啦，再来一局！`
- 菲菲和三个勋章宠物胜负后使用已有结果图：
  - `assets/pets/fifi_result_happy.png`
  - `assets/pets/fifi_result_sad.png`
  - `assets/pets/magic_star_result_happy.png`
  - `assets/pets/magic_star_result_sad.png`
  - `assets/pets/magic_moon_result_happy.png`
  - `assets/pets/magic_moon_result_sad.png`
  - `assets/pets/magic_flower_result_happy.png`
  - `assets/pets/magic_flower_result_sad.png`

## 其他当前状态

- `assets/worksheets/images/` 在 `pubspec.yaml` 中仍被引用，但目录缺失；构建会提示：
  `Error: unable to find directory entry in pubspec.yaml: W:\guoguo_forward\assets\worksheets\images\`
  目前不影响 debug APK 构建成功。
- 当前 git 工作区有大量未提交改动和新增素材，接手前务必先看 `git status --short`。
- 不要随意删除 build 目录或用户素材；若要大批量清理，先确认。

## 最近验证基线

最近通过：

```powershell
dart analyze lib/screens/leisure_playground_screen.dart lib/services/audio_service.dart
flutter build apk --debug --no-tree-shake-icons
```

最近直连安装成功，APP 包名：

```text
com.guoguo.guoguo_forward
```
