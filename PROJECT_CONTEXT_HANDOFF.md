# 果果向前冲项目交接文档

更新时间：2026-06-26

本文件是项目唯一交接入口。后续换电脑、恢复上下文、继续开发时，先读本文件，再读 `AGENTS.md` 和具体模块规范文档。

## 1. 项目与仓库

- 当前本机项目目录：`E:\Program Files\果果向前冲\guoguo_forward`
- 当前工作区根目录：`E:\Program Files\果果向前冲`
- Git 仓库：`https://github.com/huidougithub/guoguoApp.git`
- 主分支：`main`
- 技术栈：Flutter + Android

历史上另一台电脑可能使用过：

- `D:\ProJects\guoguo\guoguo_forward`
- `E:\Program Files\果果向前冲\guoguoApp-main`

以后以实际打开的项目目录为准，不要假定路径固定。

## 2. 必读文件

接手项目后按顺序阅读：

1. `AGENTS.md`：项目执行规则、找不同图片生成硬标准。
2. `PROJECT_CONTEXT_HANDOFF.md`：当前交接文档。
3. `tool\worksheet_format_spec_v1.md`：试卷题库 JSON 标准格式，当前已到 v1.10。
4. `tool\worksheet_parsing_rules.md`：语文试卷解析和拆题规则。

## 3. 当前协作规则

- 用户没有明确要求时，不构建正式 APK。
- 用户说“打包”时，才构建 APK。
- 用户说“直连更新”“直连测试”“更新到模拟器”时，使用 Flutter 直连安装到模拟器。
- 当前会话里用户偏好是：任务完成后默认直连更新，除非明确说“不更新 / 先不更新 / 不用直连”。如果新会话里不确定，以用户当场指令为准。
- 不要回滚用户手动修改。
- 不要批量删除文件；清理大文件或构建产物前先确认。
- 下载安装包或超过 100M 的文件前，先让用户确认或让用户自行下载。
- 下载的安装包放到 `D:\software\AI`。
- 文件安装如非必要，尽量安装到 `D:\Program Files (x86)`。

## 4. 当前本机环境

当前这台机器推荐使用 `W:` 映射规避中文路径问题：

```powershell
if (-not (Get-PSDrive -Name W -ErrorAction SilentlyContinue)) {
  subst W: 'E:\Program Files\果果向前冲'
}
```

常用环境：

- Flutter：`W:\.tools\flutter\bin\flutter.bat`
- Dart：`W:\.tools\flutter\bin\cache\dart-sdk\bin\dart.exe`
- Java：`E:\Program Files\果果向前冲\.tools\jdk17`
- Android SDK：`D:\Android\android-sdk`
- 常用模拟器：`emulator-5554`

每次需要 Flutter 命令时可先执行：

```powershell
if (-not (Get-PSDrive -Name W -ErrorAction SilentlyContinue)) { subst W: 'E:\Program Files\果果向前冲' }
$env:JAVA_HOME='E:\Program Files\果果向前冲\.tools\jdk17'
$env:ANDROID_HOME='D:\Android\android-sdk'
$env:ANDROID_SDK_ROOT='D:\Android\android-sdk'
$env:Path="$env:JAVA_HOME\bin;W:\.tools\flutter\bin\mingit\cmd;D:\Android\android-sdk\platform-tools;D:\Android\android-sdk\emulator;W:\.tools\flutter\bin;" + $env:Path
Set-Location 'W:\guoguo_forward'
```

注意：之前有些 Flutter 环境路径在本机走不通，后续优先使用上面的 `W:` 临时方案，不要反复尝试已知失败路径。

## 5. 换电脑或重新拉取

新电脑首次拉取示例：

```powershell
Set-Location D:\ProJects\guoguo
git clone https://github.com/huidougithub/guoguoApp.git guoguo_forward
Set-Location D:\ProJects\guoguo\guoguo_forward
```

已有项目时更新：

```powershell
Set-Location D:\ProJects\guoguo\guoguo_forward
git pull origin main
```

初始化依赖：

```powershell
& 'D:\Program\Flutter\flutter\bin\flutter.bat' pub get
```

如果新电脑 Flutter/Android 路径不同，先以本机实际路径替换命令，不要照搬旧路径。

## 6. 常用命令

### 当前本机直连更新

```powershell
& 'W:\.tools\flutter\bin\flutter.bat' run -d emulator-5554 --no-pub --no-resident
```

### 当前本机局部测试

```powershell
& 'W:\.tools\flutter\bin\flutter.bat' test --no-pub test\worksheet_models_test.dart test\worksheet_practice_input_test.dart
```

### 当前本机静态检查

```powershell
& 'W:\.tools\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze lib test
```

### 构建 APK

只有用户明确要求打包时才执行。真实平板优先使用 arm64 release：

```powershell
& 'W:\.tools\flutter\bin\flutter.bat' build apk --release --split-per-abi
```

输出文件通常在：

```text
build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

## 7. 当前功能状态

### 主流程

- APP 已包含年级/册别选择、宠物小屋、岛屿学习、试卷练习、错题、数独、自我挑战、魔法商店、休闲乐园等模块。
- 当前年级/册别体系已按上册/下册拆分。
- 休闲乐园入口在主界面靠后位置。

### 试卷练习

- 试卷入口按语文、数学、英语、真题分类展示。
- 试卷列表已改成更密集的列表样式。
- 手动导入试卷和删除按钮只在家长模式开启后显示。
- 数学试卷页使用底部自定义答题板，不使用系统键盘。
- 语文试卷支持手写练习展示、家长批改模式，以及内联下拉选择框。
- 当前重点试卷：
  - `assets\worksheets\generated\chinese_final_7day_comeback.json`
  - `assets\worksheets\generated\chinese_review_21.json`
  - `assets\worksheets\generated\morning_calc_7.json`
  - `assets\worksheets\generated\final_review.json`

### 题库标准

- 最新标准文件：`tool\worksheet_format_spec_v1.md`
- 当前版本：v1.10
- 关键新增标准：
  - `type: "inline_choice"`
  - `blankChoices`
  - `blankChoices` 可以只写一组并被多个 `/r` 共用，也可以写多组与 `/r` 一一对应。
  - `answers.length` 必须等于 `/r` 数量。
  - 每个答案必须存在于对应选项组中。
  - 下拉框未选择和已选择宽度均为 70px，未选择时不显示“选择”占位文字。

### 语文试卷解析规则

- 结构标题只放到 `sectionTitle`，不要放进 `prompt`。
- APP 会自动连续编号，题干不要保留小序号。
- 有示例时使用 `type: "example"` 和 `answerSource: "display_only"`。
- “看拼音写词语”按每个词语拆题。
- “形近字组词”按大括号拆题，一个大括号一题。
- “动词搭配 / 量词搭配”按搭配项拆题，可选词放在示例卡里。
- “按课文内容填空 / 默写片段 / 照样子写句子”按原卷小题或自然段拆题，不按每个空拆。
- “选择读音 / 选字填空 / 近反义词”等短项题，可优先转为 `inline_choice`。

### 数学题型

- 横式填空支持 `inputTypes`。
- `inputTypes: "operator"` 使用底部 `+`、`-` 按钮。
- 竖式计算使用 `visual.mode: "build"`，由用户填写上排、下排、符号位、结果位，并支持焦点自动跳转。
- 数学试卷页已针对平板横屏适配。

### 考试重点

- 内置资料已由 PDF 转为图片页，提高翻页速度。
- 图片目录：`assets\study_materials\chinese_final_review_key_points\`
- 相关代码：
  - `lib\models\study_material_models.dart`
  - `lib\services\study_material_service.dart`
  - `lib\screens\study_materials_screen.dart`

### 休闲乐园

- 已有游戏：找不同、记忆翻牌、五子棋。
- 迷宫小路已去掉。
- 找不同关卡支持手动标记模式。
- 找不同新增 AI 关卡资源目录：`assets\leisure\spot\ai\`
- 找不同图片生成和入库硬标准写在 `AGENTS.md`，后续新增关卡必须遵守。
- 用户手动标记并固化后的坐标，应同步回项目文件，避免重装后丢失。

### 奖励体系

- 已新增钻石道具。
- 一套试卷一次性全做对可获得 1 颗钻石。
- 魔法商店中“钻石兑换”包含现实奖励：10 个币、奶茶一杯、蛋糕一个、零食一份。

## 8. 常见坑

- 试卷 JSON 可能被用户手动修改，修改脚本或重建题库前先确认不会覆盖用户内容。
- 用户手动保存的图片路径、题目、答案、`images` 字段不要覆盖。
- JSON 文件有时会被编辑器保存成 UTF-8 BOM；如果 Flutter/脚本解析失败，可先用 `utf-8-sig` 读入再保存为 UTF-8 no BOM。
- PowerShell 默认输出可能导致中文显示乱码；查看中文文件时先设置：

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()
```

- `build`、`.dart_tool`、`.gradle`、临时截图、APK 输出文件不需要提交。
- 运行 `flutter run` 时出现 Kotlin Gradle Plugin 未来兼容性警告，目前不影响当前构建。

## 9. Git 注意事项

- 提交前先看 `git status --short`。
- 不要把无关构建产物提交。
- 当前项目里可能存在用户手动改动和未跟踪题库文件，不能随意丢弃。
- 需要推送 GitHub 时，确认改动范围后再 commit/push。

