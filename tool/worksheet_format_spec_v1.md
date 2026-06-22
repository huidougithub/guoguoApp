# 《智慧小探险家》题库格式规范 v1.9

> 适用范围：所有 `assets/worksheets/generated/*.json` 试卷文件  
> 版本：v1.9（2026-06-20）
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
| `images` | `array<string>` | ❌ | 配图资源路径数组。支持外部文件路径（`assets/...`）或 base64 编码字符串（见 3.10） |
| `options` | `array<string>` | ❌ | 选择题选项列表。有此字段时该题为 **选择题**（见 3.5） |
| `inputTypes` | `array<string>` | ❌ | `/r` 填空输入类型数组。缺省、缺少某项或该项为空字符串 `""` 时均按 `number` 处理（见 3.4.1） |
| `multiSelect` | `bool` | ❌ | 多选标记。`true` 表示该选择题可多选，默认 `false`（单选） |
| `left` | `array<string>` | ❌ | 配对连线题左列。与 `right` 同时存在时该题为 **配对题** |
| `right` | `array<string>` | ❌ | 配对连线题右列。与 `left` 同时存在时该题为 **配对题** |
| `isCompare` | `bool` | ❌ | 比较大小题标记。`true` 时该题为 **比较符号题**（见 3.7），默认 `false` |
| `compact` | `bool` | ❌ | 紧凑布局标记。`true` 时该题与相邻同节 `compact` 题合并为紧凑块（见 3.9），默认 `false` |
| `visual` | `object` | ❌ | 竖式计算题数据。有此字段时该题为 **竖式计算题**（见 3.10），默认 `null` |

### 3.1 type 取值表

| 取值 | 含义 | 代码行为 |
|------|------|---------|
| `chinese` | 语文题 | 手写框模式 |
| `math` | 数学题 | 单 blank 时手写框/数字键盘；多 blank 时内联数字小框（见 3.8） |
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
| 单选选择题（`options`） | 正确选项的**单个索引** | `answers: ["1"]` 表示选项 B（索引 1）正确 |
| 多选选择题（`options` + `multiSelect: true`） | 正确选项的**多个索引**数组 | `answers: ["0", "2", "4"]` 表示索引 0、2、4 都正确 |
| 配对题（`left`/`right`） | 与 `left` 一一对应的 `right` 索引 | `answers: ["0", "1", "2", "3"]` 表示 left[i] 连到 right[answers[i]] |
| 无答案 | 空数组 `[]` | 配合 `answerSource: "manual_required"` |

### 3.4 prompt 中的特殊标记

| 标记 | 含义 | 示例 |
|------|------|------|
| `/r` | 填空位置 | `春风（chuī）/r` → 显示一个手写填空框 |
| `\n` | 换行 | 自然换行，用于多行题目排版 |

**`/r` 位置决定渲染方式**：
- `/r` 在 `prompt` **末尾**（如 `34-20=/r`）：文本在左，右侧显示大答题框
- `/r` 在 `prompt` **中间**（如 `（/r）角=40分`）：内联小框，保留括号前后文本
- 多个 `/r`（如 `82角=/r元/r角`）：多个内联小框依次排列
- 无 `/r`：纯文本，右侧显示大答题框（数学题）或手写框（语文题）

**规则**：
- `answers.length` 必须等于 `prompt` 中 `/r` 的数量
- 每个 `answers[i]` 对应第 `i` 个 `/r` 的标准答案
- 无 `/r` 的题目为纯展示或纯文本答题（如数学题 `14-7=`）

### 3.4.1 `/r` 输入类型（`inputTypes`）

当数学题需要孩子自己完整列式，且空位里既有数字又有运算符时，继续使用 `/r` 表示填空位置，并用可选字段 `inputTypes` 标注每个空位的输入类型。

```json
{
  "id": "math_expression_001",
  "type": "math",
  "sectionTitle": "看图列式计算",
  "prompt": "看图列式：/r /r /r = /r",
  "answers": ["8", "+", "5", "13"],
  "inputTypes": ["", "operator", "", ""],
  "answerSource": "auto",
  "images": [],
  "compact": false
}
```

**规则**：
- `inputTypes` 是可选字段；没有该字段时，所有 `/r` 都按 `number` 处理。
- `inputTypes.length` 可以小于 `/r` 数量；未写到的空位按 `number` 处理。
- `inputTypes` 中的空字符串 `""` 等同于 `number`，推荐用于减少重复书写。
- 当前合法取值：
  - `""`：默认数字，等同于 `number`
  - `number`：数字输入，只允许底部数字键
  - `operator`：运算符输入，只允许底部 `+`、`-` 按钮；APP 中渲染为区别于数字框的符号框（更窄、淡黄色底、橙色边框）
  - `compare`：比较符输入，预留给 `>`、`<`、`=`
- `inputTypes` 只描述 `/r` 的输入限制，不改变 `answers` 的对应关系；第 `i` 个 `/r` 仍对应 `answers[i]`。
- 竖式计算题不要用 `inputTypes` 表示过程格，继续使用 `visual.mode: "build"`。

### 3.5 选择题（`options`）

#### 单选

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

#### 多选

```json
{
  "id": "choice_multi_001",
  "type": "choice",
  "prompt": "下列词语中，读轻声的字是（填序号）",
  "options": ["①哥哥", "②眼睛", "③告诉", "④喜欢", "⑤粽子", "⑥故事"],
  "answers": ["0", "1", "2", "3", "4", "5"],
  "multiSelect": true,
  "answerSource": "auto"
}
```

**规则**：
- `options` 至少 2 个元素，通常 4 个
- `answers` 中的值必须是 `options` 的有效索引（`0` 到 `options.length - 1`）
- `type` 建议为 `"choice"`，也可使用学科类型（如 `"chinese"`）
- 单选：用户答案存储为单个索引字符串，如 `"0"`、`"2"`
- 多选：添加 `"multiSelect": true`，用户答案存储为逗号分隔索引，如 `"0,2,4"`
- 多选批改：用户选择的集合与 `answers` 集合完全一致才算对

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

### 3.7 比较大小题（`isCompare`）

```json
{
  "id": "morning_calc_044",
  "type": "math",
  "sectionTitle": "三、在○里填>、<或=",
  "prompt": "31-6 /r 24",
  "answers": [">"],
  "answerSource": "auto",
  "images": [],
  "isCompare": true
}
```

**规则**：
- `isCompare` 必须为 `true`
- `prompt` 中有且仅有 **1** 个 `/r`（替换为比较符号圆圈）
- `answers` 必须为单元素数组，值为 `>`, `<`, `=` 之一
- 渲染时：中间显示 `_AnswerSlot`，点击弹出居中符号选择器（>、<、=）
- 点击符号即选中，点击外部关闭弹窗
- 答案存储键：`questionId`

---

### 3.8 多 blank 数学题（多 `/r` + `type: "math"`）

```json
{
  "id": "morning_calc_037",
  "type": "math",
  "sectionTitle": "二、元角分换算",
  "prompt": "82角=/r元/r角",
  "answers": ["8", "2"],
  "answerSource": "auto",
  "images": []
}
```

**规则**：
- `prompt` 中有 **多个** `/r`（2 个或以上）
- `type` 为 `"math"`（不是 `isCompare`）
- `answers` 数组长度必须等于 `/r` 数量
- 渲染时：每个 `/r` 对应一个 `_InlineDigitBox` 小框（56×36，白色背景）
- 点击小框 → 蓝色边框高亮（选中状态）→ 底部数字键盘输入数字
- 答案存储键：`{questionId}_blank_{index}`（index 从 0 开始）
- **与手写模式的区别**：`manualMode`（非数学试卷）时多 blank 仍使用手写框

---

### 3.9 紧凑布局题（`compact`）

```json
{
  "id": "morning_calc_001",
  "type": "math",
  "sectionTitle": "一、直接写出得数",
  "prompt": "34-20=/r",
  "answers": ["14"],
  "answerSource": "auto",
  "compact": true
}
```

**规则**：
- `compact` 为 `true` 时，该题与**同一 section 内相邻的 `compact: true` 题**合并为一个紧凑块
- 遇到 `compact: false` 或不同 `sectionTitle` 时，紧凑块在此断开
- 渲染时：紧凑块使用 `_CompactQuestionBlock` 组件，内部用 `Wrap` 排列，每行 **3** 题
- 每道小题在紧凑块中显示：小圆形题号 + 题目文本 + 内联答题框（56×36 小框）
- 小题宽度固定 **290px**，左对齐排列，间距 16px
- 点击单个小题 → 选中该题（蓝色边框高亮）→ 底部数字键盘输入
- 小题选中状态和判分状态（对/错）均独立显示
- 与单题卡片的区别：紧凑小题不显示外层卡片圆角大框，题号缩小为 28×28

**适用场景**：
- 大量短计算题（如"直接写出得数"）
- 任何需要节省空间的短题，不限题型

**注意**：
- 选择题、配对题、示例题建议不使用 `compact`
- **带图片的题自动不放入紧凑块**（`images` 非空时忽略 `compact`）
- 竖式计算题支持 `compact`（见 3.10）

---

### 3.10 竖式计算题（`visual`）

```json
{
  "id": "morning_calc_056",
  "type": "math",
  "sectionTitle": "四、用竖式计算",
  "prompt": "15+36=?",
  "answers": ["51"],
  "visual": {
    "mode": "build",
    "op": "+",
    "top": "15",
    "bottom": "36",
    "result": "51"
  },
  "answerSource": "auto",
  "images": [],
  "compact": true
}
```

**规则**：
- `visual.mode` 必须为 `"build"`。这是当前竖式题最新标准；旧版无 `mode` 的竖式展示方案不得再新增使用。
- `visual` 必须包含 `op`（运算符：`+` 或 `-`）、`top`（上数）、`bottom`（下数）、`result`（最终结果），且均为字符串。
- `prompt` 只展示横式题干，格式建议为 `15+36=?`、`52-18=?`。不要再写成笼统的“用竖式计算”。
- `answers` 必须为单元素数组，值与 `visual.result` 保持一致，用于自动批改。
- 渲染时：APP 展示横式题干，并生成空白竖式过程框；`top`、`bottom`、`op`、`result` 都由用户在格子里填写，不直接把过程数字印在竖式框中。
- 竖式格子宽度根据 `top`、`bottom`、`result` 的最大位数自动计算；不足位从左侧留空。
- 默认焦点为 `top` 最左侧十位/最高位格。
- 点击某一格 → 蓝色高亮 → 底部数字键盘输入 → 替换该格内容。
- 运算符格使用底部数字区最左侧的 `+`、`-` 按钮输入，不再弹窗选择。
- 焦点自动跳转顺序：`top` 从左到右 → 运算符格 → `bottom` 从左到右 → `result` 从右到左。以两位数为例：`top十位 → top个位 → 符号 → bottom十位 → bottom个位 → result个位 → result十位`。
- 退格 → 清除当前位
- 答案存储键：`{questionId}_vertical_{slotIndex}`。其中 `slotIndex` 从 0 开始，顺序为 `top` 各位、运算符格、`bottom` 各位、`result` 各位。
- 支持 `compact: true`，放入紧凑块时每行 2-3 题竖式排列

---

### 3.11 图片（`images`）

```json
{
  "id": "final_review_001",
  "type": "math",
  "prompt": "一共有12个球，已经踢进了5个，还需要踢进几个？/r-/r=/r(个)",
  "answers": ["12", "5", "7"],
  "images": [
    "assets/worksheets/images/final_review/q001.png"
  ],
  "compact": false
}
```

**规则**：
- 图片放在**题目文本上方**（符合小学课本习惯：先看图，再读题）
- 支持两种格式：
  - **外部文件路径**：`assets/worksheets/images/...`（推荐，需注册到 `pubspec.yaml`）
  - **base64 编码**：直接嵌入 JSON（不推荐大图使用）
- 图片尺寸：单题卡片中宽度保持题目内容区宽度，高度固定为 112px（`BoxFit.contain`，不拉伸变形）
- **带图片的题自动不放入紧凑块**，即使设置了 `compact: true`
- `pubspec.yaml` 必须注册图片所在目录，包括子目录：
  ```yaml
  assets:
    - assets/worksheets/images/
    - assets/worksheets/images/final_review/
  ```

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
- [ ] 多选题：`multiSelect: true` 时，`answers` 数量不超过 `options` 数量，且每个值都是有效索引
- [ ] 配对题：`left`/`right` 同时存在且非空，`answers` 长度 == `left` 长度，每个值都是有效 `right` 索引
- [ ] 比较题：`isCompare: true` 时，`prompt` 中 `/r` 数量 == 1，`answers` 为 `>` / `<` / `=` 之一
- [ ] 多 blank 数学题：`prompt` 中 `/r` 数量 >= 2，`answers` 长度 == `/r` 数量，`type` 为 `"math"`，不是 `isCompare`
- [ ] `inputTypes`：可缺省；如存在，长度不得超过 `/r` 数量；每项只能是空字符串、`number`、`operator`、`compare`
- [ ] 竖式计算题：`visual.mode == "build"`，`visual` 包含 `op`、`top`、`bottom`、`result`，且均为字符串；`answers` 为单元素数组且等于 `visual.result`；`prompt` 为横式题干（如 `15+36=?`）
- [ ] 紧凑布局题：`compact: true` 时，建议不与 `options`、`left`/`right` 混用；带图题自动不紧凑
- [ ] 图片路径：`assets/` 开头的外部路径必须在 `pubspec.yaml` 中注册对应目录
- [ ] 无 `answer`、`displayPrompt`、`blanks`、`segments` 等废弃字段
- [ ] JSON 格式合法，UTF-8 编码

---

## 6. 版本历史

| 版本 | 日期 | 变更内容 |
|------|------|---------|
| v1.9 | 2026-06-20 | 优化 **带图题图片显示尺寸**：宽度保持题目内容区宽度，高度固定为 112px，避免期末复习等带图题占用过多竖向空间 |
| v1.8 | 2026-06-20 | 优化 **`inputTypes: "operator"` 符号框样式标准**：运算符空位在 APP 中应与数字框视觉区分，使用更窄的符号框、淡黄色底和橙色边框 |
| v1.7 | 2026-06-20 | 新增 **`inputTypes` 输入类型标注**：用于完整列式等 `/r` 空位中数字和运算符混合的数学题；字段可选，缺省、缺项或空字符串均默认 `number`；新增 `operator` 和 `compare` 类型说明及校验规则 |
| v1.6 | 2026-06-20 | 更新 **竖式计算题** 为最新 `visual.mode: "build"` 标准：题干展示横式，竖式过程由用户填写；新增 `result` 字段、逐格答案键、默认焦点、符号按钮输入和自动跳转顺序说明；废止新增旧版无 `mode` 竖式方案 |
| v1.5 | 2026-06-18 | 新增 **竖式计算题**（`visual`）规范、**图片布局**规范（`images` 放文本上方，支持外部路径和 base64），更新 `/r` 位置渲染规则、紧凑块排除带图题逻辑、校验清单和渲染对照表 |
| v1.4 | 2026-06-18 | 新增 **紧凑布局题**（`compact: true`）规范，支持多题合并为紧凑块、每行3题、左对齐排列，更新字段表和校验清单 |
| v1.3 | 2026-06-18 | 新增 **比较大小题**（`isCompare: true`）和 **多 blank 数学题**（多 `/r` + `type: "math"`）两种题型规范，更新 type 取值表和校验清单 |
| v1.2 | 2026-06-17 | 新增 **多选题** 模式：`multiSelect: true`，支持多选批改、UI 多选切换、导入校验、格式规范 |
| v1.1 | 2026-06-13 | 新增 **选择题**（`options` + `type: "choice"`）和 **配对连线题**（`left`/`right`）两种题型规范，补充 `answers` 用法表 |
| v1.0 | 2026-06-11 | 初始版本。统一 type 为 5 种，废弃 `answer`/`displayPrompt`/`blanks`/`segments`，采用 `/r` + `answers` 数组方案 |

---

## 7. 渲染对照表

| 条件 | 渲染组件 | 布局方式 | 输入方式 |
|------|---------|---------|---------|
| `visual.mode == "build"` | `_BuildVerticalCalculation` / `_CompactVerticalCalculation` | 单题卡片或紧凑块；题干为横式，竖式过程为空白格 | 逐格输入；数字用数字键盘，运算符用底部 `+` / `-` 按钮 |
| `compact: true`（且无图、无 visual） | `_CompactQuestionBlock` | 紧凑块，每行3题，左对齐 | 视具体题型 |
| `type=match` | `_MatchQuestionWidget` | 单题卡片 | 拖拽连线 |
| `type=choice` | `_ChoiceQuestionWidget` | 单题卡片 | 点击选项 |
| `blankCount > 1` | `_buildBlankMarkersInline` + `_InlineDigitBox` | 单题卡片或紧凑块 | 数字键盘 |
| `blankCount == 1 && isCompare` | `_AnswerSlot` + 居中弹窗 | 单题卡片 | 符号选择器 |
| `blankCount == 1 && !isCompare` | 左侧文本 + 右侧 `_AnswerSlot` | 单题卡片或紧凑块 | 数字键盘 |
| `blankCount == 0` | 纯文本 | 单题卡片 | - |

> **blankCount** = `prompt` 中 `/r` 的数量

> **紧凑块内的小题**：同样根据上述规则判断展示方式，只是外层容器改为紧凑布局

> **图片位置**：所有带 `images` 的题目，图片显示在**文本上方**
