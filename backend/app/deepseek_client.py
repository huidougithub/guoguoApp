from __future__ import annotations

import time
from dataclasses import dataclass

import httpx

from app.config import Settings


class DeepSeekNotConfiguredError(RuntimeError):
    pass


@dataclass(frozen=True)
class DeepSeekResult:
    content: str
    model: str
    usage: dict | None
    latency_ms: int


class DeepSeekClient:
    def __init__(self, settings: Settings):
        self._settings = settings

    async def chat(self, messages: list[dict[str, str]], purpose: str) -> DeepSeekResult:
        if not self._settings.deepseek_api_key.strip():
            raise DeepSeekNotConfiguredError("DEEPSEEK_API_KEY is not configured")

        url = self._settings.deepseek_base_url.rstrip("/") + "/chat/completions"
        started = time.perf_counter()
        async with httpx.AsyncClient(timeout=60) as client:
            response = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {self._settings.deepseek_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self._settings.deepseek_model,
                    "messages": messages,
                    "temperature": 0.4 if purpose == "wrong_item_explain" else 0.6,
                    "max_tokens": 900 if purpose == "wrong_item_explain" else 700,
                    "stream": False,
                },
            )
            response.raise_for_status()
            payload = response.json()

        latency_ms = int((time.perf_counter() - started) * 1000)
        content = payload["choices"][0]["message"]["content"].strip()
        return DeepSeekResult(
            content=content,
            model=payload.get("model") or self._settings.deepseek_model,
            usage=payload.get("usage"),
            latency_ms=latency_ms,
        )
