# Instruções de Machine Learning — EducaStock

## 1. Visão Geral
O EducaStock possui um módulo de ML para classificar o risco de vencimento de lotes (Verde/Amarelo/Vermelho) usando:
- Classificador por regras (todas as plataformas)
- Modelo TFLite (Random Forest destilado para rede neural, Android/iOS/desktop)

## 2. Como funciona
- O app usa o classificador por regras como baseline e fallback.
- Em Android/iOS/desktop, se o arquivo `assets/models/expiry_risk.tflite` existir e o pacote `tflite_flutter` estiver instalado, o app pode usar inferência real via TFLite.
- No web, sempre usa o classificador por regras.

## 3. Treinando e atualizando o modelo

### a) Pré-requisitos
- Python 3.10+
- Instale as dependências:
  ```bash
  pip install -r scripts/ml/requirements.txt
  ```

### b) Treinar o modelo e exportar para TFLite
  ```bash
  python scripts/ml/train_risk_model.py
  ```
- O modelo será salvo em `assets/models/expiry_risk.tflite`.
- Metadados em `assets/models/expiry_risk_meta.json`.

### c) Gerar modelo placeholder (para dev)
  ```bash
  python scripts/ml/generate_placeholder_model.py
  ```

## 4. Ativando inferência real no Flutter
- Adicione ao `pubspec.yaml` (apenas para Android/iOS/desktop):
  ```yaml
  dependencies:
    tflite_flutter: ^0.11.0
  ```
- Implemente a classe real em `lib/features/ml/data/repositories/tflite_risk_classifier.dart` usando o exemplo de `scripts/ml/tflite_risk_classifier_impl.dart` (se existir).
- Rode `flutter pub get`.

## 5. Testando
- Use a página de insights ML no app para ver a classificação dos lotes.
- O badge indica se está usando TFLite ou regras.

## 6. Dicas e troubleshooting
- Se o modelo não carregar, o app usa fallback por regras automaticamente.
- Para atualizar o modelo, basta sobrescrever o arquivo `.tflite` e reiniciar o app.
- Para dúvidas, consulte os scripts Python e a documentação acadêmica em `docs/`.

---

**Contato:**
- Dúvidas técnicas: abra uma issue ou consulte o README.
- Para contribuir com o modelo, edite os scripts em `scripts/ml/`.
