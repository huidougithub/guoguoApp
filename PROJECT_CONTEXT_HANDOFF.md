# 《智慧小探险家》项目上下文交接摘要

更新时间：2026-06-04  
项目路径：`E:\Program Files\果果向前冲\guoguo_forward`  
当前目录不是 Git 仓库，不能依赖 `git status` 追踪变更。

## 1. 项目目标

这是一个 Flutter 安卓平板横屏优先的离线学习 APP，名称为《智慧小探险家》。核心闭环：

- 首次选择学习册别/年级与宠物。
- 主界面进入数学岛、语文岛、英语岛、数独、错题秘境、自我挑战、魔法商店、试卷练习。
- 答题关卡结合宠物与 BOSS 对战、奖励、错题本、宠物养成、装扮兑换。
- 本地存储使用 `SharedPreferences`，不联网、不登录、不广告、不排行榜。
- 默认不打包 APK，用户明确说“打包”才打包；直连模拟器测试也不默认执行，只有用户明确说“直连测试”“更新到模拟器”或“测试一下”时再执行。

## 2. 用户偏好与约束

- 用户希望界面尽量接近确认过的设计图，而不是普通 Material 卡片。
- 视觉风格：可爱、卡通、暖色、纸张质感、圆角、柔和阴影、按钮有质感。
- 允许删除明确废弃文件，但不批量删除构建目录，除非单独确认。
- 下载很慢；超过 100M 或多次失败时让用户手动下载。
- 下载文件安装包放到 `D:\software\AI`。
- 软件安装尽量放到 `D:\Program Files (x86)`，非必要不安装。
- 英语朗读功能用户暂时搁置过，不要贸然大改英语语音逻辑，除非用户重新要求。

## 3. 环境与命令

由于中文路径曾导致 Flutter/Gradle 环境问题，项目使用 `subst W:` 临时盘方案。

常用环境初始化：

```powershell
if (-not (subst | Select-String '^W:\\')) { subst W: 'E:\Program Files\果果向前冲' }
$env:Path='W:\.tools\flutter\bin\mingit\cmd;D:\Android\android-sdk\platform-tools;D:\Android\android-sdk\emulator;' + $env:Path
$env:ANDROID_HOME='D:\Android\android-sdk'
$env:ANDROID_SDK_ROOT='D:\Android\android-sdk'
$env:JAVA_HOME='D:\Program Files\Android\Android Studio\jbr'
$env:DART_SUPPRESS_ANALYTICS='true'
$env:FLUTTER_SUPPRESS_ANALYTICS='true'
Set-Location 'W:\guoguo_forward'
```

静态检查：

```powershell
& 'W:\.tools\flutter\bin\dart.bat' analyze lib test
```

直连测试：

```powershell
& adb devices
& 'W:\.tools\flutter\bin\flutter.bat' run -d emulator-5554 --debug --no-resident
```

当前 `android/local.properties` 必须保持：

```properties
sdk.dir=D:\\Android\\android-sdk
flutter.sdk=W:\\.tools\\flutter
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
```

已知：`flutter test --no-pub` 之前不稳定，后续优先用 `dart analyze lib test`；直连测试只在用户明确要求时执行。

## 4. 最近已完成的重要改动

### 学习册别页面

文件：`lib/screens/grade_selection_screen.dart`

状态：

- 已重做为接近用户确认设计图的页面。
- 12 张册别卡片同屏展示。
- 一年级上/下、二年级上/下可点击；三到六年级上/下锁定，后续再完善内容。
- 使用浅米色背景、果果宠物图、标题、彩色圆形册别徽章、科目小标签、开始学习/待开放胶囊按钮。
- 已修复之前卡片底部 `BOTTOM OVERFLOWED BY 22 PIXELS`。

### 试卷练习页面

文件：`lib/screens/worksheet_practice_screen.dart`

状态：

- 已从普通 Material 布局重做为接近用户设计图的样式。
- 左侧为试卷学习栏：返回、标题、宠物、Day 列表、提示卡。
- 右侧为题目纸张：Day 标题、已填写数量、清空本页、检查。
- 数学答题不用系统键盘，底部改成两行数字键盘。
- 答题框位于题目最右边，题干区域尽量横向扩满。
- 去掉每题右侧对错图标，批改结果通过题目背景色展示。
- 最近修复：
  - 点击“下一题”后，如果题目在列表可见区域外，会自动滚动到当前题。
  - 检查后的错误题目颜色加深：红色背景、红色边框、红色阴影，更醒目。

### 数独

相关文件：

- `lib/screens/sudoku_screen.dart`
- `lib/services/sudoku_service.dart`

状态：

- 数独分 4x4、6x6、9x9。
- 已按用户要求：数独判定逻辑只检查每行、每列不重复且包含 1..N，不再按标准宫格检查。
- 提交按钮触发检查；填满后不自动检查。
- 通过后生成新数独继续挑战。
- 4x4/6x6/9x9 有限时奖励规则。

### 自我挑战

相关文件：

- `lib/screens/self_challenge_screen.dart`
- `lib/services/question_factory.dart`

状态：

- 今日挑战题量已调整为 30 题。
- 今日挑战要匹配当前选择册别难度，避免一年级出现乘除法。
- 今日挑战 BOSS 形象每日从已生成 BOSS 中轮换。

### BOSS 与战斗

相关资源：

- `assets/bosses/`

状态：

- 有大量按学科和章节生成的 BOSS 图片。
- 数学关卡重新整合后，曾出现原始 BOSS 回退问题，已要求从已生成 BOSS 中随机/轮换选择。
- 关卡 BOSS 音乐已取消，采用所属关卡音乐。
- 攻击动画和音效已多轮调整，但用户仍可能继续提出战斗特效细节。

### 宠物与商店

相关文件：

- `lib/widgets/pet_avatar.dart`
- `lib/screens/shop_screen.dart`
- `lib/data/app_data.dart`

资源：

- `assets/pets/fifi.png`
- `assets/pets/fifi_result_happy.png`
- `assets/pets/fifi_result_sad.png`
- `assets/pets/magic_star*.png`
- `assets/pets/magic_moon*.png`
- `assets/pets/magic_flower*.png`
- `assets/pets/cosmetics/*.jpg`

状态：

- 果果与 3 个勋章宠物已有正常、笑脸、哭脸形象。
- 果果和 3 个勋章宠物的装扮图已生成并接入。
- 装扮不共用，每个宠物需分别兑换才能用。
- 商店里宠物预览曾出现底部溢出和预览退回原始形象的问题，已有多轮修复；若用户再反馈，需要重点检查 `shop_screen.dart` 的宠物渲染路径和装扮集合。

### 音频

相关文件：

- `lib/services/audio_service.dart`

资源目录：

- `BGM/`
- `assets/audio_licenses/`

用户指定 BGM 映射：

- 主界面：`MENU`
- 数学：`MACH`
- 语文：`YW`
- 英语：`SD1`
- 数独：`SD`
- 错题秘境：`CT`
- 自我挑战：`TZ`
- BOSS：`BOSS`，后来取消进入关卡 BOSS 音乐
- 商店：`SHOPING`

已知音效需求：

- 主界面第一次进入播放 `littlegirl.WAV`。
- 点击宠物播放 `DJ.WAV`，播放未完成前重复点击不生效。
- 全对结算播放 `RIGHT.WAV`。
- 数独完成播放 `shengli.wav`，音量需要适当降低。

## 5. 题库与内容

主要文件：

- `lib/data/app_data.dart`
- `lib/services/question_factory.dart`
- `assets/worksheets/index.json`
- `assets/worksheets/generated/`

题库方向：

- 年级按实际册别划分：一年级上/下、二年级上/下；三到六年级先占位锁定。
- 数学题库已按人教版一二年级结构多轮校准。
- 用户后续希望继续一起设计关卡题库，不要用重复凑数关卡。
- 语文、英语也已按人教版和主题线进行过调整，但仍可能需要继续细化。
- 文档型试卷练习已经导入，目前使用当前 `WorksheetService` 加载练习册 JSON。

## 6. 验证状态

最近一次验证：

- `dart analyze lib test`：通过，无问题。
- 直连 `emulator-5554`：构建、安装、启动成功。

Flutter 运行中常见 warning：

- shared_preferences_android 使用 Kotlin Gradle Plugin，未来 Flutter 版本可能要求迁移。这是 warning，不影响当前运行。
- Flutter 提示有新版本，不建议当前升级，避免环境重新不稳定。

## 7. 已知风险与注意事项

- Windows PowerShell 直接 `adb exec-out screencap -p > file.png` 会损坏 PNG，截图要用：

```powershell
adb shell screencap -p /sdcard/tmp.png
adb pull /sdcard/tmp.png local.png
```

- 终端输出中文可能显示为乱码，但源文件通常仍是 UTF-8；不要因为 PowerShell 显示乱码就贸然重写整文件。
- 项目目录不是 Git 仓库，若需要差异追踪，只能基于文件时间和当前内容。
- 用户非常在意设计图到应用内的真实还原度。后续做 UI 时，不要只实现功能，要尽量还原卡片、阴影、圆角、颜色、插图、按钮质感。
- 用户现在要求：如果没有主动说明，不用直连模拟器更新测试；也不要默认打包。

## 8. 语文试卷解析规则

规则文档：`tool/worksheet_parsing_rules.md`

后续解析语文试卷时按该文档执行。关键规则：

- 结构标题只放 `sectionTitle`，题干不重复放标题。
- APP 已经连续编号，题干里不要带 `1.`、`2.`、`（1）` 这类小序号。
- “看拼音写词语”按每个词语拆分。
- “形近字组词”遇到图片里这种大括号分组时，一个大括号拆成一道题。
- “动词搭配”和“量词搭配”保持按每个搭配项拆分；可选词放示例卡展示。
- 示例用 `type: "example"` + `answerSource: "display_only"`，只展示不计入练习。
- “照样子写词语/句子”“按课文内容填空”等按原卷自然小题拆，不按每个空拆。

## 9. 下一步可能方向

用户可能继续反馈：

1. 试卷练习页视觉是否继续贴近设计图。
2. 试卷练习滚动、检查状态、题目输入体验。
3. 学习册别页锁定卡片、三到六年级内容规划。
4. 数学、语文、英语题库进一步对标教材。
5. 商店宠物装扮预览和兑换体验。
6. BOSS 战斗动画、攻击音效、宠物/BOSS 表情反馈。

建议后续工作流程：

1. 先复现用户反馈页面。
2. 读对应文件和模型，不做跨模块大重构。
3. UI 修改后跑 `dart analyze lib test`。
4. 仅在用户明确要求时直连测试到 `emulator-5554`。
5. 只有用户明确说“打包”才构建 APK。
