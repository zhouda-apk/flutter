import logging

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from schemas import LlmOrganizeNoteRequest, LlmOrganizeNoteResponse
from services import organize_service

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="OCR LLM Backend",
    description="AI note organization API for the Flutter OCR app.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "OCR LLM Backend",
        "provider": settings.provider,
        "model": settings.active_model,
    }


@app.post("/v1/notes/organize", response_model=LlmOrganizeNoteResponse)
async def organize_note(request: LlmOrganizeNoteRequest) -> LlmOrganizeNoteResponse:
    logger.info(
        "Organize note request: client_request_id=%s, pages=%s, language=%s",
        request.client_request_id,
        len(request.pages),
        request.language,
    )

    try:
        result = await organize_service.organize_note(request)
        logger.info(
            "Organize note complete: client_request_id=%s, title=%s",
            request.client_request_id,
            result.title,
        )
        return result
    except ValueError as exc:
        logger.error("Invalid organize note request: %s", exc)
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.error("AI organization failed: %s", exc)
        raise HTTPException(
            status_code=500,
            detail="AI service failed. Please try again later.",
        ) from exc


if __name__ == "__main__":
    import uvicorn

    logger.info("Starting OCR LLM Backend")
    logger.info("Provider: %s", settings.provider)
    logger.info("Model: %s", settings.active_model)
    logger.info("URL: http://%s:%s", settings.host, settings.port)

    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )
