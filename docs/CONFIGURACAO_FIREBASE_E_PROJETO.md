# Configuração Firebase e Projeto (EducaStock)

Este guia reúne tudo o que precisa ser configurado no Firebase e no projeto para o app funcionar corretamente em desenvolvimento, homologação e produção.

## 1) Pré-requisitos locais

- Flutter e Dart instalados.
- Firebase CLI instalado e logado:
  - `npm i -g firebase-tools`
  - `firebase login`
- FlutterFire CLI instalado:
  - `dart pub global activate flutterfire_cli`
- Node.js 20 instalado (Functions usa `"engines": { "node": "20" }`).
- Android Studio/SDK e, se for usar iOS, Xcode/CocoaPods.

## 2) Projeto Firebase no Console

No Firebase Console, valide/crie:

- Projeto Firebase (atualmente configurado como `educastock-20a98`).
- Apps registradas:
  - Android: `br.org.casadacrianca.educastock`
  - iOS: `br.org.casadacrianca.educastock`
  - Web
- Serviços habilitados:
  - Authentication
  - Firestore Database
  - Storage
  - Cloud Messaging (FCM)
  - Crashlytics
  - Analytics
  - App Check

## 3) Authentication

Habilitar em Authentication > Sign-in method:

- Email/Senha
- Google

Importante para Google Sign-In:

- Android: cadastrar SHA-1 e SHA-256 do app no Firebase (debug e release).
- Web: configurar domínio autorizado em Authentication (localhost e domínio de produção).

## 4) Firestore

- Criar banco em modo Native.
- Preferir região próxima do público (ex.: `southamerica-east1`), alinhando com Functions.
- Publicar regras e índices:
  - `firebase deploy --only firestore:rules,firestore:indexes`

Arquivos já existentes no projeto:

- `firestore.rules`
- `firestore.indexes.json`

## 5) Storage

- Habilitar Cloud Storage no projeto Firebase.
- Publicar regras:
  - `firebase deploy --only storage`

Arquivo já existente:

- `storage.rules`

## 6) Cloud Functions (TypeScript)

Funções já implementadas com gatilhos Firestore e agendamentos (Scheduler).

Passos:

1. Instalar dependências:
   - `cd functions`
   - `npm install`
2. Build:
   - `npm run build`
3. Deploy:
   - `firebase deploy --only functions`

Pré-requisitos de produção:

- Plano Blaze (necessário para recursos como Scheduler/uso em produção com cobranças).
- APIs do Google Cloud habilitadas automaticamente pelo deploy quando solicitado.
- Região usada no código: `southamerica-east1`.

Arquivo-chave:

- `functions/src/index.ts`

## 7) App Check

O app ativa App Check no bootstrap:

- Android em produção: `playIntegrity`
- Apple em produção: `appAttestWithDeviceCheckFallback`
- Dev/HML: modo `debug`

No Firebase Console:

- Registrar App Check para Android/iOS/Web.
- Em Web, usar chave reCAPTCHA v3 e rodar com:
  - `--dart-define=APP_CHECK_WEB_RECAPTCHA_KEY=SUA_CHAVE`

Arquivo-chave:

- `lib/core/firebase/firebase_bootstrap.dart`

## 8) Push Notifications (FCM)

O app salva tokens na coleção `device_tokens` e reage a notificações.

Configurar:

- Android: app registrada no Firebase + `google-services.json` correto.
- iOS: configurar APNs no Apple Developer e enviar chave/certificado no Firebase.
- Web: configurar Web Push (VAPID) se for usar notificações web.

Arquivos/trechos envolvidos:

- `lib/core/notifications/push_notification_service.dart`
- `functions/src/index.ts` (envio de push)

## 9) Arquivos de configuração por plataforma

### Android

Já presente:

- `android/app/google-services.json`
- Plugins no Gradle:
  - `com.google.gms.google-services`
  - `com.google.firebase.crashlytics`

Arquivo-chave:

- `android/app/build.gradle.kts`

### iOS

Pendente no repositório atual:

- `ios/Runner/GoogleService-Info.plist` (não encontrado)

Necessário para iOS funcionar com Firebase.

Também validar no Xcode:

- Capability Push Notifications (se usar FCM).
- Background Modes > Remote notifications.

### Web

Já existe configuração base em `firebase_options.dart`.

Se quiser push em background na Web, adicionar worker:

- `web/firebase-messaging-sw.js` (não encontrado no repositório atual)

## 10) Ambientes DEV / HML / PROD

Hoje o projeto seleciona ambiente via:

- `--dart-define=APP_ENV=dev|hml|prod`

Mas atualmente os arquivos:

- `lib/firebase_options_dev.dart`
- `lib/firebase_options_hml.dart`
- `lib/firebase_options_prod.dart`

apontam para o mesmo `firebase_options.dart` (mesmo projeto Firebase).

Se a intenção for separar Firebase por ambiente, gerar opções reais para cada projeto:

1. Criar um projeto Firebase para cada ambiente (ou usar aliases).
2. Rodar `flutterfire configure` para cada ambiente e gerar arquivos distintos.
3. Garantir que cada ambiente use seu `google-services.json`/`GoogleService-Info.plist` correspondente.

## 11) Comandos úteis de setup/deploy

Na raiz do projeto:

- `flutter pub get`
- `firebase use <alias-ou-project-id>`
- `firebase deploy --only firestore:rules,firestore:indexes,storage`
- `firebase deploy --only functions`

Para executar o app:

- `flutter run --dart-define=APP_ENV=dev`
- `flutter run --dart-define=APP_ENV=hml`
- `flutter run --dart-define=APP_ENV=prod`

Web com App Check:

- `flutter run -d chrome --dart-define=APP_ENV=prod --dart-define=APP_CHECK_WEB_RECAPTCHA_KEY=SUA_CHAVE`

## 12) Checklist final (rápido)

- [ ] Firebase CLI logado (`firebase login`)
- [ ] Projeto Firebase selecionado (`firebase use ...`)
- [ ] Auth Email/Senha habilitado
- [ ] Auth Google habilitado
- [ ] SHA-1/SHA-256 Android cadastrados
- [ ] Firestore criado e regras publicadas
- [ ] Storage criado e regras publicadas
- [ ] Functions com `npm install`, `npm run build` e deploy
- [ ] App Check configurado no Console
- [ ] `google-services.json` correto no Android
- [ ] `GoogleService-Info.plist` adicionado no iOS
- [ ] APNs configurado (se usar iOS push)
- [ ] Worker web configurado para push em background (se usar web push)
- [ ] Teste de login, leitura/escrita Firestore, upload Storage, push e crash report

## 13) Estado atual detectado neste repositório

- OK: bootstrap Firebase no app (`Firebase.initializeApp` + App Check + Crashlytics).
- OK: regras Firestore e Storage presentes.
- OK: Functions configuradas com Node 20 e código TypeScript.
- OK: Android com `google-services.json` e plugins gradle do Firebase.
- Atenção: iOS sem `GoogleService-Info.plist` no repositório.
- Atenção: arquivo `web/firebase-messaging-sw.js` não encontrado (necessário para push web em background).
- Atenção: DEV/HML/PROD atualmente usam o mesmo projeto Firebase.
