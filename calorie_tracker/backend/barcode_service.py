from fastapi import FastAPI, HTTPException
import requests
from fastapi.middleware.cors import CORSMiddleware

# This service will be imported by main.py

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
