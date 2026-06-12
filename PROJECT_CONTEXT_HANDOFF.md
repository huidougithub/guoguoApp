# 《智慧小探险家》项目上下文交接摘要

更新时间：2026-06-12
项目路径：`E:\Program Files\果果向前冲\guoguo_forward`
Git 仓库：已初始化，远程 `origin/main`

## 1. 项目目标

这是一个 Flutter 安卓平板横屏优先的离线学习 APP，名称为《智慧小探险家》。核心闭环：

- 首次选择学习册别/年级与宠物。
- 主界面进入数学岛、语文岛、英语岛、数独、错题秘境、自我挑战、魔法商店、试卷练习。
- 答题关卡结合宠物与 BOSS 对战、奖励、错题本、宠物养成、装扮兑换。
- 本地存储使用 `SharedPreferences`，不联网、不登录、不广告、不排行榜。
- **重要**：默认不打包 APK、不直连更新；必须等待用户明确指令（如"打包""直连更新"）后才执行。

## 2. 用户偏好与约束

- 用户希望界面尽量接近确认过的设计图，而不是普通 Material 卡片。
- 视觉风格：可爱、卡通、暖色、纸张质感、圆角、柔和阴影、按钮有质感。
- 允许删除明确废弃文件，但不批量删除构建目录，除非单独确认。
- 下载很慢；超过 100M 或多次失败时让用户手动下载。
- 下载文件安装包放到 `D:\software\AI`。
- 软件安装尽量放到 `D:\Program Files (x86)`，非必要不安装。
- 英语朗读功能用户暂时搁置过，不要贸然大改英语语音逻辑，除非用户重新要求。
- **重要**：后续与用户讨论问题时，直接回答分析即可，必须等待用户明确指令后才执行修复，不得自主主张擅自修改代码。
- **重要**：后续直连更新（构建 APK 并安装到模拟器/设备）也必须等待用户明确指令后才执行。

## 3. 环境与命令

由于中文路径曾导致 Flutter/Gradle 环境问题，项目使用 **junction 方案**构建 release APK：

```powershell
# 创建 junction（只需一次）
cmd /C "mklink /J C:\temp\guoguo_forward ^"E:\Program Files\果果向前冲\guoguo_forward^""

# 构建时从 junction 路径执行
export PATH="$PATH:/c/Windows/System32/WindowsPowerShell/v1.0"
cd C:/temp/guoguo_forward
E:\flutter_sdk_run\bin\flutter.bat build apk --release
```

常用环境：

```powershell
$env:ANDROID_HOME='D:\Android\android-sdk'
$env:ANDROID_SDK_ROOT='D:\Android\android-sdk'
$env:JAVA_HOME='D:\Program Files\Android\Android Studio\jbr'
$env:DART_SUPPRESS_ANALYTICS='true'
$env:FLUTTER_SUPPRESS_ANALYTICS='true'
```

静态检查：

```powershell
E:\flutter_sdk_run\bin\cache\dart-sdk\bin\dart.exe analyze lib test
```

安装 APK：

```powershell
D:\Android\android-sdk\platform-tools\adb.exe install -r C:\temp\guoguo_forward\build\app\outputs\flutter-apk\app-release.apk
```

已知：`flutter test --no-pub` 之前不稳定，后续优先用 `dart analyze lib test`；直连测试只在用户明确要求时执行。

## 4. 最近已完成的重要改动

### 试卷格式 v1.0 标准化（2026-06-12）

相关文件：`tool/worksheet_format_spec_v1.md`、`lib/services/worksheet_service.dart`、`assets/worksheets/generated/` 全部试卷

已完成：

- **批量转换**：全部 2004 题的 `answer` 单字符串 → `answers` 数组。
- **清理死字段**：删除 1594 处 `displayPrompt` 废弃字段。
- **简化 type**：统一为 `chinese`/`math`/`english`/`example`/`display_only` 5 种。
- **重写导入校验**：`worksheet_service.dart` 严格 v1.0 校验，不兼容旧格式，错误直接报错并列出每处违规位置。
- **格式规范文档**：`tool/worksheet_format_spec_v1.md` 定义了完整的 v1.0 JSON 格式规范。

### 导入试卷功能修复（2026-06-12）

文件：`lib/screens/worksheet_library_screen.dart`

- **修复导入闪退**：去掉 `AnimatedSwitcher`，`setState` 改用 `addPostFrameCallback` 避免 Build 阶段触发 setState。
- **添加删除功能**：已导入试卷卡片右上角有删除按钮，确认后清除 `WorksheetService` 中对应数据和进度。
- **年级筛选修复**：`_matchesSelectedGrade` 中无法识别年级的试卷（如 `grade: "测试"`）默认在所有年级下显示。

### Match 配对连线题型（2026-06-12）

相关文件：`lib/screens/worksheet_practice_screen.dart`、`lib/models/worksheet_models.dart`、`lib/services/worksheet_service.dart`

已实现：

- **数据模型**：`WorksheetQuestion` 新增 `leftItems`/`rightItems` 字段，由 JSON 中的 `left`/`right` 数组解析。`isMatch` = 两者均非空。
- **UI 组件**：`_MatchQuestionWidget` 左右两列卡片，点击左项高亮（黄色边框），点击右项完成配对，中间用 **贝塞尔曲线** 画绿色连线；再次点击已配对左项取消配对；选中未配对左项时显示蓝色虚线提示。
- **用户答案格式**：JSON 字符串 `{"0":"2","1":"0"}`，key 为左项索引，value 为右项索引。
- **批改逻辑**：`_checkDay` 中新增 match 分支，逐对校验 `answers` 数组索引，全部配对正确才算对。
- **导入校验**：校验 `left`/`right`/`answers` 长度一致，每个答案值都是有效的 right 索引。
- **测试数据**：`assets/worksheets/test_match_pairing.json` 包含 5 对词语配对（美丽的-夏夜等），`grade: "一年级下册"`。

### 学习册别页面

文件：`lib/screens/grade_selection_screen.dart`

状态：

- 已重做为接近用户确认设计图的页面。
- 12 张册别卡片同屏展示。
- 一年级上/下、二年级上/下可点击；三到六年级上/下锁定，后续再完善内容。
- 使用浅米色背景、菲菲宠物图、标题、彩色圆形册别徽章、科目小标签、开始学习/待开放胶囊按钮。
- 已修复之前卡片底部 `BOTTOM OVERFLOWED BY 22 PIXELS`。

### 统计与设置页

文件：`lib/screens/stats_settings_screen.dart`

状态：

- 安全设置区域新增“重选宠物”功能，点击后跳转到宠物选择界面，选择后返回设置页，当前宠物名称同步更新。

### 宠物名称

文件：`lib/data/app_data.dart`、`lib/screens/home_screen.dart`

状态：

- 宠物 `id: 'fifi'` 的名称从“果果”改回为“菲菲”，主界面标题同步改为“菲菲加油！”。

### 试卷练习页面（内联手写框 — 已确认方案）

文件：`lib/screens/worksheet_practice_screen.dart`、`lib/models/worksheet_models.dart`

状态：

- 课文填空题（text_fill 类型）支持内联手写框模式，效果已确认，方案已定。
  - 数据模型 `WorksheetQuestion` 新增 `blanks` 字段（`List<WorksheetBlank>`），每个 blank 包含 `prefix`（框前文本）和 `answer`（答案）。
  - 题目渲染时，如果 `blanks` 不为空，用 `RichText` + `WidgetSpan` 在题目文本中嵌入 `_InlineHandwritingBox` 小手写框。
  - **内联框尺寸**：统一为 **56×36**，已填写和未填写尺寸一致。
  - **内联框外观**：统一带田字格网格线（横线+竖线），已填写时额外显示手写笔画缩略图，未填写时只显示网格。
  - **手写弹窗**：顶部只显示当前填空对应的 `prefix` 文本（如“春风（chuī）”），去掉原有图标、标题和提示；底部保留撤销/清空/取消/保存按钮。
  - **答案存储**：每个 blank 的答案独立存储，key 格式为 `${questionId}_blank_${index}`。
  - 目前仅 `assets/worksheets/generated/text_fill_8_units.json` Day1 第一题启用了 `blanks` 数组作为试验。后续如需批量启用，需给每道 text_fill 题目添加 `blanks` 数组。

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
- `assets/worksheets/test_match_pairing.json`（测试 match 题型）

题库方向：

- 年级按实际册别划分：一年级上/下、二年级上/下；三到六年级先占位锁定。
- 数学题库已按人教版一二年级结构多轮校准。
- 用户后续希望继续一起设计关卡题库，不要用重复凑数关卡。
- 语文、英语也已按人教版和主题线进行过调整，但仍可能需要继续细化。
- 文档型试卷练习已经导入，目前使用当前 `WorksheetService` 加载练习册 JSON。
- **v1.0 格式规范**：`tool/worksheet_format_spec_v1.md` 定义了完整的试卷 JSON 格式，包括 `type`、`answers`、`left`/`right` 等字段规范。

## 6. 验证状态

最近一次验证（2026-06-12）：

- `dart analyze lib/screens/worksheet_practice_screen.dart lib/services/worksheet_service.dart lib/models/worksheet_models.dart`：通过，我引入的代码无错误。
- 构建 release APK：通过（132MB），使用 `C:/temp/guoguo_forward` junction 路径构建。
- 安装到设备：`adb install` 成功。

Flutter 运行中常见 warning：

- shared_preferences_android 使用 Kotlin Gradle Plugin，未来 Flutter 版本可能要求迁移。这是 warning，不影响当前运行。
- Flutter 提示有新版本，不建议当前升级，避免环境重新不稳定。

## 7. 已知风险与注意事项

- **中文路径问题**：项目目录含中文路径，Flutter AOT 编译器在中文路径下会报错（`Unable to read file: app.dill`）。**必须使用 `C:/temp/guoguo_forward` junction 路径构建 release APK**。debug 模式直连运行不受此影响。
- Windows PowerShell 直接 `adb exec-out screencap -p > file.png` 会损坏 PNG，截图要用：

```powershell
adb shell screencap -p /sdcard/tmp.png
adb pull /sdcard/tmp.png local.png
```

- 终端输出中文可能显示为乱码，但源文件通常仍是 UTF-8；不要因为 PowerShell 显示乱码就贸然重写整文件。
- 用户非常在意设计图到应用内的真实还原度。后续做 UI 时，不要只实现功能，要尽量还原卡片、阴影、圆角、颜色、插图、按钮质感。
- **项目现在已经是 Git 仓库**，请使用 `git status` 追踪变更，提交前运行 `dart analyze` 检查。

## 8. 语文试卷解析规则

规则文档：`tool/worksheet_parsing_rules.md`、`tool/worksheet_format_spec_v1.md`

后续解析语文试卷时按该文档执行。关键规则：

- 结构标题只放 `sectionTitle`，题干不重复放标题。
- APP 已经连续编号，题干里不要带 `1.`、`2.`、`（1）` 这类小序号。
- “看拼音写词语”按每个词语拆分。
- “形近字组词”遇到图片里这种大括号分组时，一个大括号拆成一道题。
- “动词搭配”和“量词搭配”保持按每个搭配项拆分；可选词放示例卡展示。
- 示例用 `type: "example"` + `answerSource: "display_only"`，只展示不计入练习。
- “照样子写词语/句子”“按课文内容填空”等按原卷自然小题拆，不按每个空拆。
- **v1.0 格式**：`answer` 字段已废弃，全部使用 `answers` 数组；`displayPrompt` 已废弃；`type` 只能为 5 种合法值；填空使用 `/r` 标记。

## 9. 下一步可能方向

用户可能继续反馈：

1. 试卷练习页视觉是否继续贴近设计图。
2. 试卷练习滚动、检查状态、题目输入体验。
3. 学习册别页锁定卡片、三到六年级内容规划。
4. 数学、语文、英语题库进一步对标教材。
5. 商店宠物装扮预览和兑换体验。
6. BOSS 战斗动画、攻击音效、宠物/BOSS 表情反馈。
7. Match 配对连线题型的视觉优化（连线动画、曲线样式、卡片布局等）。
8. 更多新题型设计（如拖拽排序、判断对错等）。

建议后续工作流程：

1. 先复现用户反馈页面。
2. 读对应文件和模型，不做跨模块大重构。
3. UI 修改后跑 `dart analyze lib test`。
4. 仅在用户明确要求时直连测试到 `emulator-5554`。
5. 只有用户明确说“打包”或“直连更新”才构建 APK；构建时使用 `C:/temp/guoguo_forward` junction 路径。