from fastapi import FastAPI, HTTPException, UploadFile, File, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import requests
import httpx
import uvicorn
import base64
from typing import Optional
from io import BytesIO
import os
from pydantic import BaseModel
from dotenv import load_dotenv

# .env dosyasını yükle
load_dotenv()

app = FastAPI(title="Calorie Tracker Backend API")

# CORS configuration to allow requests from Flutter web app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods
    allow_headers=["*"],  # Allow all headers
    expose_headers=["*"],  # Expose all headers to client
    max_age=1800,  # Cache preflight requests for 30 minutes
)

# Render API URL for food recognition
RENDER_API_URL = "https://vision-processing.onrender.com/tahmin"

# OpenRouter API anahtarı ve model bilgisi (Chatbot için)
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_MODEL = "deepseek/deepseek-prover-v2:free"

@app.get("/")
def read_root():
    return {"message": "Calorie Tracker API is running"}

# Chatbot istek modeli
class ChatRequest(BaseModel):
    message: str

# Barcode servisi fonksiyonu
async def get_product_by_barcode(barcode: str):
    """
    Fetch product information from Open Food Facts API by barcode
    """
    url = f"https://world.openfoodfacts.org/api/v0/product/{barcode}.json"
    response = requests.get(url)
    
    if response.status_code != 200:
        raise HTTPException(status_code=500, detail="Open Food Facts API erişim hatası.")
    
    data = response.json()

    if data.get("status") != 1:
        raise HTTPException(status_code=404, detail="Ürün bulunamadı.")

    product = data["product"]
    
    # Extract the necessary information
    result = {
        "foodName": product.get("product_name", "Bilinmiyor"),
        "brand": product.get("brands", ""),
        "calories": product.get("nutriments", {}).get("energy-kcal_100g", 0),
        "carbs": product.get("nutriments", {}).get("carbohydrates_100g", 0),
        "protein": product.get("nutriments", {}).get("proteins_100g", 0),
        "fat": product.get("nutriments", {}).get("fat_100g", 0),
        "fiber": product.get("nutriments", {}).get("fiber_100g", 0),
        "sugar": product.get("nutriments", {}).get("sugars_100g", 0),
        "serving": "100g",
        "servingAmount": "1",
        "servingUnit": "porsiyon",
        "barcode": barcode,
        "predictionSource": "Barcode Scan"
    }
    
    return result

# Barkod API endpoint'i
@app.get("/urun/{barcode}")
async def urun_bilgisi(barcode: str):
    """
    Get product information by barcode from Open Food Facts
    """
    return await get_product_by_barcode(barcode)

# Food Recognition API endpoints
@app.post("/recognize_file")
async def recognize_food_file(file: UploadFile = File(...)):
    """
    Görüntüden yemek tanıma için Render API'ye proxy isteği yapar.
    """
    try:
        # Dosya içeriğini oku
        contents = await file.read()
        
        # Render API'ye istek gönder
        async with httpx.AsyncClient(timeout=60.0) as client:
            files = {"file": (file.filename, contents, file.content_type)}
            response = await client.post(RENDER_API_URL, files=files)
            
            # Yanıtı kontrol et
            if response.status_code == 200:
                return response.json()
            else:
                return {
                    "error": f"Render API hatası: {response.status_code}",
                    "detail": response.text
                }
    except Exception as e:
        return {
            "error": "Proxy hatası",
            "detail": str(e)
        }

@app.post("/recognize_base64")
async def recognize_food_base64(data: dict):
    """
    Base64 kodlanmış görüntüden yemek tanıma için Render API'ye proxy isteği yapar.
    Web uygulamaları için idealdir.
    """
    try:
        # Base64 kodlu veriyi al
        base64_image = data.get("image")
        if not base64_image:
            return {"error": "Base64 kodlu görüntü bulunamadı"}
        
        # Base64'ü ikili veriye dönüştür
        image_data = base64.b64decode(base64_image.split(",")[1] if "," in base64_image else base64_image)
        
        # Render API'ye istek gönder
        async with httpx.AsyncClient(timeout=60.0) as client:
            files = {"file": ("image.jpg", image_data, "image/jpeg")}
            response = await client.post(RENDER_API_URL, files=files)
            
            # Yanıtı kontrol et
            if response.status_code == 200:
                return response.json()
            else:
                return {
                    "error": f"Render API hatası: {response.status_code}",
                    "detail": response.text
                }
    except Exception as e:
        return {
            "error": "Proxy hatası",
            "detail": str(e)
        }

# Chatbot endpoint
@app.post("/chatbot")
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

# Doğrudan çalıştırma için
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
