# 果果向前冲项目交接文档

更新时间：2026-06-22

## 项目位置

- 本机项目目录：`D:\ProJects\guoguo\guoguo_forward`
- Git 仓库：`https://github.com/huidougithub/guoguoApp.git`
- 当前主分支：`main`
- 主要技术栈：Flutter + Android

## 本机环境

- Flutter：`D:\Program\Flutter\flutter\bin\flutter.bat`
- Android SDK：`D:\Android\android-sdk`
- 常用模拟器设备：`emulator-5554`
- 真实平板 APK 优先使用：`build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`

常用环境变量临时设置：

```powershell
$env:ANDROID_HOME='D:\Android\android-sdk'
$env:ANDROID_SDK_ROOT='D:\Android\android-sdk'
$env:Path='D:\Program\Flutter\flutter\bin;D:\Android\android-sdk\platform-tools;D:\Android\android-sdk\emulator;' + $env:Path
```

## 协作规则

- 用户说“直连更新”时，使用模拟器直连更新：

```powershell
& 'D:\Program\Flutter\flutter\bin\flutter.bat' run -d emulator-5554 --no-resident
```

- 用户没有主动提出打包时，尽量不要构建 APK。
- 用户要求平板安装包时，构建分 ABI release 包：

```powershell
& 'D:\Program\Flutter\flutter\bin\flutter.bat' build apk --release --split-per-abi
```

- 不要把安装组件、下载软件、临时工具放进项目目录。
- 不要回滚用户手动修改。特别是 `assets\worksheets\generated\final_review.json` 里的 `images` 字段，用户会手动调整，后续更新题目时必须保留。

## 当前功能状态

### 试卷练习

- 试卷入口按语文、数学、英语、真题分类展示。
- 当前导入试卷主要是一年级下册，并按当前年级过滤。
- 手动导入试卷和删除按钮只在家长模式开启后显示。
- 数学试卷页面已经针对真实平板做过适配，紧凑题卡在真实平板上尽量保持每行 3 题。

### 数学题型标准

- 横式填空支持 `inputTypes`，默认空值为数字输入。
- 符号输入支持 `operator` 类型，数字区左侧有 `+`、`-` 按钮。
- 竖式计算支持用户填写上排、下排、符号位、结果位，并支持焦点自动跳转。
- 最新标准写在：`tool\worksheet_format_spec_v1.md`

### 期末复习数学卷

- 数据文件：`assets\worksheets\generated\final_review.json`
- 图片目录：`assets\worksheets\images\final_review\`
- 目前第 2 天到第 4 天已经按新标准整理，并附加对应图片。
- 注意：不要再运行旧的自动图片填充逻辑覆盖用户手动调整的图片参数。

### 早读计算

- 数据文件：`assets\worksheets\generated\morning_calc_7.json`
- 第四大题竖式计算已改造成新交互模式。

### 考试重点

- 新增模块入口在主界面。
- 内置资料已经由 PDF 转成图片页，提高翻页速度。
- 内置图片目录：`assets\study_materials\chinese_final_review_key_points\`
- 相关代码：
  - `lib\models\study_material_models.dart`
  - `lib\services\study_material_service.dart`
  - `lib\screens\study_materials_screen.dart`
  - `android\app\src\main\kotlin\com\guoguo\guoguo_forward\MainActivity.kt`

### 休闲乐园

- 已有游戏：找不同、记忆翻牌、五子棋。
- 迷宫小路已去掉。
- 找不同新增 AI 关卡资源在：`assets\leisure\spot\ai\`
- 找不同生图和入库标准写在 `AGENTS.md`，后续新增关卡必须遵守。

### 奖励体系

- 已新增钻石道具。
- 一套试卷一次性全做对可获得 1 颗钻石。
- 魔法商店中“钻石兑换”包含现实奖励：10 个币、奶茶一杯、蛋糕一个、零食一份。

## 验证命令

常用测试：

```powershell
& 'D:\Program\Flutter\flutter\bin\flutter.bat' test test\worksheet_models_test.dart test\worksheet_practice_input_test.dart test\study_materials_labels_test.dart test\worksheet_library_labels_test.dart test\leisure_playground_labels_test.dart
```

常用静态检查：

```powershell
& 'D:\Program\Flutter\flutter\bin\flutter.bat' analyze lib\models\worksheet_models.dart lib\services\worksheet_service.dart lib\screens\worksheet_practice_screen.dart lib\screens\study_materials_screen.dart lib\services\study_material_service.dart lib\screens\worksheet_library_screen.dart lib\screens\leisure_playground_screen.dart test\worksheet_models_test.dart test\worksheet_practice_input_test.dart test\study_materials_labels_test.dart test\worksheet_library_labels_test.dart test\leisure_playground_labels_test.dart
```

## 交接提醒

- 换电脑后先读 `AGENTS.md`、本文件和 `NEXT_COMPUTER_HANDOFF.md`。
- 项目里有较多图片资源，提交前确认只提交 `assets` 下实际被代码引用的素材。
- `build`、`.dart_tool`、`.gradle`、临时截图、APK 输出文件不需要提交。
- 试卷 JSON 很容易被手动调整，修改脚本前先确认不会覆盖用户保存的字段。
