# Guia completo: Deploy no Cloud Run com GitHub (pelo site, sem terminal)

Este guia foi feito para o projeto da Casa da Crianca (EducaStock), com foco em fazer tudo pelo navegador, sem comandos.

## Objetivo

Voce vai:

1. Criar e configurar o projeto no Google Cloud.
2. Conectar o repositorio no GitHub ao Google Cloud.
3. Criar o servico no Cloud Run.
4. Ativar deploy continuo por branch (CI/CD).
5. Publicar com dominio e SSL.

## Decisao rapida para o seu caso

Para o codigo atual deste projeto, siga esta regra simples:

1. Se voce quer publicar o backend atual em `functions/src/index.ts` (gatilhos Firestore e agendamentos), use Firebase Functions (2nd gen).
2. Nao use a tela de servico HTTP do Cloud Run para esse codigo, porque ele nao e um servidor Web na porta 8080.
3. So use Cloud Run (servico) quando voce tiver uma API HTTP dedicada (Express/Fastify) rodando como servidor.

Resumo pratico:

1. Codigo atual: Firebase Functions (recomendado).
2. Cloud Run Service: apenas para API HTTP.

---

## 1) Pre-requisitos

Antes de comecar, garanta que voce tem:

1. Conta Google com acesso ao Google Cloud.
2. Conta no GitHub com permissao de administrador no repositorio.
3. Billing (faturamento) ativo no projeto Google Cloud.
4. Repositorio com uma aplicacao pronta para container (Dockerfile) ou que rode com Buildpacks.

---

## 2) Criar projeto no Google Cloud

1. Abra o Console do Google Cloud.
2. No topo, clique no seletor de projeto.
3. Clique em Novo projeto.
4. Nome sugerido: educastock-prod (ou outro padrao seu).
5. Clique em Criar.
6. Entre em Billing e vincule a conta de faturamento ao projeto.

Dica:
Use 1 projeto por ambiente (ex.: dev, hml, prod) para separar dados e risco.

---

## 3) Ativar APIs necessarias (pela interface)

No menu lateral:

1. APIs e servicos > Biblioteca.
2. Ative as APIs abaixo:
   - Cloud Run Admin API
   - Cloud Build API
   - Artifact Registry API
   - Secret Manager API (recomendado)
   - Cloud Logging API (normalmente ja vem)

Observacao:
Sem essas APIs, o fluxo de build/deploy pode falhar.

---

## 4) Preparar IAM e seguranca

No menu lateral:

1. IAM e Admin > IAM.
2. Confirme seu usuario com papel suficiente (Owner ou combinado de Admins).
3. Evite usar conta pessoal para execucao em producao.

Recomendacao de boas praticas:

1. Crie uma service account para o runtime da aplicacao.
2. Dê apenas papeis minimos necessarios.
3. Salve segredos no Secret Manager (nao em variavel aberta).

---

## 5) Conectar GitHub ao Google Cloud (via Cloud Run)

### Caminho principal (mais simples)

1. Va em Cloud Run.
2. Clique em Criar servico.
3. Escolha a opcao de codigo-fonte/repositorio (nao imagem pronta).
4. Clique em Configurar deploy continuo ou Conectar repositorio (nome pode variar).
5. Escolha GitHub.
6. Autorize o Google Cloud/Cloud Build no GitHub.
7. Selecione organizacao, repositorio e branch principal (ex.: main).
8. Defina o gatilho para novas revisoes automaticas ao fazer push na branch.

Se aparecer tela de permissao no GitHub:

1. Instale o app solicitado apenas no repositorio desejado (mais seguro).
2. Volte ao Cloud e conclua a conexao.

---

## 6) Criar o servico Cloud Run

Ainda no assistente de criacao:

1. Nome do servico: educastock-api (exemplo).
2. Regiao: escolha a mais proxima dos usuarios (ex.: southamerica-east1 para Brasil).
3. Plataforma: Cloud Run totalmente gerenciado.
4. Build:
   - Se tiver Dockerfile, selecione Dockerfile.
   - Se nao tiver Dockerfile, use Buildpacks (detecao automatica).
5. Porta:
   - Configure a porta esperada pela app (geralmente 8080).

### Sem Dockerfile: o que preencher nessa tela

Se voce escolher Buildpacks (opcao sem Dockerfile), use assim:

1. Branch: `^main$` (ou a branch que voce usa para deploy).
2. Tipo de build: Buildpacks.
3. Diretorio de contexto de build:
   - Se o repositorio abre direto na pasta da API: `/`
   - Se a API esta dentro de subpasta (seu caso): `educastock/functions`
4. Ponto de entrada:
   - Deixe em branco se seu projeto tiver script de start padrao compativel.
   - Preencha somente se voce tiver comando de inicio explicito do servidor HTTP.
5. Destino da funcao:
   - Deixe em branco para aplicacao Web/HTTP server.
   - Preencha so quando estiver publicando uma unica funcao suportada no modo de funcoes por codigo-fonte.

Atencao para o seu projeto atual:

1. O codigo em `functions/src/index.ts` usa gatilhos Firebase (Firestore/Scheduler), nao um servidor HTTP convencional.
2. Para esse codigo, o caminho mais correto e publicar como Firebase Functions (2nd gen), nao como servico HTTP unico no Cloud Run.
3. Se voce realmente quiser Cloud Run, crie uma API HTTP dedicada (ex.: Express/Fastify) na pasta da API e entao use Buildpacks nessa pasta.

### Configuracoes importantes

1. Autenticacao:
   - Publico (Allow unauthenticated) se for API aberta/site publico.
   - Privado (Require authentication) para APIs internas.
2. Escalabilidade:
   - Min instances: 0 para economizar.
   - Max instances: defina limite para controlar custo.
3. CPU e memoria:
   - Comece pequeno (ex.: 1 vCPU e 512MB/1GB) e ajuste por uso.
4. Timeout:
   - Ajuste conforme suas rotas (evite timeout muito baixo).
5. Concorrencia:
   - Para APIs leves, concorrencia maior reduz custo.
   - Para tarefas pesadas, concorrencia menor melhora estabilidade.

---

## 7) Variaveis e segredos

Durante criacao/edicao do servico:

1. Abra Variaveis e segredos.
2. Variaveis simples (nao sensiveis): ambiente, flags etc.
3. Segredos: use Secret Manager para chaves, tokens, credenciais.
4. Associe cada segredo com versao (recomendado: latest inicialmente).

Exemplos de configuracao:

- APP_ENV=production
- FIREBASE_PROJECT_ID=seu-projeto
- JWT_SECRET via Secret Manager

---

## 8) Deploy inicial e validacao

1. Clique em Criar/Implantar.
2. Acompanhe build e deploy no painel.
3. Ao finalizar, abra a URL gerada do Cloud Run.
4. Teste endpoint de saude (health) e rotas principais.

Checklist rapido de validacao:

1. Servico responde sem erro 500.
2. Logs nao mostram erro de credencial.
3. Conexao com banco/Firestore funcionando.
4. CORS configurado se frontend estiver em dominio diferente.

---

## 9) CI/CD com GitHub (deploy automatico)

Depois do servico criado com repositorio conectado:

1. Verifique em Cloud Build/Cloud Deploy trigger associado ao repo.
2. Confirme branch monitorada (ex.: main).
3. Confirme estrategia:
   - Push em main gera nova revisao automatica.
4. Opcional: criar strategy por ambiente:
   - develop -> dev
   - release/hml -> homologacao
   - main -> producao

Boas praticas:

1. Exigir Pull Request antes de merge em main.
2. Proteger branch main no GitHub.
3. Ativar checks obrigatorios antes de merge.

---

## 10) Dominio customizado e HTTPS

1. No Cloud Run, abra o servico.
2. Clique em Gerenciar dominios personalizados.
3. Adicione seu dominio.
4. Siga os registros DNS solicitados (normalmente CNAME/A/AAAA).
5. Aguarde emissao do certificado SSL gerenciado.

Observacao:
A propagacao DNS pode levar minutos ou horas.

---

## 11) Monitoramento e operacao

No Google Cloud:

1. Logging > Logs Explorer para erros e stack trace.
2. Monitoring > Dashboards para latencia, CPU, memoria.
3. Alertas:
   - taxa de erro 5xx
   - latencia alta
   - picos de custo

No ciclo diario:

1. Acompanhe revisoes novas apos cada merge.
2. Em falha, faca rollback para revisao anterior no Cloud Run.
3. Mantenha segredos rotacionados periodicamente.

---

## 12) Rollback rapido (pelo site)

1. Cloud Run > Servico > Revisoes.
2. Selecione revisao estavel anterior.
3. Direcione trafego para ela (100%).
4. Monitore logs e disponibilidade.

---

## Erros comuns e como evitar

1. Erro de permissao no build
   - Revisar IAM do Cloud Build e service account.
2. App sobe mas nao responde
   - Porta incorreta ou app nao ouvindo na porta esperada.
3. Falha em segredo/credencial
   - Segredo nao vinculado ao servico ou versao invalida.
4. Deploy nao dispara no push
   - Trigger/branch incorreta ou repositorio desconectado.

---

## Arquitetura recomendada para o EducaStock

1. Frontend web: Firebase Hosting.
2. API/backend: Cloud Run.
3. Banco e autenticacao: Firestore + Firebase Auth.
4. Arquivos: Cloud Storage.
5. Segredos: Secret Manager.
6. Monitoramento: Cloud Logging + Cloud Monitoring.

Assim voce ganha escalabilidade automatica, menor manutencao e deploy continuo com GitHub sem depender de terminal.

---

## Checklist final (resumo)

1. Projeto + billing ativos.
2. APIs Cloud Run/Build/Artifact Registry ativadas.
3. GitHub conectado no assistente do Cloud Run.
4. Servico criado com regiao correta e seguranca definida.
5. Variaveis e segredos configurados.
6. Deploy inicial validado pela URL.
7. Deploy continuo por branch funcionando.
8. Dominio + SSL configurados.
9. Alertas e logs monitorados.

Pronto. Com isso, seu fluxo fica profissional e repetivel: merge no GitHub, deploy automatico no Cloud Run.
