# Educastock — Deploy no Google Cloud Run (passo a passo pelo site)

> Site de teste (temporario): https://web-929079196105.southamerica-east1.run.app

## O que cada parte faz

| Arquivo | Função |
|---|---|
| `functions/src/index.ts` | Servidor Express com 4 rotas HTTP (substituiu o Firebase Functions) |
| `functions/Dockerfile` | Receita para montar a imagem que roda no Cloud Run |
| Este guia | Passo a passo para subir pelo site do Google Cloud |

As 4 rotas disponíveis após o deploy:

| Rota | Disparada por | Horário |
|---|---|---|
| `POST /generate-expiry-alerts` | Cloud Scheduler | 07:00 todos os dias |
| `POST /generate-low-stock-alerts` | Cloud Scheduler | 07:10 todos os dias |
| `POST /audit-sensitive-changes` | Eventarc (Firestore) | A cada escrita em documents monitorados |
| `POST /notify-on-alert-created` | Eventarc (Firestore) | A cada novo alerta criado |
| `POST /send-weekly-report` | Cloud Scheduler | Conforme configurado pelo admin no app |

---

## PARTE 1 — Habilitar as APIs necessárias

1. Acesse [console.cloud.google.com](https://console.cloud.google.com) e selecione o projeto **educastock-20a98**
2. No menu lateral, vá em **APIs e Serviços → Biblioteca**
3. Pesquise e habilite uma por uma as seguintes APIs:
   - **Cloud Run Admin API**
   - **Cloud Scheduler API**
   - **Eventarc API**
   - **Artifact Registry API**
   - **Cloud Build API**
   - **Firebase Cloud Messaging API**

---

## PARTE 2 — Criar o repositório de imagens (Artifact Registry)

1. No menu lateral, vá em **Artifact Registry → Repositórios**
2. Clique em **+ Criar repositório**
3. Preencha:
   - **Nome:** `educastock`
   - **Formato:** `Docker`
   - **Modo:** `Padrão`
   - **Região:** `southamerica-east1 (São Paulo)`
4. Clique em **Criar**

---

## PARTE 3 — Fazer o build e enviar a imagem com Cloud Build

> Você não precisa ter Docker instalado no seu computador. O Cloud Build faz o build direto na nuvem usando o `Dockerfile` da pasta `functions/`.

1. No menu lateral, vá em **Cloud Build → Acionadores**
2. Clique em **Conectar repositório**
3. Escolha **GitHub** (ou outra fonte onde está o código), autentique e selecione o repositório **educastock**
4. Clique em **Criar acionador** e preencha:
   - **Nome:** `build-functions`
   - **Evento:** `Envio para um branch`
   - **Branch:** `^main$` (ou o branch que desejar)
   - **Tipo:** `Dockerfile`
   - **Diretório do Dockerfile:** `functions/`
   - **Imagem:** `southamerica-east1-docker.pkg.dev/educastock-20a98/educastock/functions:$COMMIT_SHA`
5. Clique em **Salvar**
6. Para rodar o build agora (sem precisar de push), clique nos **três pontos** ao lado do acionador → **Executar**

> Acompanhe o progresso em **Cloud Build → Histórico**. Quando aparecer ✅ verde, a imagem está no Artifact Registry.

---

## PARTE 4 — Criar a Service Account para o Cloud Run

> A Service Account é a "identidade" do serviço — ela precisa de permissão para acessar o Firestore e o FCM.

1. No menu lateral, vá em **IAM e Administrador → Contas de serviço**
2. Clique em **+ Criar conta de serviço**
3. Preencha:
   - **Nome:** `educastock-run`
   - **ID:** `educastock-run` (preenchido automaticamente)
4. Clique em **Criar e continuar**
5. Na seção **Conceder acesso**, adicione os 3 papéis abaixo (clique em **+ Adicionar outro papel** para cada um):
   - `Usuário do Cloud Datastore` *(acesso ao Firestore)*
   - `Agente de serviço do Firebase SDK Admin` *(permissões do Firebase)*
   - `Administrador do Firebase Cloud Messaging` *(envio de push)*
6. Clique em **Concluído**

---

## PARTE 5 — Fazer o deploy no Cloud Run

1. No menu lateral, vá em **Cloud Run**
2. Clique em **+ Criar serviço**
3. Em **Origem do contêiner**, selecione **Imagem de contêiner existente** e clique em **Selecionar**
   - Navegue até `educastock → functions` e selecione a imagem com a tag `latest` ou o commit mais recente
4. Preencha as configurações do serviço:
   - **Nome do serviço:** `educastock-functions`
   - **Região:** `southamerica-east1 (São Paulo)`
5. Em **Autenticação**, selecione **Exigir autenticação** *(NÃO marque "Permitir invocações não autenticadas")*
6. Expanda **Contêiner, variáveis e segredos, conexões, segurança** e configure:
   - **Porta do contêiner:** `8080`
   - **Memória:** `512 MiB`
   - **CPU:** `1`
   - **Tempo limite das solicitações:** `120 segundos`
   - **Instâncias mínimas:** `0`
   - **Variáveis de ambiente** *(para envio de e-mail do relatório semanal)*:
     - `SMTP_HOST` → ex: `smtp.gmail.com`
     - `SMTP_PORT` → ex: `587`
     - `SMTP_USER` → e-mail remetente (ex: `educastock@gmail.com`)
     - `SMTP_PASS` → senha de app do Gmail (ou senha do SMTP)
     - `SMTP_SENDER_NAME` → ex: `EducaStock`
   - **Instâncias máximas:** `5`
7. Em **Segurança → Conta de serviço**, selecione `educastock-run`
8. Clique em **Criar**

> Após o deploy, o Cloud Run exibe a **URL do serviço** (algo como `https://educastock-functions-xxxx-uc.a.run.app`). **Anote essa URL**, você vai precisar nos próximos passos.

---

## PARTE 5B — Deploy do site Flutter web no Cloud Run

> Faça isso **depois** que o Cloud Build terminar o build dos 2 serviços (functions + web).

1. No menu lateral, vá em **Cloud Run**
2. Clique em **+ Criar serviço**
3. Em **Origem do contêiner**, selecione **Imagem de contêiner existente** e clique em **Selecionar**
   - Navegue até `educastock → web` e selecione a imagem com a tag `latest`
4. Preencha as configurações do serviço:
   - **Nome do serviço:** `educastock-web`
   - **Região:** `southamerica-east1 (São Paulo)`
5. Em **Autenticação**, selecione **✅ Permitir invocações não autenticadas** *(o site precisa ser público)*
6. Expanda **Contêiner, variáveis e segredos, conexões, segurança** e configure:
   - **Porta do contêiner:** `8080`
   - **Memória:** `256 MiB`
   - **CPU:** `1`
   - **Instâncias mínimas:** `0`
   - **Instâncias máximas:** `3`
7. Em **Segurança → Conta de serviço**, pode deixar a conta padrão
8. Clique em **Criar**

> O site ficará disponível em uma URL como `https://educastock-web-xxxx.run.app` — essa é a URL do seu app Flutter web!

---

## PARTE 6 — Criar a Service Account para o Cloud Scheduler

1. No menu lateral, vá em **IAM e Administrador → Contas de serviço**
2. Clique em **+ Criar conta de serviço**
3. Preencha:
   - **Nome:** `educastock-scheduler`
   - **ID:** `educastock-scheduler`
4. Clique em **Criar e continuar** → **Concluído** (sem papéis por enquanto)
5. Agora vá em **Cloud Run → educastock-functions**
6. Clique na aba **Segurança** → **+ Adicionar principal**
7. Em **Novos principais**, digite: `educastock-scheduler@educastock-20a98.iam.gserviceaccount.com`
8. Em **Papel**, selecione `Invocador do Cloud Run`
9. Clique em **Salvar**

---

## PARTE 7 — Criar os jobs no Cloud Scheduler

### Job 1 — Alertas de vencimento (07:00)

1. No menu lateral, vá em **Cloud Scheduler**
2. Clique em **+ Criar job**
3. Preencha:
   - **Nome:** `generate-expiry-alerts`
   - **Região:** `southamerica-east1`
   - **Frequência:** `0 7 * * *`
   - **Fuso horário:** `America/Sao_Paulo (BRT)`
4. Clique em **Continuar** e preencha:
   - **Destino:** `HTTP`
   - **URL:** `https://SUA-URL-AQUI/generate-expiry-alerts`
   - **Método HTTP:** `POST`
   - **Cabeçalho:** clique em **+ Adicionar cabeçalho** → Chave: `Content-Type` / Valor: `application/json`
   - **Corpo:** `{}`
5. Em **Auth header**, selecione `Adicionar token OIDC`
   - **Conta de serviço:** `educastock-scheduler@educastock-20a98.iam.gserviceaccount.com`
   - **Público:** deixe igual à URL
6. Clique em **Criar**

### Job 2 — Alertas de estoque baixo (07:10)

Repita os mesmos passos do Job 1, mudando apenas:
- **Nome:** `generate-low-stock-alerts`
- **Frequência:** `10 7 * * *`
- **URL:** `https://SUA-URL-AQUI/generate-low-stock-alerts`

### Job 3 — Relatório semanal por e-mail

Repita os mesmos passos do Job 1, mudando apenas:
- **Nome:** `send-weekly-report`
- **Frequência:** `0 8 * * 1` *(toda segunda-feira às 08:00 — ajuste conforme a configuração do admin)*
- **URL:** `https://SUA-URL-AQUI/send-weekly-report`

> **Obs:** A frequência real é configurada pelo admin no app (Relatórios → Agendar relatório). O Scheduler deve ter uma frequência genérica; o endpoint verifica o Firestore e pula se não for o dia correto — ou configure o job exatamente no horário/dia que o admin escolheu.

---

## PARTE 8 — Criar os triggers do Eventarc

> Os triggers do Eventarc fazem o Cloud Run ser chamado automaticamente quando algo muda no Firestore.

### Trigger 1 — Auditoria de mudanças

1. No menu lateral, vá em **Eventarc → Triggers**
2. Clique em **+ Criar trigger**
3. Preencha:
   - **Nome:** `audit-sensitive-changes`
   - **Provedor de eventos:** `Cloud Firestore`
   - **Tipo de evento:** `google.cloud.firestore.document.v1.written` *(documento escrito/atualizado/deletado)*
   - **Banco de dados:** `(default)`
   - **Padrão de documento:** `**` *(qualquer documento — o código filtra internamente)*
   - **Região:** `southamerica-east1`
4. Em **Destino do evento**:
   - **Tipo:** `Cloud Run`
   - **Serviço Cloud Run:** `educastock-functions`
   - **Caminho URL do serviço:** `/audit-sensitive-changes`
5. Em **Conta de serviço**, selecione `educastock-run`
6. Clique em **Criar**

### Trigger 2 — Notificação push ao criar alerta

Repita os mesmos passos do Trigger 1, mudando apenas:
- **Nome:** `notify-on-alert-created`
- **Tipo de evento:** `google.cloud.firestore.document.v1.created` *(documento criado)*
- **Padrão de documento:** `alerts/{alertId}`
- **Caminho URL do serviço:** `/notify-on-alert-created`

---

## PARTE 9 — Testar se está funcionando

1. No menu lateral, vá em **Cloud Scheduler**
2. Clique nos **três pontos** ao lado de `generate-expiry-alerts` → **Forçar execução**
3. Verifique o resultado em **Cloud Run → educastock-functions → Logs**
   - Você deve ver a requisição chegando e a resposta `{"success":true}`
4. Para verificar os alertas criados, acesse o **Firestore** e olhe a coleção `alerts`

---

## PARTE 10 — Atualizar o serviço (nova versão do código)

Quando fizer alterações no código:

1. Faça push para o branch configurado no Cloud Build — ele cria a nova imagem automaticamente
2. Vá em **Cloud Run → educastock-functions → Editar e fazer o deploy de uma nova revisão**
3. Em **Imagem do contêiner**, clique em **Selecionar** e escolha a imagem com o novo tag
4. Clique em **Implantar**

---

## Estrutura dos arquivos

```
functions/
├── src/
│   └── index.ts      ← servidor Express (5 rotas HTTP)
├── Dockerfile        ← build multi-stage Node 20 (usado pelo Cloud Build)
├── .dockerignore
├── package.json      ← express + firebase-admin
└── tsconfig.json
```
