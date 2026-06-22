# 新电脑接手快速指南

更新时间：2026-06-22

## 1. 拉取项目

新电脑首次拉取：

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

## 2. 必读文件

接手后先读：

- `AGENTS.md`
- `PROJECT_CONTEXT_HANDOFF.md`
- `tool\worksheet_format_spec_v1.md`

这些文件记录了项目规则、当前功能状态、试卷 JSON 标准和容易踩坑的地方。

## 3. 环境路径

推荐保持当前路径，避免脚本和命令反复改：

- Flutter：`D:\Program\Flutter\flutter`
- Android SDK：`D:\Android\android-sdk`

临时设置命令：

```powershell
$env:ANDROID_HOME='D:\Android\android-sdk'
$env:ANDROID_SDK_ROOT='D:\Android\android-sdk'
$env:Path='D:\Program\Flutter\flutter\bin;D:\Android\android-sdk\platform-tools;D:\Android\android-sdk\emulator;' + $env:Path
```

## 4. 初始化依赖

```powershell
& 'D:\Program\Flutter\flutter\bin\flutter.bat' pub get
```

## 5. 验证项目

```powershell
& 'D:\Program\Flutter\flutter\bin\flutter.bat' test test\worksheet_models_test.dart test\worksheet_practice_input_test.dart test\study_materials_labels_test.dart test\worksheet_library_labels_test.dart test\leisure_playground_labels_test.dart
```

## 6. 直连模拟器更新

用户明确说“直连更新”后再执行：

```powershell
& 'D:\Program\Flutter\flutter\bin\flutter.bat' run -d emulator-5554 --no-resident
```

## 7. 构建平板 APK

用户明确要求打包时执行：

```powershell
& 'D:\Program\Flutter\flutter\bin\flutter.bat' build apk --release --split-per-abi
```

给真实平板安装这个文件：

```text
build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

## 8. 当前重点提醒

- `assets\worksheets\generated\final_review.json` 是用户经常手动调整的数学卷，尤其 `images` 字段必须保留。
- 考试重点资料已改成图片页，不再使用内置 PDF。
- 找不同新增关卡默认必须 `manualMarked: false`，只有用户手动标记固化后才能改成 `true`。
- 不要主动直连更新或打包，除非用户明确要求。
