from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str
    database: str


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    conversation_id: str | None = None
    student_id: int | None = None
    grade_label: str | None = Field(default=None, max_length=40)


class ChatResponse(BaseModel):
    conversation_id: str
    answer: str
    model: str
    usage: dict | None = None


class WrongItemExplainRequest(BaseModel):
    subject: str = Field(min_length=1, max_length=24)
    question: str = Field(min_length=1, max_length=4000)
    student_answer: str | None = Field(default=None, max_length=2000)
    correct_answer: str | None = Field(default=None, max_length=2000)
    knowledge_point: str | None = Field(default=None, max_length=120)
    grade_label: str | None = Field(default=None, max_length=40)
    student_id: int | None = None


class WrongItemExplainResponse(BaseModel):
    explanation: str
    model: str
    wrong_item_id: int | None = None
    usage: dict | None = None
