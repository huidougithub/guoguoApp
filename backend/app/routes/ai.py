from fastapi import APIRouter, Depends, HTTPException
from httpx import HTTPError
from sqlalchemy.orm import Session

from app.config import Settings, get_settings
from app.database import get_db
from app.deepseek_client import DeepSeekClient, DeepSeekNotConfiguredError
from app.models import (
    AiConversation,
    AiMessage,
    AiUsageLog,
    WrongItemCloud,
)
from app.prompts import child_chat_system_prompt, wrong_item_prompt
from app.schemas import (
    ChatRequest,
    ChatResponse,
    WrongItemExplainRequest,
    WrongItemExplainResponse,
)

router = APIRouter(prefix="/api/v1/ai", tags=["ai"])


def _usage_value(usage: dict | None, key: str) -> int | None:
    if not usage:
        return None
    value = usage.get(key)
    return int(value) if isinstance(value, int) else None


def _log_usage(
    db: Session,
    *,
    model: str,
    purpose: str,
    usage: dict | None,
    latency_ms: int | None,
    success: bool,
    error_message: str | None = None,
) -> None:
    db.add(
        AiUsageLog(
            model=model,
            purpose=purpose,
            prompt_tokens=_usage_value(usage, "prompt_tokens"),
            completion_tokens=_usage_value(usage, "completion_tokens"),
            total_tokens=_usage_value(usage, "total_tokens"),
            latency_ms=latency_ms,
            success=success,
            error_message=error_message,
        )
    )


@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> ChatResponse:
    conversation = None
    if request.conversation_id:
        conversation = db.get(AiConversation, request.conversation_id)
        if conversation is None:
            raise HTTPException(status_code=404, detail="conversation not found")
    else:
        title = request.message[:40]
        conversation = AiConversation(
            student_id=request.student_id,
            purpose="chat",
            title=title,
        )
        db.add(conversation)
        db.flush()

    messages = [
        {"role": "system", "content": child_chat_system_prompt(request.grade_label)},
        *[
            {"role": message.role, "content": message.content}
            for message in conversation.messages[-8:]
        ],
        {"role": "user", "content": request.message},
    ]

    client = DeepSeekClient(settings)
    try:
        result = await client.chat(messages, purpose="chat")
    except DeepSeekNotConfiguredError as exc:
        _log_usage(
            db,
            model=settings.deepseek_model,
            purpose="chat",
            usage=None,
            latency_ms=None,
            success=False,
            error_message=str(exc),
        )
        db.commit()
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except HTTPError as exc:
        _log_usage(
            db,
            model=settings.deepseek_model,
            purpose="chat",
            usage=None,
            latency_ms=None,
            success=False,
            error_message=str(exc),
        )
        db.commit()
        raise HTTPException(status_code=502, detail="DeepSeek API request failed") from exc

    db.add(AiMessage(conversation_id=conversation.id, role="user", content=request.message))
    db.add(
        AiMessage(
            conversation_id=conversation.id,
            role="assistant",
            content=result.content,
        )
    )
    _log_usage(
        db,
        model=result.model,
        purpose="chat",
        usage=result.usage,
        latency_ms=result.latency_ms,
        success=True,
    )
    db.commit()
    return ChatResponse(
        conversation_id=conversation.id,
        answer=result.content,
        model=result.model,
        usage=result.usage,
    )


@router.post("/wrong-item/explain", response_model=WrongItemExplainResponse)
async def explain_wrong_item(
    request: WrongItemExplainRequest,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> WrongItemExplainResponse:
    prompt = wrong_item_prompt(
        subject=request.subject,
        question=request.question,
        student_answer=request.student_answer,
        correct_answer=request.correct_answer,
        knowledge_point=request.knowledge_point,
        grade_label=request.grade_label,
    )
    messages = [
        {"role": "system", "content": child_chat_system_prompt(request.grade_label)},
        {"role": "user", "content": prompt},
    ]

    client = DeepSeekClient(settings)
    try:
        result = await client.chat(messages, purpose="wrong_item_explain")
    except DeepSeekNotConfiguredError as exc:
        _log_usage(
            db,
            model=settings.deepseek_model,
            purpose="wrong_item_explain",
            usage=None,
            latency_ms=None,
            success=False,
            error_message=str(exc),
        )
        db.commit()
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except HTTPError as exc:
        _log_usage(
            db,
            model=settings.deepseek_model,
            purpose="wrong_item_explain",
            usage=None,
            latency_ms=None,
            success=False,
            error_message=str(exc),
        )
        db.commit()
        raise HTTPException(status_code=502, detail="DeepSeek API request failed") from exc

    wrong_item = WrongItemCloud(
        student_id=request.student_id,
        subject=request.subject,
        grade_label=request.grade_label,
        knowledge_point=request.knowledge_point,
        question_text=request.question,
        student_answer=request.student_answer,
        correct_answer=request.correct_answer,
        explanation=result.content,
    )
    db.add(wrong_item)
    db.flush()
    _log_usage(
        db,
        model=result.model,
        purpose="wrong_item_explain",
        usage=result.usage,
        latency_ms=result.latency_ms,
        success=True,
    )
    db.commit()
    return WrongItemExplainResponse(
        explanation=result.content,
        model=result.model,
        wrong_item_id=wrong_item.id,
        usage=result.usage,
    )
