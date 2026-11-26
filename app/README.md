# PlaceZ — app Flutter

App Android do PlaceZ. O calendário é a tela inicial; o login só é pedido
quando uma ação protegida exige (chat, criação de evento ou amigos).

## Executar

```bash
flutter pub get
flutter run
```

Por padrão o app usa a API remota. A URL é definida em tempo de build:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://IP_DA_VPS:3000/api/v1
```

O modo mock pode ser alternado em **Configurações → Conexão com a API**.

## Notificações

A Fase 8 está em modo no-op: `lib/core/notificacoes/notificacao_service.dart`
expõe a costura para o FCM, mas não carrega Firebase nem registra token. O app
funciona normalmente sem push.
