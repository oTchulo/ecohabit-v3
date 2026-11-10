# Validação da implementação

Ambiente preparado nesta execução: Windows, Flutter estável 3.47.9, Dart 3.13.7 e JDK 21. O diretório inicial estava vazio. SDKs e caches ficam em `.tools/`, ignorado pelo Git.

## Etapas e evidências

| Etapa | Implementação | Verificação |
| --- | --- | --- |
| 1 — Fundação | Projeto Flutter Android, dependências resolvidas, Material 3 e SQLite v1 | `flutter pub get` executado com sucesso; análise sem apontamentos |
| 2 — Persistência/autenticação | Schema, integridade, cadastro, login, sessão protegida, recuperação e troca de senha | Testes de cadastro, unicidade, validação, login, sessão via dublê, recuperação/rotação e persistência em arquivo passaram |
| 3 — Gamificação | Catálogo, faixas cumulativas, transações idempotentes, teto e níveis | Fronteiras de todas as faixas, sequência 4+4+4+2, concorrência, duplicidade, virada de dia, isolamento e níveis passaram |
| 4 — Interface | Navegação, estados, filtros e formulário com prévia | Testes de widgets em tela estreita e fluxo SQLite de cadastro pela interface, código de recuperação, registro, ranking, histórico, logout e novo login passaram |
| 5 — Impacto/ranking | Energia com potência explícita, impacto versionado, CO2 não calculado, ranking semanal/geral | Conversão energética, nulos, versões, fronteira semanal e desempate passaram |
| 6 — Entrega | README, decisões técnicas, script de verificação, workflow e capturas | Análise sem apontamentos, 23 testes aprovados, APK gerado e assinatura validada |

## Comandos executados

- `flutter --version`: Flutter 3.47.9 / Dart 3.13.7.
- `flutter create --platforms android --org br.edu.umc --project-name ecohabit --no-pub .`: estrutura nativa gerada, preservando o código existente.
- `flutter pub get`: sucesso, lockfile gerado.
- `dart format lib test`: executado.
- `dart fix --apply`: corrigiu 11 apontamentos de chaves em condicionais da primeira análise.
- `flutter analyze`: última execução terminou com `No issues found!`.
- `flutter test`: execução intermediária com 22 testes aprovados.
- `flutter test --dart-define=CAPTURE_SCREENSHOTS=true`: execução final com **23 testes aprovados**, incluindo a navegação integrada adicionada posteriormente.
- `flutter build apk --debug`: sucesso. A primeira compilação completa foi aprovada após instalar SDKs/NDK; a compilação final incremental, com os últimos ajustes, terminou com código 0 em aproximadamente 47 segundos.
- `apksigner verify --verbose`: sucesso, assinatura APK v2 válida, um assinante de depuração.
- `aapt dump badging`: confirmou pacote, versão, nome, SDKs e arquiteturas descritos abaixo.
- `git init`: repositório local inicializado; não houve publicação remota nem execução de CI no GitHub.

Os primeiros testes de widget precisaram de ajuste para usar SQLite FFI sem isolate dentro de `tester.runAsync`. O teste de fluxo também foi corrigido para aguardar a saída do SnackBar e rolar até o item efetivo do histórico. As execuções com essas falhas não foram contadas como aprovação.

A revisão do formulário removeu a filtragem que poderia transformar entradas fracionárias coladas em outro número. O teste integrado final verifica que `-4`, `1,5`, `1.5`, `0` e `2147483648` mostram erro, antes de registrar uma quantidade válida.

## Capturas verificadas

Foram geradas seis imagens de widgets reais em `docs/screenshots/`: login, início, atividades, registro, ranking e perfil. O teste carrega Roboto e MaterialIcons do SDK, usa resolução lógica 390 × 844 e grava imagens em escala 2. Todas foram abertas para inspeção visual; o fluxo completo foi verificado por assertions.

São renderizações de teste Flutter com conta explicitamente identificada como teste, não prints de aparelho Android. O código de recuperação nunca é incluído nas capturas.

## Limitações de verificação

- Sem dispositivo/emulador Android conectado: não foi executado teste manual de instalação, ciclo de vida em aparelho, Keystore ou teclado Android.
- A sessão em testes usa armazenamento em memória; a integração nativa de armazenamento protegido depende de validação em Android.
- O custo de produção de PBKDF2 não foi cronometrado. O dublê usa custo reduzido para testes e há comparação do algoritmo real com vetor conhecido.
- Não foram validados fatores de CO2; os campos correspondentes são nulos por decisão explícita e documentada.
- A migração histórica não pode ser testada sem uma versão anterior: este é o schema inicial v1. Versões futuras precisam de migrações implementadas e testadas.
- O workflow foi criado, mas nenhuma execução remota foi realizada.

## Resultado Android

APK final gerado em `build/app/outputs/flutter-apk/app-debug.apk` e verificado em 10/11/2026.

- Aplicativo: EcoHabit; pacote: `br.edu.umc.ecohabit`.
- Versão: `3.0.0`, código `1`.
- SDK mínimo: API 24; target/compile: API 36.
- Arquiteturas: `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- Tamanho: 165.338.859 bytes (aproximadamente 165,3 MB; build debug com três arquiteturas).
- SHA-256: `254A0B568484ACA2C4A5BF043C811A76AAA3680D3572CE459BD9B1305412DD0A`.

A geração e a assinatura foram verificadas; a instalação/execução em aparelho Android permanece pendente. O APK é de depuração, destinado à demonstração e desenvolvimento, e não está incluído no Git.
