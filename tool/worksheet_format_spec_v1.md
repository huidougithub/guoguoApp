# 《智慧小探险家》题库格式规范 v1.1

> 适用范围：所有 `assets/worksheets/generated/*.json` 试卷文件  
> 版本：v1.1（2026-06-13）  
> 后续调整时，请递增版本号并同步更新此文档。

---

## 1. 顶层结构（WorksheetSet）

```json
{
  "id": "text_fill_8_units",
  "title": "课文拼写",
  "subject": "chinese",
  "grade": "一年级下册",
  "description": "...",
  "sourceFile": "课文拼写.pdf",
  "days": []
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | `string` | ✅ | 试卷唯一标识，英文+下划线，如 `text_fill_8_units` |
| `title` | `string` | ✅ | 试卷名称，显示在试卷列表中 |
| `subject` | `string` | ✅ | 学科：`chinese` / `math` / `english` |
| `grade` | `string` | ✅ | 年级，如 `一年级下册` |
| `description` | `string` | ✅ | 试卷描述，显示在试卷详情页 |
| `sourceFile` | `string` | ❌ | 原始文件来源，仅存档用 |
| `days` | `array` | ✅ | 按天/单元组织的题目数组 |

---

## 2. 天/单元结构（WorksheetDay）

```json
{
  "day": 1,
  "title": "第一单元",
  "questions": []
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `day` | `int` | ✅ | 第几天/第几单元，从 1 开始递增 |
| `title` | `string` | ✅ | 本单元标题，如 `第一单元`、`春夏秋冬` |
| `questions` | `array` | ✅ | 题目数组 |

---

## 3. 题目结构（WorksheetQuestion）

```json
{
  "id": "text_fill_u01_q001",
  "type": "chinese",
  "sectionTitle": "课文填空",
  "prompt": "春风（chuī）/r，夏（yǔ）/r落，（qiū）/r霜降。",
  "answers": ["吹", "雨", "秋"],
  "answerSource": "textbook",
  "images": []
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | `string` | ✅ | **同一试卷内必须唯一**。建议格式：`{试卷id}_u{单元号}_q{序号}` |
| `type` | `string` | ✅ | 题目大类，见下方 **type 取值表** |
| `sectionTitle` | `string` | ❌ | 大题分类标题。相同 `sectionTitle` 的题目在 APP 中归为一组显示 |
| `prompt` | `string` | ✅ | 题目正文。用 `/r` 标记填空位置，用 `\n` 表示换行 |
| `answers` | `array<string>` | ✅ | 标准答案数组。含义根据题型不同，见下方 **answers 用法表** |
| `answerSource` | `string` | ✅ | 答案来源，见下方 **answerSource 取值表** |
| `images` | `array<string>` | ❌ | 配图资源路径数组（当前未启用，预留） |
| `options` | `array<string>` | ❌ | 选择题选项列表。有此字段时该题为 **选择题**（见下方） |
| `left` | `array<string>` | ❌ | 配对连线题左列。与 `right` 同时存在时该题为 **配对题** |
| `right` | `array<string>` | ❌ | 配对连线题右列。与 `left` 同时存在时该题为 **配对题** |

### 3.1 type 取值表

| 取值 | 含义 | 代码行为 |
|------|------|---------|
| `chinese` | 语文题 | 手写框模式 |
| `math` | 数学题 | 手写框/数字键盘模式 |
| `english` | 英语题 | 手写框模式（预留） |
| `choice` | 选择题 | 点击选项卡片模式，自动批改 |
| `example` | 示例/例题 | 只展示，不计入练习进度，显示"看例子"标签 |
| `display_only` | 纯展示内容 | 只展示，不计入练习进度 |

### 3.2 answerSource 取值表

| 取值 | 含义 | 代码行为 |
|------|------|---------|
| `auto` | 有标准答案，可自动批改 | 点击"检查"时自动比对 |
| `textbook` | 教材标准答案（同 auto） | 同上 |
| `manual_required` | 无标准答案，需手动批改 | 点击"检查"时标记为"已练习" |
| `display_only` | 只展示不练习 | 同 `example`，不计入进度 |

### 3.3 answers 用法表

`answers` 的含义根据题目类型不同：

| 题型 | `answers` 含义 | 示例 |
|------|---------------|------|
| 填空题（含 `/r`） | 与 `/r` 一一对应的标准答案 | `answers: ["吹", "雨", "秋"]` 对应 3 个 `/r` |
| 选择题（`options`） | 正确选项的**索引**数组 | `answers: ["1"]` 表示选项 B（索引 1）正确 |
| 配对题（`left`/`right`） | 与 `left` 一一对应的 `right` 索引 | `answers: ["0", "1", "2", "3"]` 表示 left[i] 连到 right[answers[i]] |
| 无答案 | 空数组 `[]` | 配合 `answerSource: "manual_required"` |

### 3.4 prompt 中的特殊标记

| 标记 | 含义 | 示例 |
|------|------|------|
| `/r` | 填空位置 | `春风（chuī）/r` → 显示一个手写填空框 |
| `\n` | 换行 | 自然换行，用于多行题目排版 |

**规则**：
- `answers.length` 必须等于 `prompt` 中 `/r` 的数量
- 每个 `answers[i]` 对应第 `i` 个 `/r` 的标准答案
- 无 `/r` 的题目为纯展示或纯文本答题（如数学题 `14-7=`）

### 3.5 选择题（`options`）

```json
{
  "id": "choice_001",
  "type": "choice",
  "prompt": "下面音序排列正确的是哪一项？",
  "options": ["A. A C B D F E", "B. J K L M N", "C. O R S T P Q", "D. E G H J I"],
  "answers": ["1"],
  "answerSource": "auto"
}
```

**规则**：
- `options` 至少 2 个元素，通常 4 个
- `answers` 中的值必须是 `options` 的有效索引（`0` 到 `options.length - 1`）
- `type` 建议为 `"choice"`，也可使用学科类型（如 `"chinese"`）
- 用户答案存储为单个索引字符串，如 `"0"`、`"2"`

### 3.6 配对连线题（`left`/`right`）

```json
{
  "id": "match_001",
  "type": "chinese",
  "prompt": "读一读，连一连。",
  "left": ["美丽的", "潮湿的", "透明的", "青青的", "亮晶晶的"],
  "right": ["夏夜", "空气", "翅膀", "草地", "灯笼"],
  "answers": ["0", "1", "2", "3", "4"],
  "answerSource": "auto"
}
```

**规则**：
- `left` 和 `right` 必须同时存在且非空
- `answers` 长度必须等于 `left` 长度
- `answers[i]` 是 `right` 的索引，表示 `left[i]` 应连到 `right[answers[i]]`
- 用户答案存储为 JSON 字符串：`{"0":"2","1":"0"}`，key 为 left 索引，value 为 right 索引

---

## 4. 已废弃字段（不得再使用）

| 字段 | 废弃版本 | 替代方案 |
|------|---------|---------|
| `answer` | v1.0 | `answers` 数组 |
| `displayPrompt` | v1.0 | 统一使用 `prompt` |
| `blanks` | v1.0 | 统一使用 `/r` 标记 + `answers` 数组 |
| `segments` | v1.0 | 统一使用 `/r` 标记 |

---

## 5. 校验清单

新增或修改试卷后，请逐项检查：

- [ ] 所有 `id` 在同一试卷内不重复
- [ ] `type` 取值在规范表内
- [ ] `answerSource` 取值在规范表内
- [ ] `prompt` 中的 `/r` 数量 == `answers.length`（填空题）
- [ ] 选择题：`options` 至少 2 个，`answers` 中每个值都是有效选项索引
- [ ] 配对题：`left`/`right` 同时存在且非空，`answers` 长度 == `left` 长度，每个值都是有效 `right` 索引
- [ ] 无 `answer`、`displayPrompt`、`blanks`、`segments` 等废弃字段
- [ ] JSON 格式合法，UTF-8 编码

---

## 6. 版本历史

| 版本 | 日期 | 变更内容 |
|------|------|---------|
| v1.1 | 2026-06-13 | 新增 **选择题**（`options` + `type: "choice"`）和 **配对连线题**（`left`/`right`）两种题型规范，补充 `answers` 用法表 |
| v1.0 | 2026-06-11 | 初始版本。统一 type 为 5 种，废弃 `answer`/`displayPrompt`/`blanks`/`segments`，采用 `/r` + `answers` 数组方案 |
