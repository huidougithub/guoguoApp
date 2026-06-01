import argparse
import base64
import json
import re
from pathlib import Path

from docx import Document
from docx.oxml.table import CT_Tbl
from docx.oxml.text.paragraph import CT_P
from docx.table import Table, _Cell
from docx.text.paragraph import Paragraph


SECTION_RE = re.compile(r"^[一二三四五六七八九十]\s*[、.．]\s*(.+)")


def normalize_text(value):
    return re.sub(r"\s+", " ", value).strip()


def iter_blocks(parent):
    element = parent.element.body if hasattr(parent, "element") else parent._tc
    for child in element.iterchildren():
        if isinstance(child, CT_P):
            yield "paragraph", Paragraph(child, parent)
        elif isinstance(child, CT_Tbl):
            yield "table", Table(child, parent)


def paragraph_images(document, paragraph):
    images = []
    for blip in paragraph._element.xpath(".//a:blip"):
        rel_id = blip.get(
            "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed"
        )
        if not rel_id:
            continue
        part = document.part.related_parts.get(rel_id)
        if part is None:
            continue
        images.append(base64.b64encode(part.blob).decode("ascii"))
    return images


def cell_content(document, cell):
    texts = []
    images = []
    for paragraph in cell.paragraphs:
        text = normalize_text(paragraph.text)
        if text:
            texts.append(text)
        images.extend(paragraph_images(document, paragraph))
    return normalize_text(" ".join(texts)), images


def add_question(section, prompt, images, answers):
    prompt = normalize_text(prompt)
    if not prompt and not images:
        return
    question_id = f"section{section['day']:02d}_q{len(section['questions']) + 1:02d}"
    answer = answers.get(question_id)
    section["questions"].append(
        {
            "id": question_id,
            "type": "chinese_free_text",
            "prompt": prompt or "看图作答",
            "answer": answer,
            "answerSource": "manual" if answer else "manual_required",
            "images": images,
        }
    )


def parse_docx(path, worksheet_id, title, grade, description, answers):
    document = Document(path)
    result = {
        "formatVersion": 1,
        "id": worksheet_id,
        "title": title,
        "subject": "chinese",
        "grade": grade,
        "description": description,
        "sourceFile": str(path),
        "days": [],
    }
    current = None

    for kind, block in iter_blocks(document):
        if kind == "paragraph":
            text = normalize_text(block.text)
            images = paragraph_images(document, block)
            match = SECTION_RE.match(text)
            if match:
                current = {
                    "day": len(result["days"]) + 1,
                    "title": text,
                    "questions": [],
                }
                result["days"].append(current)
                continue
            if current is None:
                continue
            add_question(current, text, images, answers)
        else:
            if current is None:
                continue
            for row in block.rows:
                for cell in row.cells:
                    text, images = cell_content(document, cell)
                    add_question(current, text, images, answers)

    result["days"] = [day for day in result["days"] if day["questions"]]
    for index, day in enumerate(result["days"], start=1):
        day["day"] = index
        for q_index, question in enumerate(day["questions"], start=1):
            question["id"] = f"section{index:02d}_q{q_index:02d}"
            answer = answers.get(question["id"])
            question["answer"] = answer
            question["answerSource"] = "manual" if answer else "manual_required"
    return result


def main():
    parser = argparse.ArgumentParser(
        description="Import a Chinese Word worksheet into app-ready JSON."
    )
    parser.add_argument("docx", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--id", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--grade", default="")
    parser.add_argument("--description", default="")
    parser.add_argument("--answers", type=Path)
    args = parser.parse_args()

    answers = {}
    if args.answers and args.answers.exists():
        answers = json.loads(args.answers.read_text(encoding="utf-8"))

    data = parse_docx(
        args.docx,
        worksheet_id=args.id,
        title=args.title,
        grade=args.grade,
        description=args.description,
        answers=answers,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    question_count = sum(len(day["questions"]) for day in data["days"])
    image_count = sum(
        len(question.get("images", []))
        for day in data["days"]
        for question in day["questions"]
    )
    print(
        f"Imported {len(data['days'])} section(s), "
        f"{question_count} question(s), {image_count} image(s)."
    )


if __name__ == "__main__":
    main()
