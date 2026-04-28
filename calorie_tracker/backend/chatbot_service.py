from fastapi import APIRouter
from pydantic import BaseModel
import os
from dotenv import load_dotenv
from fastapi.responses import JSONResponse
import httpx

# .env dosyasını yükle
load_dotenv()

router = APIRouter()

# OpenRouter API anahtarı ve model bilgisi
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_MODEL = "deepseek/deepseek-prover-v2:free"

# İstek verisi modeli
class ChatRequest(BaseModel):
    message: str

# Chatbot endpoint
@router.post("/chatbot")
async def chatbot(request_data: ChatRequest):
    user_message = request_data.message.strip()

    if not user_message:
        return JSONResponse(status_code=400, content={"error": "Mesaj boş olamaz."})

    if not OPENROUTER_API_KEY or OPENROUTER_API_KEY == "sk-...":
        return JSONResponse(
            status_code=503,
            content={"reply": "API anahtarı yapılandırılmamış. Lütfen sistem yöneticisine başvurun."}
        )

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://yourdomain.com",  # isteğe bağlı olarak kendi domaininle değiştir
                    "X-Title": "FitnessBot"
                },
                json={
                    "model": OPENROUTER_MODEL,
                    "messages": [
                        {
                            "role": "system",
                            "content": "Sen bir Türkçe konuşan diyetisyen ve fitness uzmanısın. Kullanıcılara sağlıklı yaşam, spor ve beslenme konusunda yardımcı ol."
                        },
                        {"role": "user", "content": user_message}
                    ]
                },
                timeout=30.0
            )

            result = response.json()

            if "reply" in result:
                return {"reply": result["reply"]}
            elif "choices" in result:
                return {"reply": result["choices"][0]["message"]["content"]}
            else:
                return {"reply": f"Beklenmeyen yanıt formatı: {result}"}

        except httpx.RequestError as e:
            return {"reply": f"API isteği başarısız oldu: {str(e)}"}
