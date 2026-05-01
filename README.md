# EducaStock 📦

Sistema de Gestão de Estoque para a ONG **Casa da Criança** — desenvolvido como Projeto Integrador do curso de **Desenvolvimento de Software Multiplataforma** da Fatec Itapira.

## Equipe

| Nome | Função |
|---|---|
| Marco Aurelio Bubola | Dev Full-Stack / Arquitetura Firebase |
| Cauã Lima | Dev Mobile Flutter / Scanner & OCR |
| Letícia | Dev Mobile Flutter / Relatórios & Aprovações |
| Guilherme | Dev Full-Stack / Cloud Functions & ML |

## Sobre o Projeto

O **EducaStock** digitaliza e automatiza o controle de doações e suprimentos da ONG, substituindo planilhas manuais por um aplicativo multiplataforma com:

- 📷 **Leitura de código de barras** e **OCR de validade** (Google ML Kit)
- 🔄 **Política FEFO** obrigatória nas saídas (First Expired, First Out)
- 🔔 **Notificações push** de vencimento e baixo estoque (Firebase Messaging)
- 🤖 **Machine Learning** — classificação de risco de vencimento (Verde/Amarelo/Vermelho)
- 📊 **Relatórios exportáveis** em PDF e Excel
- ✅ **Fluxo de aprovação** para ajustes negativos acima de limite
- 🌐 **Modo offline** com sincronização automática

## Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| App | Flutter 3.x (Dart) — Android, iOS, Web |
| Estado | Riverpod 2 |
| Navegação | GoRouter |
| Backend | Firebase (Firestore, Auth, Storage, Functions) |
| Push | Firebase Cloud Messaging (FCM) |
| ML | scikit-learn → TFLite (via `tflite_flutter`) |
| CI/CD | GitHub Actions |
| Relatórios | `pdf` + `printing` (Dart) |

## Módulo de Machine Learning

O modelo de **Random Forest** classifica cada lote em:

- 🟢 **Verde** — seguro (dias até vencimento OK, saída regular)
- 🟡 **Amarelo** — atenção (vencimento se aproximando ou estoque baixo)
- 🔴 **Vermelho** — crítico (vencimento iminente, risco de perda)

Treinamento em Python/scikit-learn → conversão para TFLite → inferência local no dispositivo (funciona offline).

## Documentação Acadêmica

Os documentos abaixo estão em [`docs/`](docs/) no padrão ABNT:

| Arquivo | Conteúdo |
|---|---|
| [Relatorio_PI_EducaStock.docx](docs/Relatorio_PI_EducaStock.docx) | Relatório principal: objetivos, requisitos, histórias de usuário, arquitetura e cronograma |
| [Relatorio_ML_EducaStock.docx](docs/Relatorio_ML_EducaStock.docx) | Estudo de viabilidade, bibliotecas Flutter/ML, modelo de IA e diagrama de fluxo |
| [Roteiro_Pitch_EducaStock.docx](docs/Roteiro_Pitch_EducaStock.docx) | Roteiro do pitch de 2 min 30 s para apresentação do PI |

## Como Executar

```bash
# Instalar dependências
flutter pub get

# Executar no Android/iOS (DEV)
flutter run --dart-define=APP_ENV=dev

# Executar no Android/iOS (HML)
flutter run --dart-define=APP_ENV=hml

# Executar no Android/iOS (PROD)
flutter run --dart-define=APP_ENV=prod

# Executar na Web (DEV)
flutter run -d chrome --dart-define=APP_ENV=dev

# Executar na Web (PROD + App Check)
flutter run -d chrome \
  --dart-define=APP_ENV=prod \
  --dart-define=APP_CHECK_WEB_RECAPTCHA_KEY=SEU_SITE_KEY

# Gerar APK de release por ambiente
flutter build apk --release --dart-define=APP_ENV=dev
flutter build apk --release --dart-define=APP_ENV=hml
flutter build apk --release --dart-define=APP_ENV=prod
```

## Estrutura Principal

```
lib/
  core/          # Design system, tema, roteamento, utilitários
  features/      # Módulos: auth, products, batches, stock, alerts,
                 #          reports, scanner, audit, dashboard, ML
  infra/         # Repositórios Firebase, providers Riverpod
functions/       # Cloud Functions TypeScript (alertas agendados, ML server-side)
docs/            # Documentação acadêmica (Word ABNT)
```


## Cronograma

| Sprint | Período | Entrega |
|---|---|---|
| S1 | Mar/2026 Sem 1-2 | Setup, autenticação, design system |
| S2 | Mar/2026 Sem 3-4 | CRUD produtos/lotes, scanner, OCR |
| S3 | Abr/2026 Sem 1-2 | FEFO, movimentações, aprovação de ajuste |
| S4 | Abr/2026 Sem 3-4 | Cloud Functions, alertas, push notifications |
| S5 | Mai/2026 Sem 1-2 | Relatórios PDF/Excel, filtros, offline/sync |
| S6 | Mai/2026 Sem 3-4 | Módulo ML: treinamento + integração TFLite |
| S7 | Jun/2026 Sem 1-2 | Testes, segurança, CI/CD |
| S8 | Jun/2026 Sem 3-4 | **Deploy PROD + Pitch (30/06/2026)** |

---

> Projeto Integrador — Fatec Itapira — Curso DSM — 2026
