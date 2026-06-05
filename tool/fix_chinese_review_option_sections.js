const fs = require('fs');
const path = 'assets/worksheets/generated/chinese_review_21.json';
const catalogPath = 'assets/worksheets/index.json';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));

function isDisplayOnly(q) {
  return q.type === 'example' || q.answerSource === 'display_only';
}

function cleanPrompt(raw) {
  return String(raw || '')
    .replace(/^\s*(?:\d+[.．、]|[（(]\d+[）)]|[①②③④⑤⑥⑦⑧⑨⑩])\s*/u, '')
    .replace(/\s+/g, ' ')
    .trim();
}

const optionSections = {
  2: {
    section: '三、量词搭配',
    typeLabel: '可选量词',
    options: '①册 ②部 ③条 ④台 ⑤架 ⑥支 ⑦床 ⑧件',
    bodies: ['一（____）铅笔', '一（____）手机', '一（____）裤子', '一（____）上衣', '一（____）书', '一（____）电视', '一（____）飞机', '一（____）棉被'],
  },
  6: {
    section: '三、动词搭配',
    typeLabel: '可选动词',
    options: '①踢 ②丢 ③吹 ④搭 ⑤跳 ⑥吃 ⑦跑 ⑧拍',
    bodies: ['（____）皮球', '（____）泡泡', '（____）积木', '（____）绳', '（____）毽子', '（____）沙包', '（____）西瓜', '（____）步'],
  },
  9: {
    section: '三、词语搭配',
    typeLabel: '可选动词',
    options: '①吃 ②打 ③掰 ④开 ⑤追 ⑥伸 ⑦摘 ⑧抱',
    bodies: ['（____）哈欠', '（____）早饭', '（____）大会', '（____）玉米', '（____）桃子', '（____）西瓜', '（____）舌头', '（____）小兔'],
  },
  17: {
    section: '四、词语搭配',
    typeLabel: '可选词语',
    options: '①火红火红 ②金黄金黄 ③碧绿碧绿 ④瓦蓝瓦蓝',
    bodies: ['（____）的天空', '（____）的枫叶', '（____）的草地', '（____）的稻谷'],
  },
  19: {
    section: '四、量词搭配',
    typeLabel: '可选量词',
    options: '①块 ②棵 ③双 ④片 ⑤只 ⑥个',
    bodies: ['一（____）大眼睛', '一（____）玉米地', '一（____）桃树', '一（____）瓜地', '一（____）西瓜', '一（____）小兔子'],
  },
};

for (const [dayNumberRaw, config] of Object.entries(optionSections)) {
  const dayNumber = Number(dayNumberRaw);
  const day = data.days.find((item) => item.day === dayNumber);
  if (!day) continue;
  const first = day.questions.findIndex((q) => q.sectionTitle === config.section);
  const last = day.questions.findLastIndex((q) => q.sectionTitle === config.section);
  if (first < 0 || last < first) continue;
  const prefix = `chinese_review_21_d${String(dayNumber).padStart(2, '0')}_options`;
  const rebuilt = [
    {
      id: `${prefix}_example`,
      type: 'example',
      sectionTitle: config.section,
      displayPrompt: `${config.typeLabel}：${config.options}`,
      prompt: `${config.typeLabel}：${config.options}`,
      answer: null,
      answerSource: 'display_only',
      images: [],
    },
    ...config.bodies.map((body, index) => ({
      id: `${prefix}_${String(index + 1).padStart(2, '0')}`,
      type: 'word_usage',
      sectionTitle: config.section,
      displayPrompt: body,
      prompt: body,
      answer: null,
      answerSource: 'manual_required',
      images: [],
    })),
  ];
  day.questions.splice(first, last - first + 1, ...rebuilt);
}

for (const day of data.days) {
  if (day.day < 2) continue;
  for (const q of day.questions) {
    if (isDisplayOnly(q)) continue;
    const cleaned = cleanPrompt(q.displayPrompt || q.prompt);
    q.displayPrompt = cleaned;
    q.prompt = cleaned;
  }
}

let practice = 0;
let display = 0;
for (const day of data.days) {
  for (const question of day.questions) {
    if (isDisplayOnly(question)) display += 1;
    else practice += 1;
  }
}
fs.writeFileSync(path, JSON.stringify(data, null, 2) + '\n', 'utf8');
const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
const item = catalog.sets.find((set) => set.id === data.id);
if (item) item.description = `21天 · ${practice}道练习 · 手写练习`;
fs.writeFileSync(catalogPath, JSON.stringify(catalog, null, 2) + '\n', 'utf8');
console.log(JSON.stringify({ practice, display }, null, 2));
