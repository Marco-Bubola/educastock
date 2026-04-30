# Prompt de Modernizacao do EducaStock

Transforme o EducaStock em um app Flutter moderno, confiavel e pronto para operacao real da ONG Casa da Crianca.

## Objetivo do produto

Criar uma experiencia de estoque clara, rapida e profissional, com foco em:

- cadastro e consulta de produtos e lotes
- controle de entradas, saidas e ajustes
- alertas de estoque baixo e vencimento
- autenticacao segura com e-mail, Google e perfis de acesso
- visual moderno, calor humano e leitura rapida em celular e web

## Direcao visual

- identidade limpa, institucional e atual
- linguagem visual baseada em azul profundo, azul vivo, branco e fundos suaves
- evitar telas vazias e blocos genericos sem hierarquia
- usar cards com boa respiracao, contrastes claros e titulos fortes
- formularios com aparencia premium, foco em legibilidade e validacao clara
- dashboards com metricas, chips de status e secoes bem segmentadas
- responsividade real para mobile, tablet e web

## Telas prioritarias

1. Login moderno com Google, e-mail e recuperacao de senha
2. Cadastro de conta moderno com validacoes
3. Dashboard com cards executivos, alertas e acoes rapidas
4. Lista de produtos com busca, filtros, categorias e estado vazio forte
5. Detalhe do produto com historico, lotes e acoes principais
6. Cadastro e edicao de produto com UX simples e segura
7. Cadastro de lote com campos condicionais e datas claras
8. Movimentacao de estoque com contexto do lote e confirmacao visual
9. Alertas com destaque para criticidade e acao imediata
10. Relatorios com graficos e resumo executivo
11. Configuracoes com perfil, preferencias e controle de sessao

## Requisitos funcionais

- login por e-mail e senha com Firebase Auth
- login com Google
- cadastro de conta com criacao de documento do usuario no Firestore
- redefinicao de senha
- persistencia do perfil no Firestore com roles: admin, estoquista, voluntario, consulta
- protecao de rotas por autenticacao
- registrar token FCM por usuario e dispositivo
- mostrar notificacoes de estoque baixo, vencimento e eventos criticos
- logs de auditoria para alteracoes sensiveis

## Firebase

- usar firebase_options.dart gerado pelo FlutterFire
- Firestore como origem de verdade para users, products, batches, stock_movements e alerts
- Authentication com e-mail/senha e Google
- Messaging para push notifications
- Crashlytics para erros em producao
- Analytics para eventos principais da jornada

## Padrões tecnicos

- Riverpod para estado e regras de leitura/escrita
- GoRouter para navegacao
- componentes reutilizaveis para auth, cards, estados vazios, filtros e cabecalhos
- evitar logica de negocio dentro das telas
- feedback de erro e sucesso com snackbars e estados de loading
- estados vazios com mensagem orientada a acao

## Qualidade esperada

- sem erros de compilacao
- warnings reduzidos ao minimo necessario
- fluxo de login e cadastro funcionando em web e mobile
- telas sem dependencias visuais quebradas
- app utilizavel mesmo sem dados iniciais, com empty states consistentes

## Entregaveis esperados

- auth completo e moderno
- dashboard redesenhado
- CRUD principal de produtos e lotes funcional
- notificacoes preparadas
- tema visual consistente em todo o app
- base pronta para receber icone, splash e refinamentos finais