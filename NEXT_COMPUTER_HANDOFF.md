# 《智慧小探险家》换电脑继续开发交接说明

更新时间：2026-06-05  
当前 GitHub 仓库：`https://github.com/huidougithub/guoguoApp.git`  
当前分支：`main`  
当前最新提交：`3e9a377 补充换电脑开发交接说明`

## 1. 换电脑第一步

另一台电脑上已经有项目时，先进入项目目录后执行：

```powershell
git pull origin main
```

如果另一台电脑上不是 Git 仓库，而只是解压目录，可以重新克隆：

```powershell
git clone https://github.com/huidougithub/guoguoApp.git
```

## 2. 当前最重要的工作规则

- 用户没有明确说“打包”，不要打包 APK。
- 用户没有明确说“直连测试 / 更新到模拟器 / 测试一下”，不要直连模拟器。
- 默认只做代码、题库、资源调整，并做必要的本地校验。
- 旧的 `flutter test --no-pub` 路线之前不稳定，优先用：

```powershell
dart analyze lib test
```

- 当前项目如果在中文路径下，继续优先用 `subst W:` 临时盘方案，避免 Flutter/Gradle 路径问题。

## 3. 本项目常用环境命令

本机曾使用的初始化方式如下；另一台电脑路径可按实际情况调整：

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

直连测试只有用户明确要求时才执行：

```powershell
& 'W:\.tools\flutter\bin\flutter.bat' run -d emulator-5554 --debug --no-resident
```

## 4. 当前已经完成的主要内容

- 年级/册别选择页已经按“一上、一下、二上、二下、三到六年级占位锁定”改造。
- 主界面、地图、商店、宠物、BOSS、数独、试卷练习等已多轮完善。
- 数学、语文、英语关卡和题库已经做过多次重排。
- 语文试卷练习已接入《语文期末复习冲刺21天》。
- 试卷练习支持手写框预览、点击预览继续手写、家长批改模式、对/错标记。
- 设置页有“家长批改模式”开关，默认关闭；开启后语文试卷底部显示“对 / 错”按钮。
- Day 2 到 Day 21 已按新解析规则重组完成。
- 当前语文试卷入口描述为：`21天 · 557道练习 · 手写练习`。

## 5. 语文试卷解析规则

详细规则文件：

```text
tool/worksheet_parsing_rules.md
```

关键规则：

- 结构标题只放到 `sectionTitle`，不要重复放进题干。
- APP 已经会连续编号，所以题干里不要带 `1.`、`2.`、`（1）` 这类小序号。
- “看拼音写词语”：按每个词语拆分，一组拼音一道题。
- “形近字组词”：如果版式是大括号分组，一个大括号一道题；每题保留上下两个形近字。
- “动词搭配”：按每个搭配项拆分；可选动词放示例卡。
- “量词搭配”：按每个搭配项拆分；可选量词放示例卡。
- “词语搭配”：如果有可选词，也提到示例卡。
- “照样子写词语/句子”：示例单独做示例卡，实际练习按原卷自然小题拆分。
- “按课文内容填空”：按原卷小题或自然段落拆分，不按每个空拆。
- 示例卡使用：

```json
{
  "type": "example",
  "answerSource": "display_only"
}
```

## 6. 关键文件位置

题库与试卷：

```text
assets/worksheets/index.json
assets/worksheets/generated/chinese_review_21.json
tool/worksheet_parsing_rules.md
tool/rebuild_chinese_review_rules.js
tool/fix_chinese_review_option_sections.js
tool/normalize_chinese_review_shape_sections.js
```

试卷练习 UI：

```text
lib/screens/worksheet_practice_screen.dart
lib/models/worksheet_models.dart
lib/services/worksheet_service.dart
```

核心进度/设置：

```text
lib/models/app_models.dart
lib/services/app_store.dart
lib/screens/stats_settings_screen.dart
```

题目生成：

```text
lib/services/question_factory.dart
lib/data/app_data.dart
```

宠物/商店/素材：

```text
lib/widgets/pet_avatar.dart
lib/screens/shop_screen.dart
assets/pets/
assets/pets/cosmetics/
assets/bosses/
```

音频：

```text
lib/services/audio_service.dart
BGM/
android/app/src/main/res/raw/
```

## 7. Git 注意事项

- 当前项目根目录已经是 Git 仓库，远端为 `origin`。
- 已排除不该上传的内容：`build/`、`dist/`、`tmp/`、临时截图、日志、zip 包等。
- 不要把 `guoguo_forward.zip` 这种大备份包提交到仓库。
- 之前为了接上另一台电脑创建的远端历史，本机采用过 partial fetch；现在已经成功推送到 `main`。

## 8. 已知风险和注意点

- 终端里中文可能显示成乱码，但文件本身通常仍是 UTF-8；不要因为 PowerShell 显示乱码就重写整份中文文件。
- 如果用 Node/PowerShell 写中文 JSON，注意 PowerShell 标准输入可能把中文变成问号；必要时使用 UTF-8 文件或 Unicode 转义。
- Android/Flutter 构建里会出现 Kotlin Gradle Plugin 的未来兼容 warning，目前不影响运行。
- 另一台电脑如果 Flutter/Android 环境路径不同，先修环境变量和 `android/local.properties`。

## 9. 推荐继续工作方式

1. 先 `git pull origin main`。
2. 阅读本文件和 `PROJECT_CONTEXT_HANDOFF.md`。
3. 如果是题库继续调整，先阅读 `tool/worksheet_parsing_rules.md`。
4. 改完后优先跑 `dart analyze lib test`。
5. 只有用户明确要求时，才直连模拟器或打包 APK。
