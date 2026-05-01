"""
generate_placeholder_model.py
==============================
Gera um modelo TFLite MÍNIMO VÁLIDO para desenvolvimento.
Use train_risk_model.py para o modelo real de produção.

Uso:
  python scripts/ml/generate_placeholder_model.py
"""

import pathlib
import numpy as np
import tensorflow as tf

ASSETS_DIR = pathlib.Path(__file__).parent.parent.parent / "assets" / "models"
OUTPUT_PATH = ASSETS_DIR / "expiry_risk.tflite"

def main():
    print("Gerando modelo placeholder (regras simples embutidas)...")

    inputs = tf.keras.Input(shape=(4,), name="features")
    x = tf.keras.layers.Dense(8, activation="relu",
                              kernel_initializer="glorot_uniform")(inputs)
    outputs = tf.keras.layers.Dense(3, activation="softmax", name="risk_probs")(x)
    model = tf.keras.Model(inputs, outputs)

    # Treina com dados triviais para ter pesos válidos
    rng = np.random.default_rng(0)
    X = rng.random((200, 4)).astype(np.float32)
    # Regra simples: vermelho se days_to_expiry_norm < 0.05
    y = np.where(X[:, 0] < 0.05, 2, np.where(X[:, 0] < 0.1, 1, 0))
    y_oh = np.eye(3)[y].astype(np.float32)

    model.compile(optimizer="adam", loss="categorical_crossentropy")
    model.fit(X, y_oh, epochs=5, verbose=0)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()

    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_bytes(tflite_model)
    print(f"Placeholder salvo em: {OUTPUT_PATH} ({len(tflite_model)/1024:.1f} KB)")
    print("AVISO: este modelo não tem acurácia real — execute train_risk_model.py para produção.")

if __name__ == "__main__":
    main()
