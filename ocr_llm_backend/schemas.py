from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field


class LlmPageInput(BaseModel):
    """每一頁的 OCR 內容"""
    page_index: int = Field(..., description="頁面索引（0-based）")
    page_number: int = Field(..., description="頁面編號（1-based）")
    text: str = Field(..., description="OCR 文本")
    summary: str = Field(..., description="頁面摘要")
    average_confidence: Optional[float] = Field(None, description="平均信心分數")
    low_confidence_count: Optional[int] = Field(None, description="低信心區塊數")


class LlmOrganizeNoteRequest(BaseModel):
    """筆記整理請求"""
    ocr_text: str = Field(..., description="所有 OCR 文本")
    pages: List[LlmPageInput] = Field(..., description="各頁 OCR 內容")
    language: str = Field(default="zh-TW", description="語言代碼")
    task: str = Field(default="organize_note", description="任務類型")
    options: dict = Field(
        default_factory=lambda: {"format": "markdown", "generate_tags": True},
        description="選項"
    )
    client_request_id: str = Field(..., description="客戶端請求 ID")


class LlmOrganizeNoteResponse(BaseModel):
    """筆記整理回應"""
    model_config = ConfigDict(protected_namespaces=())

    title: str = Field(..., description="生成的標題")
    summary: str = Field(..., description="生成的摘要")
    organized_content: str = Field(..., description="整理後的 Markdown 內容")
    tags: List[str] = Field(..., description="自動生成的標籤")
    warnings: List[str] = Field(default_factory=list, description="警告信息")
    model_name: str = Field(..., description="使用的模型名稱")
    prompt_version: str = Field(..., description="提示詞版本")
