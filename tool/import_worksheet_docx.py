import argparse
import ast
import json
import operator
import re
from pathlib import Path

from docx import Document
from docx.oxml.table import CT_Tbl
from docx.oxml.text.paragraph import CT_P
from docx.table import Table
from docx.text.paragraph import Paragraph


DAY_RE = re.compile(r"Day\s*(\d+)", re.IGNORECASE)
SECTION_DIRECT = "直接写出得数"
SECTION_BLANK = "括号"
SECTION_WORD = "应用题"


def iter_blocks(document):
    for child in document.element.body.iterchildren():
        if isinstance(child, CT_P):
            yield "paragraph", Paragraph(child, document).text.strip()
        elif isinstance(child, CT_Tbl):
            table = Table(child, document)
            yield "table", [
                [cell.text.strip() for cell in row.cells] for row in table.rows
            ]


def normalize_text(value):
    return re.sub(r"\s+", " ", value).strip()


def split_equations(value):
    value = value.replace("＝", "=").replace("—", "-").replace("－", "-")
    parts = re.split(r"\s{2,}", value.strip())
    return [part.strip() for part in parts if "=" in part]


def extract_direct_equations(value):
    value = value.replace("＝", "=").replace("—", "-").replace("－", "-")
    pattern = re.compile(r"\d+\s*(?:[+\-]\s*\d+\s*)+=")
    return [normalize_text(match.group(0)) for match in pattern.finditer(value)]


def extract_blank_equations(value):
    value = value.replace("（", "(").replace("）", ")")
    value = value.replace("＝", "=").replace("—", "-").replace("－", "-")
    token = r"(?:\(\s*\)|\d+)"
    expression = rf"{token}\s*(?:[+\-]\s*{token})*"
    pattern = re.compile(rf"{expression}=\s*{token}")
    prompts = []
    for match in pattern.finditer(value):
        prompt = normalize_text(match.group(0))
        if "(" in prompt and ")" in prompt:
            prompts.append(prompt)
    return prompts


def extract_prompts(value, section):
    if section == "direct":
        prompts = extract_direct_equations(value)
    elif section == "blank":
        prompts = extract_blank_equations(value)
    else:
        prompts = split_equations(value)
    return prompts or ([value.strip()] if "=" in value else [])


def safe_eval_expression(expression):
    tree = ast.parse(expression, mode="eval")
    return _eval_node(tree.body)


def _eval_node(node):
    ops = {
        ast.Add: operator.add,
        ast.Sub: operator.sub,
        ast.USub: operator.neg,
        ast.UAdd: operator.pos,
    }
    if isinstance(node, ast.Constant) and isinstance(node.value, int):
        return node.value
    if isinstance(node, ast.BinOp) and type(node.op) in ops:
        return ops[type(node.op)](_eval_node(node.left), _eval_node(node.right))
    if isinstance(node, ast.UnaryOp) and type(node.op) in ops:
        return ops[type(node.op)](_eval_node(node.operand))
    raise ValueError(f"Unsupported expression: {ast.dump(node)}")


def solve_direct(equation):
    expression = equation.split("=", 1)[0]
    expression = re.sub(r"[^0-9+\-]", "", expression)
    if not expression:
        return None
    try:
        return str(safe_eval_expression(expression))
    except Exception:
        return None


def solve_blank_equation(equation):
    expression = equation.replace("（", "(").replace("）", ")")
    expression = re.sub(r"\(\s*\)", "x", expression)
    expression = re.sub(r"\(\s+\)", "x", expression)
    expression = re.sub(r"\(\s*", "x", expression)
    expression = re.sub(r"\s*\)", "", expression)
    expression = re.sub(r"\s+", "", expression)
    expression = expression.replace("＝", "=").replace("－", "-")
    if expression.count("=") != 1 or "x" not in expression:
        return None
    left, right = expression.split("=", 1)
    if left.count("x") + right.count("x") != 1:
        return None
    for candidate in range(0, 101):
        try:
            lval = safe_eval_expression(left.replace("x", str(candidate)))
            rval = safe_eval_expression(right.replace("x", str(candidate)))
        except Exception:
            continue
        if lval == rval:
            return str(candidate)
    return None


def make_question(day, index, section, prompt, manual_answers=None):
    prompt = normalize_text(prompt)
    if not prompt:
        return None
    question_id = f"day{day:02d}_q{index:02d}"
    if section == "direct":
        answer = solve_direct(prompt)
        question_type = "calculation"
    elif section == "blank":
        answer = solve_blank_equation(prompt)
        question_type = "blank_equation"
    else:
        answer = (manual_answers or {}).get(question_id)
        question_type = "word_problem"

    return {
        "id": question_id,
        "type": question_type,
        "prompt": prompt,
        "answer": answer,
        "answerSource": "auto" if section != "word" and answer is not None else (
            "manual" if answer is not None else "manual_required"
        ),
    }


def add_prompts(day_data, section, prompts, manual_answers=None):
    for prompt in prompts:
        question = make_question(
            day_data["day"],
            len(day_data["questions"]) + 1,
            section,
            prompt,
            manual_answers,
        )
        if question:
            day_data["questions"].append(question)


def parse_docx(
    path,
    limit_days=None,
    manual_answers=None,
    worksheet_id="worksheet_import",
    title="导入练习",
    subject="math",
    grade="",
    description="",
):
    document = Document(path)
    result = {
        "formatVersion": 1,
        "id": worksheet_id,
        "title": title,
        "subject": subject,
        "grade": grade,
        "description": description,
        "sourceFile": str(path),
        "days": [],
    }
    current_day = None
    current_section = None

    for kind, value in iter_blocks(document):
        if kind == "paragraph":
            text = normalize_text(value)
            if not text:
                continue
            day_match = DAY_RE.search(text)
            if day_match:
                if current_day:
                    result["days"].append(current_day)
                    if limit_days and len(result["days"]) >= limit_days:
                        return result
                current_day = {
                    "day": int(day_match.group(1)),
                    "title": text,
                    "questions": [],
                }
                current_section = None
                continue
            if current_day is None:
                continue
            if SECTION_DIRECT in text:
                current_section = "direct"
                inline = text.split(SECTION_DIRECT, 1)[-1]
                add_prompts(
                    current_day, current_section, split_equations(inline), manual_answers
                )
                continue
            if SECTION_BLANK in text:
                current_section = "blank"
                inline = text.split("数", 1)[-1] if "数" in text else ""
                add_prompts(
                    current_day, current_section, split_equations(inline), manual_answers
                )
                continue
            if SECTION_WORD in text:
                current_section = "word"
                inline = text.split(SECTION_WORD, 1)[-1]
                if inline:
                    add_prompts(current_day, current_section, [inline], manual_answers)
                continue
            if current_section in {"direct", "blank"}:
                add_prompts(
                    current_day,
                    current_section,
                    extract_prompts(text, current_section),
                    manual_answers,
                )
            elif current_section == "word":
                blank_prompts = extract_blank_equations(text)
                if blank_prompts:
                    add_prompts(current_day, "blank", blank_prompts, manual_answers)
                else:
                    add_prompts(current_day, current_section, [text], manual_answers)
        elif kind == "table" and current_day is not None:
            prompts = []
            for row in value:
                for cell in row:
                    if cell:
                        prompts.extend(extract_prompts(cell, current_section))
            if current_section in {"direct", "blank"}:
                add_prompts(current_day, current_section, prompts, manual_answers)

    if current_day:
        result["days"].append(current_day)
    if limit_days:
        result["days"] = result["days"][:limit_days]
    return result


def project_relative_asset(path):
    resolved = path.resolve()
    try:
        return resolved.relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        return path.as_posix().replace("\\", "/")


def update_catalog(catalog_path, item):
    catalog = {"sets": []}
    if catalog_path.exists():
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    sets = catalog.setdefault("sets", [])
    replaced = False
    for index, existing in enumerate(sets):
        if existing.get("id") == item["id"]:
            sets[index] = item
            replaced = True
            break
    if not replaced:
        sets.append(item)
    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    catalog_path.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser(
        description="Import a Word worksheet into app-ready JSON."
    )
    parser.add_argument("docx", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--id", required=True, help="Stable worksheet id.")
    parser.add_argument("--title", required=True, help="Worksheet title shown in app.")
    parser.add_argument("--subject", default="math", help="Internal subject id.")
    parser.add_argument("--limit-days", type=int)
    parser.add_argument(
        "--answers",
        type=Path,
        help="Optional JSON mapping question ids, such as day01_q19, to answers.",
    )
    parser.add_argument(
        "--update-catalog",
        action="store_true",
        help="Register or replace this worksheet in assets/worksheets/index.json.",
    )
    parser.add_argument(
        "--catalog",
        type=Path,
        default=Path("assets/worksheets/index.json"),
        help="Catalog JSON path used with --update-catalog.",
    )
    parser.add_argument("--catalog-subject", default="数学")
    parser.add_argument("--grade", default="")
    parser.add_argument("--description", default="")
    args = parser.parse_args()

    manual_answers = None
    if args.answers:
        manual_answers = json.loads(args.answers.read_text(encoding="utf-8"))

    data = parse_docx(
        args.docx,
        args.limit_days,
        manual_answers,
        worksheet_id=args.id,
        title=args.title,
        subject=args.subject,
        grade=args.grade,
        description=args.description,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    if args.update_catalog:
        update_catalog(
            args.catalog,
            {
                "id": args.id,
                "title": args.title,
                "subject": args.catalog_subject,
                "grade": args.grade,
                "description": args.description,
                "asset": project_relative_asset(args.out),
            },
        )

    question_count = sum(len(day["questions"]) for day in data["days"])
    answer_counts = {}
    for day in data["days"]:
        for question in day["questions"]:
            source = question["answerSource"]
            answer_counts[source] = answer_counts.get(source, 0) + 1
    auto_count = sum(
        1
        for day in data["days"]
        for question in day["questions"]
        if question["answerSource"] == "auto"
    )
    print(
        f"Imported {len(data['days'])} day(s), "
        f"{question_count} question(s), {auto_count} auto answer(s)."
    )
    print(f"Answer sources: {answer_counts}")


if __name__ == "__main__":
    main()
