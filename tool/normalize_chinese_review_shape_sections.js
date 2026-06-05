const fs = require('fs');
const path = 'assets/worksheets/generated/chinese_review_21.json';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));
const knownShapePairs = {
  1: [['入', '人'], ['么', '公'], ['太', '大'], ['主', '住'], ['乐', '东']],
  2: [['间', '问'], ['地', '他'], ['米', '来'], ['千', '干'], ['止', '正']],
  3: [['贝', '见'], ['运', '远'], ['今', '令'], ['近', '进'], ['玉', '王']],
  4: [['怕', '拍'], ['像', '象'], ['他', '她'], ['找', '我'], ['课', '棵']],
  5: [['清', '晴'], ['古', '右'], ['广', '厂'], ['方', '万'], ['后', '石']],
  6: [['和', '合'], ['米', '来'], ['自', '白'], ['门', '们'], ['把', '巴']],
  7: [['平', '干'], ['坐', '座'], ['白', '百'], ['着', '看'], ['瓜', '爪']],
  8: [['夕', '多'], ['块', '快'], ['羽', '习'], ['左', '在'], ['红', '江']],
};
for (const day of data.days) {
  const pairs = knownShapePairs[day.day];
  if (!pairs) continue;
  const shape = day.questions.filter((q) => q.sectionTitle.includes('形近字组词'));
  for (let i = 0; i < Math.min(shape.length, pairs.length); i += 1) {
    const [top, bottom] = pairs[i];
    const prompt = `${top}（    ）\n${bottom}（    ）`;
    shape[i].displayPrompt = prompt;
    shape[i].prompt = prompt;
    shape[i].type = 'word_group';
    shape[i].answer = null;
    shape[i].answerSource = 'manual_required';
    shape[i].images = [];
  }
}
fs.writeFileSync(path, JSON.stringify(data, null, 2) + '\n', 'utf8');
console.log('shape prompts normalized');
