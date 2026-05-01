"""
train_risk_model.py
===================
Treina um modelo Random Forest para classificar risco de vencimento de lotes
do EducaStock e exporta para TFLite.

Saída: ../../assets/models/expiry_risk.tflite

Requisitos: pip install -r requirements.txt

Features (4 entradas normalizadas para [0,1]):
  0 - days_to_expiry_norm   : dias até vencimento / 365  (1.0 = sem validade)
  1 - quantity_ratio         : qtd_atual / qtd_inicial
  2 - days_since_entry_norm  : dias em estoque / 365
  3 - is_no_expiry           : 1 se sem validade, 0 se perecível

Labels:
  0 - Verde    (seguro)
  1 - Amarelo  (atenção)
  2 - Vermelho (crítico — risco de perda)
"""

import os
import sys
import json
import pathlib
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import tensorflow as tf

# ---------------------------------------------------------------------------
# Configuração
# ---------------------------------------------------------------------------
ASSETS_DIR = pathlib.Path(__file__).parent.parent.parent / "assets" / "models"
OUTPUT_PATH = ASSETS_DIR / "expiry_risk.tflite"
RANDOM_SEED = 42
N_ESTIMATORS = 100
MAX_DAYS = 365.0

# ---------------------------------------------------------------------------
# Geração de dados sintéticos
# ---------------------------------------------------------------------------

def generate_dataset(n_samples: int = 5000) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(RANDOM_SEED)

    X = []
    y = []

    for _ in range(n_samples):
        is_no_expiry = rng.choice([0.0, 1.0], p=[0.7, 0.3])

        if is_no_expiry:
            days_to_expiry_norm = 1.0
        else:
            days_to_expiry = rng.integers(0, MAX_DAYS + 1)
            days_to_expiry_norm = float(days_to_expiry) / MAX_DAYS

        quantity_ratio = float(rng.uniform(0.05, 1.0))
        days_since_entry_norm = float(rng.uniform(0.0, 1.0))

        features = [days_to_expiry_norm, quantity_ratio, days_since_entry_norm, is_no_expiry]

        # Determina label (mesmas regras do RuleBasedRiskClassifier)
        if is_no_expiry:
            label = 0  # verde
        else:
            days = int(days_to_expiry_norm * MAX_DAYS)
            if days <= 0:
                label = 2  # vermelho — vencido
            elif days <= 7:
                label = 2  # vermelho — crítico
            elif days <= 30:
                # Lento e pouco movido → vermelho, senão amarelo
                if quantity_ratio > 0.8 and days <= 20:
                    label = 2
                else:
                    label = 1  # amarelo
            else:
                # Verde com possível lentidão
                stale = days_since_entry_norm > (60 / MAX_DAYS) and quantity_ratio > 0.8
                if stale and days <= 90:
                    label = 1  # amarelo
                else:
                    label = 0  # verde

        # Adiciona ruído realista (~5% dos exemplos)
        if rng.random() < 0.05:
            label = rng.integers(0, 3)

        X.append(features)
        y.append(label)

    return np.array(X, dtype=np.float32), np.array(y, dtype=np.int32)


# ---------------------------------------------------------------------------
# Treino
# ---------------------------------------------------------------------------

def train(X: np.ndarray, y: np.ndarray) -> RandomForestClassifier:
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=RANDOM_SEED, stratify=y
    )
    clf = RandomForestClassifier(
        n_estimators=N_ESTIMATORS,
        max_depth=8,
        random_state=RANDOM_SEED,
        n_jobs=-1,
    )
    clf.fit(X_train, y_train)

    y_pred = clf.predict(X_test)
    print("\n=== Relatório de Classificação ===")
    print(classification_report(y_test, y_pred, target_names=["verde", "amarelo", "vermelho"]))

    acc = (y_pred == y_test).mean()
    print(f"Acurácia no conjunto de teste: {acc:.4f}\n")
    return clf


# ---------------------------------------------------------------------------
# Conversão para TFLite via TF SavedModel
# ---------------------------------------------------------------------------

def export_tflite(clf: RandomForestClassifier) -> None:
    # Cria rede neural equivalente simples usando os predict_proba do RF
    # Encapsula em uma tf.function para converter ao TFLite

    # Captura as árvores via predict_proba (sklearn → numpy → TF literal)
    # Estratégia: exportar uma rede densa treinada sobre as predições do RF
    # para manter compatibilidade total com o TFLite runtime.

    print("Gerando modelo TF a partir das probabilidades do RF...")

    # Dataset de destilação: todas as probabilidades do RF
    n_distil = 10_000
    rng = np.random.default_rng(RANDOM_SEED + 1)
    X_distil = rng.random((n_distil, 4)).astype(np.float32)
    X_distil[:, 3] = (rng.random(n_distil) > 0.7).astype(np.float32)  # ~30% sem validade
    y_soft = clf.predict_proba(X_distil).astype(np.float32)

    # Rede pequena: 4 → 32 → 16 → 3 com softmax
    inputs = tf.keras.Input(shape=(4,), name="features")
    x = tf.keras.layers.Dense(32, activation="relu")(inputs)
    x = tf.keras.layers.Dense(16, activation="relu")(x)
    outputs = tf.keras.layers.Dense(3, activation="softmax", name="risk_probs")(x)

    model = tf.keras.Model(inputs, outputs)
    model.compile(optimizer="adam", loss="categorical_crossentropy", metrics=["accuracy"])

    model.fit(X_distil, y_soft, epochs=60, batch_size=64, verbose=0,
              validation_split=0.1)

    print("Treinamento de destilação concluído.")

    # Converte para TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_bytes(tflite_model)
    print(f"\nModelo TFLite salvo em: {OUTPUT_PATH}")
    print(f"Tamanho: {len(tflite_model) / 1024:.1f} KB")


# ---------------------------------------------------------------------------
# Salva metadados do modelo
# ---------------------------------------------------------------------------

def save_metadata(clf: RandomForestClassifier) -> None:
    meta = {
        "features": [
            "days_to_expiry_norm",
            "quantity_ratio",
            "days_since_entry_norm",
            "is_no_expiry",
        ],
        "labels": ["verde", "amarelo", "vermelho"],
        "model_type": "random_forest_distilled",
        "n_estimators": clf.n_estimators,
        "input_shape": [1, 4],
        "output_shape": [1, 3],
    }
    meta_path = ASSETS_DIR / "expiry_risk_meta.json"
    meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False))
    print(f"Metadados salvos em: {meta_path}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("=== EducaStock — Treinamento do Modelo de Risco ===\n")
    print("Gerando dataset sintético...")
    X, y = generate_dataset(n_samples=6000)
    print(f"  Total de amostras: {len(X)}")
    print(f"  Distribuição: {dict(zip(*np.unique(y, return_counts=True)))}\n")

    print("Treinando Random Forest...")
    clf = train(X, y)

    print("Exportando para TFLite via destilação...")
    export_tflite(clf)

    save_metadata(clf)
    print("\n✓ Processo concluído. Arquivo pronto para uso no Flutter.")
