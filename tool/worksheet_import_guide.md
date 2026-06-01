# Word 试卷导入流程

## 1. 准备 Word

先把 PDF 转成 Word，并尽量保留这些结构：

- 标题里包含 `Day1`、`Day2` 这样的天数标记。
- 计算题放在“一、直接写出得数”下面。
- 括号填空放在“二、在括号中填入合适的数”下面。
- 应用题放在“三、应用题”下面。

普通计算题和括号填空会自动算答案。应用题建议用单独答案文件补充。

## 2. 准备应用题答案文件

答案文件放在：

```text
assets/worksheets/answers/
```

格式示例：

```json
{
  "day01_q19": "7",
  "day02_q19": "6"
}
```

题号可以先不填，跑一次导入后查看生成的 JSON，再把应用题对应的 `id` 补进答案文件。

## 3. 导入并登记到 App

示例命令：

```powershell
python tool\import_worksheet_docx.py "C:\Users\Administrator\Downloads\xxx.docx" `
  --out assets\worksheets\generated\xxx.json `
  --id xxx `
  --title "练习册标题" `
  --subject math `
  --answers assets\worksheets\answers\xxx_answers.json `
  --update-catalog `
  --catalog-subject "数学" `
  --grade "一年级上" `
  --description "练习册说明"
```

导入后会自动更新：

```text
assets/worksheets/index.json
```

App 的“每日练习”列表会读取这个清单。

## 4. 校验

导入后建议跑：

```powershell
flutter analyze
flutter test
```
