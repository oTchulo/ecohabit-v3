# Validação da implementação

## Atualização para 20 atividades — 10/11/2026

Versão validada: **3.1.0+2**, banco **v2**, regras novas **xp-v2**.

- `flutter pub get`: sucesso, mantendo as versões do lockfile.
- `flutter analyze`: **No issues found!** na execução final.
- `flutter test`: **63 testes aprovados**. A mesma suíte passou com `--dart-define=CAPTURE_SCREENSHOTS=true`, atualizando as capturas dos widgets.
- `flutter build apk --debug`: sucesso, código de saída 0; compilação em aproximadamente 222 segundos.
- `apksigner verify --verbose`: assinatura v2 válida. `aapt dump badging` confirmou `3.1.0`, versionCode `2`, SDK mínimo 24 e target/compile 36.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`, 165.362.271 bytes. SHA-256: `02682D062D09E7F64965823A2438F663F0E0CE3F9AC77E053AC9D0775FF8B679`.
- Instalação com `adb install -r -t`: sucesso no Pixel 6 / `emulator-5554`, preservando os dados. A atividade `br.edu.umc.ecohabit/.MainActivity` foi confirmada em primeiro plano e a tela foi inspecionada. Não foi encontrada falha do EcoHabit no buffer de crashes consultado.
- Conferência adicional sobre cópias locais do banco real: **1 teste aprovado**. Confirmou versão 1 antes, versão 2 depois, preservação dos campos antigos de usuários/recuperação/registros, 20 atividades, 66 faixas, chaves diárias legadas e integridade referencial.
- Essas cópias e a captura com a conta do usuário ficaram exclusivamente em `.tools/`, ignoradas pelo Git. Não foram incluídos bancos ou dados pessoais no repositório.

Os 63 testes versionados cobrem as 20 atividades e fronteiras de faixas, modalidades, teto diário/mensal, registro sem XP, viradas de dia/mês/ano, conquistas vitalícias, ranking, idempotência, referências repetidas, corridas e migração. Os testes de interface cobrem busca, sete chips (Todas + seis categorias), quantidade fixa da conquista, botão “Concluída” bloqueado e referência obrigatória em registro mensal. A matriz de faixas dos testes é independente das constantes usadas na inicialização.

A migração em arquivo preserva conta, credenciais derivadas, sessão, IDs, data local, instante UTC e XP legado. Um segundo caso provoca falha durante a migração e confirma rollback de DDL, catálogo, dados e `user_version`. A mensagem “falha controlada” impressa nesse teste é esperada e sua exceção é verificada, não um erro pendente do aplicativo.

Durante o desenvolvimento foram corrigidas referências antigas do teste de impacto (ID → código estável), a rolagem nos formulários maiores e um apontamento de estilo. As execuções com falha não foram contadas como aprovação. A conferência local do banco real também foi ajustada para usar caminhos absolutos; somente a execução aprovada é relatada como validação.

O `.gitignore` existente foi revisado e já cobre caches, SDKs, arquivos `.env`, chaves de assinatura, configurações locais e bancos/arquivos auxiliares SQLite. A inspeção do histórico e dos arquivos versionados não identificou padrões de token/chave privada nem arquivos de banco/segredos a publicar. As senhas determinísticas presentes em testes são apenas fixtures de bancos temporários, não credenciais de contas reais.

Limitações mantidas: quantidades inteiras, somente registros do momento atual, referências autodeclaradas, relógio local não confiável contra adulteração, fatores de CO2 não validados e ausência de teste em aparelho físico. Permaneceram avisos não fatais das ferramentas Android/JDK. A publicação e a visibilidade do GitHub precisam de confirmação pela API; a mudança para público exige autorização explícita do proprietário.

## Histórico da implementação anterior

Ambiente da implementação inicial: Windows, Flutter estável 3.47.9, Dart 3.13.7 e JDK 21. O diretório inicial estava vazio. SDKs e caches ficam em `.tools/`, ignorado pelo Git. A validação posterior no Pixel 6 está registrada ao final.

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
- `git init`: repositório local inicializado na implementação inicial, preservada no commit `fcea4c4`.

Os primeiros testes de widget precisaram de ajuste para usar SQLite FFI sem isolate dentro de `tester.runAsync`. O teste de fluxo também foi corrigido para aguardar a saída do SnackBar e rolar até o item efetivo do histórico. As execuções com essas falhas não foram contadas como aprovação.

A revisão do formulário removeu a filtragem que poderia transformar entradas fracionárias coladas em outro número. O teste integrado final verifica que `-4`, `1,5`, `1.5`, `0` e `2147483648` mostram erro, antes de registrar uma quantidade válida.

## Capturas verificadas

Foram geradas seis imagens de widgets reais em `docs/screenshots/`: login, início, atividades, registro, ranking e perfil. O teste carrega Roboto e MaterialIcons do SDK, usa resolução lógica 390 × 844 e grava imagens em escala 2. Todas foram abertas para inspeção visual; o fluxo completo foi verificado por assertions.

São renderizações de teste Flutter com conta explicitamente identificada como teste, não prints de aparelho Android. O código de recuperação nunca é incluído nas capturas.

## Limitações de verificação

- A instalação e a inicialização foram verificadas posteriormente no Pixel 6. Fluxos completos de cadastro/recuperação, ciclo de vida, Keystore e teclado no Android ainda precisam de testes específicos em dispositivo.
- A sessão nos testes automatizados usa armazenamento em memória; não se atribui a esses testes uma validação nativa do Keystore.
- O custo de produção de PBKDF2 não foi cronometrado. O dublê usa custo reduzido para testes e há comparação do algoritmo real com vetor conhecido.
- Não foram validados fatores de CO2; os campos correspondentes são nulos por decisão explícita e documentada.
- Na implementação inicial o schema era v1 e não havia banco anterior. A atualização para v2 possui testes de migração e rollback, descritos acima.
- O resultado de CI remoto não faz parte da validação local registrada aqui; deve ser consultado no GitHub Actions.

## Resultado Android da etapa anterior (3.0.0)

APK final gerado em `build/app/outputs/flutter-apk/app-debug.apk` e verificado em 10/11/2026.

- Aplicativo: EcoHabit; pacote: `br.edu.umc.ecohabit`.
- Versão: `3.0.0`, código `1`.
- SDK mínimo: API 24; target/compile: API 36.
- Arquiteturas: `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- Tamanho do APK recompilado para a execução no emulador: 165.338.471 bytes (aproximadamente 165,3 MB; build debug com três arquiteturas).
- SHA-256 desse APK: `547DE9523FBE5B83C9BEDDBBDF481D5C83372BFCC2606C2F6DEFEFE2ACDF4F4F`.

A geração, a assinatura e a inicialização em emulador foram verificadas. A execução em aparelho físico permanece pendente. O APK é de depuração, destinado à demonstração e desenvolvimento, e não está incluído no Git.

## Execução no Pixel 6 — 10/11/2026

- `flutter doctor -v`: toolchain Android aprovado, licenças aceitas. Flutter/Dart estão disponíveis pelo SDK local, ainda fora do PATH global. A ausência de Visual Studio afeta o alvo Windows, não o Android.
- `flutter devices`: encontrou `emulator-5554`, Android 15 (API 35), x86_64. `adb -s emulator-5554 emu avd name` retornou `Pixel_6`, com boot concluído.
- `flutter pub get`: sucesso, sem atualizar as versões travadas das dependências.
- `flutter run -d emulator-5554`: compilação aprovada, APK instalado, arquivos sincronizados e serviço de depuração Dart conectado. O Flutter utilizou o JDK 25 incluído no Android Studio; a compilação inicial também havia sido validada com JDK 21.
- `adb shell pidof br.edu.umc.ecohabit`: confirmou o processo ativo. `dumpsys activity activities` confirmou `br.edu.umc.ecohabit/.MainActivity` como atividade em primeiro plano.
- Captura ADB inspecionada visualmente: tela de login renderizada, sem mensagem de erro de inicialização. Arquivo: `docs/screenshots/android-pixel6-login.png`.
- O buffer de crashes consultado não apresentou falha do EcoHabit. Houve avisos não fatais de SDK XML, compilação Java 8 em dependência e frames descartados durante a inicialização do emulador.
- A exportação de hierarquia via `uiautomator` retornou raiz nula; a confirmação visual foi feita pela captura direta da tela, juntamente com a atividade Android e o serviço Dart.
- Não foi necessário alterar código Dart nem regras de negócio. O aplicativo foi mantido aberto para testes.

## Preparação do GitHub

- Git existente, branch `main`, histórico inicial preservado. Não havia remoto configurado.
- GitHub CLI oficial instalada em `.tools/`, com checksum verificado. Autenticação concluída pelo usuário; credenciais guardadas no keyring do Windows, fora do projeto.
- Repositório `oTchulo/ecohabit-v3` criado após verificar que não existia. A API confirmou `isPrivate: true`; remoto `origin` associado por HTTPS.
- `.gitignore` ampliado para caches, segredos, arquivos `.env`, chaves de assinatura e bancos SQLite/arquivos auxiliares. O caminho local do SDK em `.vscode/settings.json` está ignorado; somente recomendações de extensões e configuração de execução são compartilhadas.
- A inspeção dos caminhos do histórico e de padrões de chave privada/token não encontrou candidatos. Capturas compartilhadas não contêm credenciais ou dados de contas reais.
- Nenhuma branch ou alteração remota foi apagada; não foi utilizado push forçado.
