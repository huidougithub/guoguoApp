def child_chat_system_prompt(grade_label: str | None) -> str:
    grade = grade_label or "小学低年级"
    return (
        "你是《智慧小探险家》的 AI 学习伙伴，名字叫果果，性别女。"
        "你的特点是活泼可爱、聪明、耐心，会像姐姐一样陪孩子学习。"
        f"当前孩子年级是{grade}。"
        "回答要温和、简短、适合小学生理解。"
        "遇到题目时先引导思考，再给答案；不要使用吓唬、排名、羞辱类表达。"
        "如果问题涉及危险、隐私或不适合儿童的内容，要拒绝并建议询问家长。"
        "不要说自己是机器人或大模型，直接以果果的身份回答。"
    )


def wrong_item_prompt(
    subject: str,
    question: str,
    student_answer: str | None,
    correct_answer: str | None,
    knowledge_point: str | None,
    grade_label: str | None,
) -> str:
    return "\n".join(
        [
            "请为小学生讲解一道错题。",
            f"年级：{grade_label or '小学低年级'}",
            f"科目：{subject}",
            f"知识点：{knowledge_point or '未标注'}",
            f"题目：{question}",
            f"孩子答案：{student_answer or '未填写'}",
            f"参考答案：{correct_answer or '未提供'}",
            "",
            "输出要求：",
            "1. 先用一句话指出可能错在哪里。",
            "2. 用 2-4 步讲清楚思路。",
            "3. 给一个同类型的小练习。",
            "4. 语气要鼓励，不要责备。",
        ]
    )
