import json
import logging
import re
from typing import Any

from config import settings
from schemas import LlmOrganizeNoteRequest, LlmOrganizeNoteResponse

logger = logging.getLogger(__name__)


ORGANIZED_NOTE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "title": {"type": "string"},
        "summary": {"type": "string"},
        "organized_content": {"type": "string"},
        "tags": {"type": "array", "items": {"type": "string"}},
        "warnings": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["title", "summary", "organized_content", "tags", "warnings"],
}


class NoteOrganizeService:
    """Organize OCR text into structured notes with the configured LLM."""

    def __init__(self):
        self.provider = settings.provider
        self.model = settings.active_model
        self.max_tokens = settings.active_max_tokens
        self.client = self._create_client()

    def _create_client(self) -> Any:
        if self.provider == "google":
            if not settings.google_api_key:
                raise ValueError(
                    "GOOGLE_API_KEY is required when LLM_PROVIDER=google"
                )

            from google import genai

            return genai.Client(api_key=settings.google_api_key)

        if self.provider == "openai":
            if not settings.openai_api_key:
                raise ValueError(
                    "OPENAI_API_KEY is required when LLM_PROVIDER=openai"
                )

            from openai import OpenAI

            return OpenAI(api_key=settings.openai_api_key)

        raise ValueError(
            f"Unsupported LLM_PROVIDER={settings.llm_provider!r}; "
            "use 'google'/'gemini' or 'openai'"
        )

    async def organize_note(
        self, request: LlmOrganizeNoteRequest
    ) -> LlmOrganizeNoteResponse:
        logger.info(
            "Start organizing note: request_id=%s provider=%s model=%s",
            request.client_request_id,
            self.provider,
            self.model,
        )

        prompt = self._build_prompt(request)

        try:
            response_text = self._generate_content(prompt)
            logger.info(
                "LLM response received: request_id=%s provider=%s",
                request.client_request_id,
                self.provider,
            )
            return self._parse_llm_response(response_text)
        except Exception:
            logger.exception("LLM service error")
            raise

    def _generate_content(self, prompt: str) -> str:
        if self.provider == "openai":
            completion = self.client.chat.completions.create(
                model=self.model,
                max_tokens=self.max_tokens,
                temperature=0.2,
                response_format={"type": "json_object"},
                messages=[
                    {
                        "role": "system",
                        "content": "Return only valid JSON matching the requested schema.",
                    },
                    {"role": "user", "content": prompt},
                ],
            )
            return completion.choices[0].message.content or ""

        from google.genai import types

        response = self.client.models.generate_content(
            model=self.model,
            contents=prompt,
            config=types.GenerateContentConfig(
                max_output_tokens=self.max_tokens,
                temperature=0.2,
                response_mime_type="application/json",
                response_schema=ORGANIZED_NOTE_SCHEMA,
            ),
        )
        return response.text or ""

    def _build_prompt(self, request: LlmOrganizeNoteRequest) -> str:
        organize_instruction = self._option_string(
            request.options,
            "organize_instruction",
            "請將 OCR 內容整理成清楚的繁體中文筆記。",
        )
        organize_label = self._option_string(
            request.options,
            "organize_label",
            "一般筆記",
        )
        translate_enabled = self._option_bool(request.options, "translate_enabled")
        target_language = self._option_string(
            request.options,
            "target_language",
            request.language,
        )
        translation_instruction = (
            f"整理完成後，請將 title、summary、organized_content、tags、warnings "
            f"全部翻譯成{target_language}。"
            if translate_enabled
            else f"請使用{request.language}輸出，預設使用自然、清楚的繁體中文。"
        )
        pages_text = "\n\n".join(
            [
                (
                    f"--- Page {page.page_number} ---\n"
                    f"Summary: {page.summary}\n"
                    f"Average confidence: {page.average_confidence}\n"
                    f"Low confidence count: {page.low_confidence_count}\n"
                    f"OCR text:\n{page.text}"
                )
                for page in request.pages
            ]
        )

        return f"""
你是一個 OCR 筆記整理助手，負責把辨識後的文字整理成可直接儲存的筆記。

整理模式：{organize_label}
模式指令：{organize_instruction}
{translation_instruction}

請先理解 OCR 內容，再整理成有結構的筆記。你可以修正明顯的 OCR 錯字、斷行與雜訊，但不能編造原文沒有出現的事實、數字、人名、日期或結論。

OCR 頁面內容：
{pages_text}

請只回傳 JSON，格式必須完全符合：
{{
  "title": "簡短明確的筆記標題",
  "summary": "可直接放入筆記內容開頭的重點摘要",
  "organized_content": "完整的 Markdown 筆記內容",
  "tags": ["標籤1", "標籤2", "標籤3"],
  "warnings": []
}}

欄位規則：
- title：使用繁體中文，簡短、明確，不要超過 20 個中文字。
- summary：用繁體中文整理最重要內容，適合直接當作筆記正文的開頭。
- organized_content：使用 Markdown，包含小標題、條列、表格或待辦清單，依整理模式決定。
- tags：產生 3 到 5 個有用的繁體中文標籤。
- warnings：只有在 OCR 文字明顯不完整、低信心、語意不確定或缺少上下文時才填寫；沒有問題就回傳空陣列。
- 若有翻譯需求，請翻譯整理後的內容，不要翻譯原始 OCR 雜訊。
- 若原文很長，請摘要整理，不要逐字重寫；務必優先確保 JSON 完整閉合。
- 不要把 JSON 包在 Markdown code block 裡。
""".strip()

    @staticmethod
    def _option_string(
        options: dict[str, Any],
        key: str,
        default: str,
    ) -> str:
        value = options.get(key)
        if value is None:
            return default
        text = str(value).strip()
        return text or default

    @staticmethod
    def _option_bool(options: dict[str, Any], key: str) -> bool:
        value = options.get(key)
        if isinstance(value, bool):
            return value
        if isinstance(value, str):
            return value.strip().lower() in {"true", "1", "yes", "y"}
        return False

    def _parse_llm_response(self, response_text: str) -> LlmOrganizeNoteResponse:
        json_text = self._extract_json(response_text)
        parse_warnings: list[str] = []

        try:
            parsed = json.loads(json_text)
        except (json.JSONDecodeError, TypeError, ValueError) as exc:
            parsed = self._parse_partial_json_fields(json_text)
            if not parsed:
                logger.error("Could not parse LLM response as JSON: %s", exc)
                raise RuntimeError("AI response was not valid JSON") from exc
            parse_warnings.append(
                "AI 回應 JSON 不完整，已擷取可用欄位；建議重新整理以取得完整內容。"
            )

        if not isinstance(parsed, dict):
            raise RuntimeError("AI response JSON root was not an object")

        title = self._clean_text(parsed.get("title")) or "AI 整理結果"
        summary = self._clean_text(parsed.get("summary"))
        organized_content = self._clean_text(parsed.get("organized_content"))

        if not organized_content:
            organized_content = summary

        if not organized_content:
            raise RuntimeError("AI response did not include note content")

        warnings = [
            *self._string_list(parsed.get("warnings")),
            *parse_warnings,
        ]

        return LlmOrganizeNoteResponse(
            title=title,
            summary=summary,
            organized_content=organized_content,
            tags=self._string_list(parsed.get("tags")),
            warnings=warnings,
            model_name=self.model,
            prompt_version="v1.2",
        )

    @staticmethod
    def _extract_json(response_text: str) -> str:
        text = response_text.strip()
        if text.startswith("```"):
            text = re.sub(r"^```(?:json)?\s*", "", text)
            text = re.sub(r"\s*```$", "", text)

        start = text.find("{")
        if start < 0:
            return text

        end = text.rfind("}")
        if end > start:
            return text[start : end + 1]

        return text[start:]

    def _parse_partial_json_fields(self, json_text: str) -> dict[str, Any]:
        """Recover useful fields from a JSON object truncated by max tokens."""
        parsed: dict[str, Any] = {}
        for field in ("title", "summary", "organized_content"):
            value = self._extract_json_string_field(json_text, field)
            if value:
                parsed[field] = value

        for field in ("tags", "warnings"):
            value = self._extract_json_array_field(json_text, field)
            if value:
                parsed[field] = value

        return parsed

    @staticmethod
    def _extract_json_string_field(json_text: str, field: str) -> str:
        match = re.search(rf'"{re.escape(field)}"\s*:\s*"', json_text)
        if not match:
            return ""

        chars: list[str] = []
        escaped = False
        index = match.end()
        while index < len(json_text):
            char = json_text[index]
            if escaped:
                chars.append("\\" + char)
                escaped = False
                index += 1
                continue

            if char == "\\":
                escaped = True
                index += 1
                continue

            if char == '"' and NoteOrganizeService._is_json_field_boundary(
                json_text[index + 1 :]
            ):
                break

            chars.append(char)
            index += 1

        raw_value = "".join(chars).strip()
        if not raw_value:
            return ""

        try:
            return str(json.loads(f'"{raw_value}"')).strip()
        except json.JSONDecodeError:
            return (
                raw_value.replace(r"\n", "\n")
                .replace(r"\"", '"')
                .replace(r"\\", "\\")
                .strip()
            )

    @staticmethod
    def _is_json_field_boundary(text_after_quote: str) -> bool:
        stripped = text_after_quote.lstrip()
        if stripped.startswith("}"):
            return True
        return re.match(r',\s*"[A-Za-z_][A-Za-z0-9_]*"\s*:', stripped) is not None

    @staticmethod
    def _extract_json_array_field(json_text: str, field: str) -> list[str]:
        match = re.search(
            rf'"{re.escape(field)}"\s*:\s*(\[[^\]]*\])',
            json_text,
            flags=re.DOTALL,
        )
        if not match:
            return []
        try:
            value = json.loads(match.group(1))
        except json.JSONDecodeError:
            return []
        return NoteOrganizeService._string_list(value)

    @staticmethod
    def _clean_text(value: Any) -> str:
        if value is None:
            return ""
        return str(value).strip()

    @staticmethod
    def _string_list(value: Any) -> list[str]:
        if not isinstance(value, list):
            return []
        return [str(item) for item in value if item is not None]


organize_service = NoteOrganizeService()
