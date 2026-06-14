# 换电脑继续开发快速交接

更新时间：2026-06-14  
仓库：`https://github.com/huidougithub/guoguoApp.git`  
项目目录：`D:\ProJects\guoguo\guoguo_forward`

## 新电脑第一步

已有仓库时：

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
```

## 当前固定规则

- 用户没说“直连更新”，不要安装到模拟器。
- 用户没说“打包”，不要构建 APK。
- Android SDK 使用：`D:\Android\android-sdk`。
- 项目目录只放项目相关文件。
- 通用软件放 `D:\Program`。

## 常用命令

```powershell
$env:ANDROID_HOME='D:\Android\android-sdk'
$env:ANDROID_SDK_ROOT='D:\Android\android-sdk'
$env:Path='D:\Android\android-sdk\platform-tools;D:\Android\android-sdk\emulator;' + $env:Path
dart analyze lib test
flutter run -d emulator-5554 --no-resident
flutter build apk --release
```

## 当前模拟器

- AVD：`Guoguo_Tablet_Lite`
- 常见设备号：`emulator-5554`
- 平板验证尺寸：`1280 x 800`

## 当前最新重点

- 休闲乐园已有：找不同、记忆翻牌、五子棋。
- 找不同已有 20 关 AI 成品图，每关左右两张 JPG。
- 找不同素材目录：`assets/leisure/spot/ai/`
- 找不同素材总大小约 `6.04 MB`，没有 PNG 残留。
- 记忆翻牌会从项目图片素材池随机抽 8 对。
- 五子棋棋盘已放大并使用自绘棋子。
- 最近 release APK 路径：`build\app\outputs\flutter-apk\app-release.apk`

## 验证基线

最近通过：

```powershell
dart analyze lib test
flutter build apk --release
```

如果继续开发，优先保持这个基线。
