const fs = require('fs');

const path = 'assets/worksheets/generated/chinese_review_21.json';
const catalogPath = 'assets/worksheets/index.json';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));

function isDisplayOnly(question) {
  return question.type === 'example' || question.answerSource === 'display_only';
}

function cleanPrompt(raw) {
  return String(raw || '')
    .replace(/\r/g, '')
    .replace(/^\s*(?:\d+[.．、]|[（(]\d+[）)]|[①②③④⑤⑥⑦⑧⑨⑩])\s*/u, '')
    .replace(/\s+/g, ' ')
    .replace(/\s*\n\s*/g, '\n')
    .trim();
}

function normalizeQuestion(question, patch = {}) {
  const prompt = patch.displayPrompt ?? question.displayPrompt ?? question.prompt ?? '';
  return {
    ...question,
    ...patch,
    displayPrompt: prompt,
    prompt,
    answer: patch.answer === undefined ? (question.answer ?? null) : patch.answer,
    answerSource: patch.answerSource ?? question.answerSource ?? 'manual_required',
    images: patch.images ?? question.images ?? [],
  };
}

function makeExample(id, sectionTitle, prompt) {
  return {
    id,
    type: 'example',
    sectionTitle,
    displayPrompt: prompt,
    prompt,
    answer: null,
    answerSource: 'display_only',
    images: [],
  };
}

const knownShapePairs = {
  2: [['间', '问'], ['地', '他'], ['米', '来'], ['千', '干'], ['止', '正']],
  3: [['贝', '见'], ['运', '远'], ['今', '令'], ['近', '进'], ['玉', '王']],
  4: [['怕', '拍'], ['像', '象'], ['他', '她'], ['找', '我'], ['课', '棵']],
  5: [['清', '晴'], ['古', '右'], ['广', '厂'], ['方', '万'], ['后', '石']],
  6: [['和', '合'], ['米', '来'], ['自', '白'], ['门', '们'], ['把', '巴']],
  7: [['平', '干'], ['坐', '座'], ['白', '百'], ['着', '看'], ['瓜', '爪']],
  8: [['夕', '多'], ['块', '快'], ['羽', '习'], ['左', '在'], ['红', '江']],
};

function rebuildShapeSection(day, questions) {
  const section = questions.find((q) => q.sectionTitle.includes('形近字组词'))?.sectionTitle;
  if (!section) return questions;
  const pairs = knownShapePairs[day.day];
  if (!pairs) return questions.map((q) => normalizeQuestion(q, { displayPrompt: cleanPrompt(q.displayPrompt || q.prompt) }));
  const first = questions.findIndex((q) => q.sectionTitle === section);
  const last = questions.findLastIndex((q) => q.sectionTitle === section);
  const rebuilt = pairs.map(([top, bottom], index) => ({
    id: `chinese_review_21_d${String(day.day).padStart(2, '0')}_shape_${String(index + 1).padStart(2, '0')}`,
    type: 'word_group',
    sectionTitle: section,
    displayPrompt: `${top}（    ）\n${bottom}（    ）`,
    prompt: `${top}（    ）\n${bottom}（    ）`,
    answer: null,
    answerSource: 'manual_required',
    images: [],
  }));
  return [...questions.slice(0, first), ...rebuilt, ...questions.slice(last + 1)];
}

function splitOptionPrefix(prompt) {
  const text = cleanPrompt(prompt);
  const match = text.match(/^((?:[①②③④⑤⑥⑦⑧⑨⑩]\s*[^①②③④⑤⑥⑦⑧⑨⑩\s]+\s*){2,})(.+)$/u);
  if (!match) return null;
  return { options: match[1].trim(), body: match[2].trim() };
}

function rebuildOptionSection(day, sectionTitle, questions, sectionQuestions) {
  const optionPieces = sectionQuestions.map((q) => splitOptionPrefix(q.displayPrompt || q.prompt));
  const optionPiece = optionPieces.find(Boolean);
  if (!optionPiece) return sectionQuestions.map((q) => normalizeQuestion(q, { displayPrompt: cleanPrompt(q.displayPrompt || q.prompt) }));

  const typeLabel = sectionTitle.includes('动词')
    ? '可选动词'
    : sectionTitle.includes('量词')
      ? '可选量词'
      : '可选词';
  const prefix = `chinese_review_21_d${String(day.day).padStart(2, '0')}_${sectionTitle.includes('动词') ? 'verb' : sectionTitle.includes('量词') ? 'measure' : 'match'}`;
  const example = makeExample(`${prefix}_options`, sectionTitle, `${typeLabel}：${optionPiece.options}`);
  const bodyQuestions = sectionQuestions.map((q, index) => {
    const parsed = splitOptionPrefix(q.displayPrompt || q.prompt);
    const body = parsed ? parsed.body : cleanPrompt(q.displayPrompt || q.prompt);
    return normalizeQuestion(q, {
      id: q.id || `${prefix}_${String(index + 1).padStart(2, '0')}`,
      displayPrompt: body,
      answer: null,
      answerSource: 'manual_required',
    });
  });
  return [example, ...bodyQuestions];
}

function rebuildExampleSection(day, sectionTitle, sectionQuestions) {
  const rebuilt = [];
  let exampleIndex = 0;
  let practiceIndex = 0;
  for (const q of sectionQuestions) {
    let prompt = cleanPrompt(q.displayPrompt || q.prompt);
    const isExamplePrompt = /^例[:：]/u.test(prompt) || prompt.includes('例：');
    if (isExamplePrompt && !/[（(]____?[）)]|____|_\s*_/u.test(prompt)) {
      exampleIndex += 1;
      rebuilt.push(makeExample(
        `chinese_review_21_d${String(day.day).padStart(2, '0')}_example_${String(exampleIndex).padStart(2, '0')}`,
        sectionTitle,
        prompt,
      ));
      continue;
    }
    prompt = prompt.replace(/^例[:：]\s*/u, '');
    practiceIndex += 1;
    rebuilt.push(normalizeQuestion(q, {
      id: q.id || `chinese_review_21_d${String(day.day).padStart(2, '0')}_example_practice_${String(practiceIndex).padStart(2, '0')}`,
      displayPrompt: prompt,
      answer: null,
      answerSource: 'manual_required',
    }));
  }
  return rebuilt;
}

function rebuildGenericSection(sectionQuestions) {
  return sectionQuestions.map((q) => normalizeQuestion(q, {
    displayPrompt: cleanPrompt(q.displayPrompt || q.prompt),
    answer: q.answer ?? null,
    answerSource: q.answerSource ?? 'manual_required',
  }));
}

for (const day of data.days) {
  if (day.day < 2) continue;
  let questions = day.questions.filter((q) => !isDisplayOnly(q));
  questions = rebuildShapeSection(day, questions);

  const result = [];
  let index = 0;
  while (index < questions.length) {
    const sectionTitle = questions[index].sectionTitle;
    const sectionQuestions = [];
    while (index < questions.length && questions[index].sectionTitle === sectionTitle) {
      sectionQuestions.push(questions[index]);
      index += 1;
    }

    if (sectionTitle.includes('搭配')) {
      result.push(...rebuildOptionSection(day, sectionTitle, questions, sectionQuestions));
    } else if (sectionTitle.includes('照样子') || sectionTitle.includes('仿写')) {
      result.push(...rebuildExampleSection(day, sectionTitle, sectionQuestions));
    } else {
      result.push(...rebuildGenericSection(sectionQuestions));
    }
  }
  day.questions = result;
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

console.log(JSON.stringify({ practice, display, days: data.days.map((day) => ({ day: day.day, total: day.questions.length, practice: day.questions.filter((q) => !isDisplayOnly(q)).length, examples: day.questions.filter(isDisplayOnly).length })) }, null, 2));
