from app.prompts import child_chat_system_prompt, wrong_item_prompt


def test_child_chat_prompt_mentions_grade_and_safety():
    prompt = child_chat_system_prompt("一年级下册")

    assert "名字叫果果" in prompt
    assert "性别女" in prompt
    assert "活泼可爱、聪明" in prompt
    assert "一年级下册" in prompt
    assert "不要使用吓唬、排名、羞辱类表达" in prompt
    assert "询问家长" in prompt


def test_wrong_item_prompt_contains_required_fields():
    prompt = wrong_item_prompt(
        subject="数学",
        question="3 + 4 = ?",
        student_answer="6",
        correct_answer="7",
        knowledge_point="20以内加法",
        grade_label="一年级上册",
    )

    assert "数学" in prompt
    assert "3 + 4 = ?" in prompt
    assert "孩子答案：6" in prompt
    assert "参考答案：7" in prompt
    assert "同类型的小练习" in prompt
