import os
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras.applications import ResNet50
from tensorflow.keras.applications.resnet50 import preprocess_input, decode_predictions
from tensorflow.keras.preprocessing import image

print("Model yükleniyor...")
model = ResNet50(weights='imagenet')
print("Model başarıyla yüklendi.")

def preprocess_image(img_path):
    img = image.load_img(img_path, target_size=(224, 224))
    x = image.img_to_array(img)
    x = np.expand_dims(x, axis=0)
    x = preprocess_input(x)
    return x

img_path = "muz.jpg"

if not os.path.exists(img_path):
    print(f"Hata: {img_path} bulunamadı! Lütfen doğru dosya yolunu kullanın.")
else:
    print(f"Görüntü dosyası bulundu: {img_path}")
    
    processed_image = preprocess_image(img_path)
    predictions = model.predict(processed_image)
    results = decode_predictions(predictions, top=3)[0]

    print("\nTahmin sonuçları:")
    for result in results:
        print(f"{result[1]}: {result[2]*100:.2f}%")
