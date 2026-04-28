from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import httpx
import uvicorn
from typing import Optional
import base64
from io import BytesIO
from chatbot_service import router as chatbot_router

app = FastAPI(title="Yemek Tanıma Proxy API")

# Include chatbot router
app.include_router(chatbot_router)

# CORS ayarları - tüm kaynaklardan gelen isteklere izin ver
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tüm kaynaklara izin ver (geliştirme için)
    allow_credentials=True,
    allow_methods=["*"],  # Tüm HTTP metodlarına izin ver
    allow_headers=["*"],  # Tüm başlıklara izin ver
    expose_headers=["*"],  # Tüm başlıkları istemciye göster
    max_age=1800,  # Preflight isteklerini önbelleğe al (30 dakika)
)

# Render API URL
RENDER_API_URL = "https://vision-processing.onrender.com/tahmin"

@app.get("/")
def read_root():
    return {"message": "Yemek Tanıma Proxy API çalışıyor"}

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

# Doğrudan çalıştırma için
if __name__ == "__main__":
    uvicorn.run("food_recognition_proxy:app", host="0.0.0.0", port=8000, reload=True)
