# EcoHabit V3 🌱

Plataforma gamificada de sustentabilidade urbana, desenvolvida em Flutter para Android como projeto acadêmico de Engenharia de Software da Universidade de Mogi das Cruzes (UMC), relacionada aos ODS 7 e 11.

O objetivo é incentivar hábitos sustentáveis por meio de registros de reciclagem de garrafas, deslocamentos de bicicleta e economia de energia. O MVP funciona offline e guarda os dados em SQLite, sem serviços externos de armazenamento.

## Funcionalidades

- Cadastro e login locais, e-mail único, senha derivada com salt e sessão protegida.
- Recuperação offline autenticada por código secreto de uso único, com rotação; alteração de senha mediante senha atual; logout.
- Catálogo com filtros, múltiplos registros por dia e prévia do XP adicional.
- XP calculado sobre quantidade acumulada diária, limites configuráveis e transações idempotentes.
- Cinco níveis, progresso até o próximo nível e aviso de promoção.
- Início com resumo, perfil e histórico persistido, incluindo ações que concederam zero XP.
- Ranking geral e semanal entre contas reais do mesmo dispositivo.
- Estimativa de energia mediante potência informada; impactos sem fator validado apresentados como não calculados.
- Interface verde e branca, Material Design 3, navegação inferior e estados de erro/carregamento/vazio.

## Tecnologias e estrutura

Flutter estável 3.47.9, Dart 3.13.7, Provider, sqflite, cryptography, flutter_secure_storage, Material 3 e flutter_test. As versões efetivamente resolvidas estão em `pubspec.lock`, que deve ser versionado. Os testes de persistência usam `sqflite_common_ffi`.

```text
lib/
  main.dart
  app/                 Aplicativo, localização pt-BR e tema
  core/database/       Schema versionado e catálogo inicial
  models/              Entidades, níveis e datas locais
  repositories/        Autenticação e consultas/transações SQLite
  services/            Senhas e impacto ambiental
  providers/           Estado observável e coordenação
  screens/             Login/cadastro, navegação e registro
  widgets/             Cards e componentes compartilhados
test/                  Regras, persistência, widgets e fluxo integrado
android/               Projeto Android nativo gerado pelo Flutter
docs/                  Decisões técnicas e capturas
scripts/check.ps1      Verificação local no Windows
.github/workflows/     Verificações propostas para GitHub Actions
```

A arquitetura separa apresentação, domínio e persistência. Veja [decisões técnicas, segurança e fontes ambientais](docs/ARQUITETURA.md).

## Instalar e executar

Requisitos: Flutter estável compatível com o lockfile, Java 21, Android SDK com plataforma API 36, ferramentas de compilação e um dispositivo Android com depuração USB ou emulador. O projeto usa os valores de SDK/NDK recomendados pelo Flutter. A primeira preparação precisa de internet para baixar ferramentas e dependências; o aplicativo instalado funciona offline.

```sh
flutter pub get
flutter devices
flutter run -d <id-do-dispositivo-android>
```

Nesta máquina o SDK Flutter foi baixado para `.tools/flutter` e o Android SDK para `.tools/android-sdk`. Essas ferramentas locais não entram no Git. No PowerShell, é possível usar:

```powershell
$env:ANDROID_HOME = "$PWD\.tools\android-sdk"
$env:GRADLE_USER_HOME = "$PWD\.tools\gradle-cache"
# Configure JAVA_HOME para seu JDK 21, se ainda não estiver configurado.
.\.tools\flutter\bin\flutter.bat pub get
.\.tools\flutter\bin\flutter.bat run -d <id-do-dispositivo-android>
```

Não é um aplicativo web/Windows: o alvo do MVP é Android e a abertura de banco em produção usa o plugin sqflite Android. O FFI é usado apenas nos testes.

## Testar e gerar APK

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Ou, no Windows: `powershell -File scripts/check.ps1 -BuildApk`. O script interrompe ao primeiro erro. O APK de depuração foi gerado em `build/app/outputs/flutter-apk/app-debug.apk` (165,3 MB; Android API 24+, ARM e x86_64). A assinatura foi verificada, e a inicialização foi confirmada no emulador Pixel 6 com Android 15 (API 35). A distribuição de produção requer assinatura própria; a configuração inicial de release ainda usa chave de depuração.

### VS Code e emulador

As extensões Flutter e Dart são recomendadas em `.vscode/extensions.json`. Abra `lib/main.dart`, selecione o dispositivo Android na barra de status e inicie a configuração **EcoHabit · Android** com F5. O caminho do SDK desta máquina fica em `.vscode/settings.json`, ignorado pelo Git; cada integrante deve configurar seu próprio SDK.

Na validação de 10/11/2026, `adb emu avd name` confirmou o AVD `Pixel_6`, e `flutter devices` identificou o dispositivo como `emulator-5554`. O aplicativo foi iniciado com:

```powershell
$env:ANDROID_HOME = "$PWD\.tools\android-sdk"
$env:GRADLE_USER_HOME = "$PWD\.tools\gradle-cache"
.\.tools\flutter\bin\flutter.bat run -d emulator-5554
```

O identificador pode mudar em outra execução: confira `flutter devices` antes de reutilizar o comando. Não é necessário instalar Visual Studio para desenvolver o alvo Android.

Para regenerar as capturas dos widgets reais, com conta exclusiva do teste e banco temporário:

```sh
flutter test test/app_flow_test.dart --dart-define=CAPTURE_SCREENSHOTS=true
```

Os testes cobrem autenticação e recuperação, todas as fronteiras das faixas, acumulado diário, teto menor configurado, ações sem XP, virada de dia, níveis, ranking, idempotência, concorrência, integridade referencial e persistência após reabertura. O fluxo de interface usa o mesmo SQLite dos testes para registrar uma ação e verificar navegação, ranking, histórico e logout. O custo PBKDF2 é reduzido apenas no dublê de testes; não se trata de validação do Keystore em dispositivo Android.

Resultados efetivamente executados são registrados em [VALIDACAO.md](docs/VALIDACAO.md). A configuração de CI está preparada; não há execução remota de GitHub Actions alegada.

## Regras de pontuação

| Atividade | Faixas de quantidade acumulada no dia → XP | Teto configurado |
| --- | --- | --- |
| Garrafas | 1–5 → 30; 6–10 → 60; 11–20 → 100; 21+ → 150 | 200 XP |
| Bicicleta (km inteiros) | 1–5 → 25; 6–10 → 50; 11–20 → 100; 21+ → 150 | 200 XP |
| Energia (minutos inteiros) | 1–15 → 10; 16–30 → 25; 31–60 → 50; 61+ → 80 | 100 XP |

O XP adicional é a diferença não negativa entre a pontuação devida após a nova quantidade e o XP já concedido naquela atividade/dia, limitado pelo teto. Com configurações constantes, equivale a `máximo(0, faixa_depois − faixa_antes)`. Quatro registros de 4, 4, 4 e 2 garrafas concedem 30, 30, 40 e 0 XP. Todos permanecem no histórico. As faixas atuais não alcançam os tetos e não geram pontos extras para preenchê-los.

As regras são carregadas das tabelas `atividades` e `faixas_pontuacao`. Alterações de configuração devem ser versionadas em migrações. Não há edição manual de pontuação na interface.

| Nível | Nome | XP total |
| --- | --- | --- |
| 1 | Iniciante Verde | 0–199 |
| 2 | Amigo da Natureza | 200–499 |
| 3 | Protetor Ambiental | 500–999 |
| 4 | Guardião Verde | 1.000–1.999 |
| 5 | Mestre Sustentável | 2.000+ (máximo) |

O dia é a data local do dispositivo. XP total permanece entre dias. A semana começa na segunda-feira e termina antes da segunda seguinte. O desempate do ranking usa a data de cadastro crescente e o ID crescente. O nível no ranking é o nível total da conta, inclusive no ranking semanal. Contas sem atividade aparecem com zero XP; nenhum usuário fictício é inserido na instalação.

## SQLite

| Tabela | Conteúdo |
| --- | --- |
| `usuarios` | Identidade, e-mail único, hash/salt/custo da senha, bairro opcional e data de cadastro |
| `atividades` | Nome, categoria, unidade, ODS, teto diário e situação ativa |
| `faixas_pontuacao` | Atividade, mínimo, máximo opcional e XP |
| `registros` | Usuário, atividade, quantidade, XP concedido, estimativas opcionais, potência, dia local, instante UTC, versões e ID único da operação |
| `configuracoes` | Parâmetros versionados, inicialmente `versao_regra = xp-v1` |
| `recuperacao` | Hash, salt e custo do código secreto por usuário |

Chaves estrangeiras são habilitadas e verificadas. Há índices por usuário/dia/atividade e por dia/usuário. O banco inicial está na versão 1; não há banco anterior a migrar. O callback de upgrade rejeita caminhos sem implementação para evitar perda silenciosa de dados. XP total e nível não são armazenados redundantemente.

## Impacto ambiental e limites do MVP

Energia: `kWh = potência_W × minutos / 60.000`, com potência fornecida pelo usuário a partir da etiqueta da lâmpada. Fonte dimensional: [EIA — Measuring electricity](https://www.eia.gov/energyexplained/electricity/measuring-electricity.php). O app não assume uma lâmpada padrão. A soma inclui apenas registros com potência conhecida.

CO₂ fica **não calculado** nesta versão: reciclagem precisa de material e massa; bicicleta precisa de um cenário motorizado substituído e fator validado; energia precisa de um fator da rede aplicável. O código reserva esses campos como `NULL` e armazena a versão de fatores em cada registro. Não se apresentam números ambientais inventados. Veja as hipóteses no documento de arquitetura.

As senhas usam PBKDF2-HMAC-SHA256 com 600.000 iterações, salt de 128 bits e hash de 256 bits. A sessão usa armazenamento protegido pelo sistema Android. O código de recuperação deve ser guardado pelo usuário fora do app; sem ele ou a senha não existe recuperação remota. Dados pessoais e ações ficam no SQLite privado, sem criptografia extra do arquivo. Root, alterações do banco/relógio e comprometimento do aparelho estão fora da proteção do MVP. Apagar os dados ou reinstalar pode perder o progresso. Não há sincronização nem ranking online.

## Capturas

Captura real da tela de login no emulador Pixel 6, Android 15, obtida por ADB após confirmar o processo do aplicativo em primeiro plano:

<img src="docs/screenshots/android-pixel6-login.png" alt="EcoHabit executando no Pixel 6" width="320">

Capturas de widgets Flutter renderizados pelo teste integrado, com a conta explícita “Conta de teste”. Não representam execução em um aparelho ou emulador Android. Nenhuma conta de demonstração é criada na instalação normal.

| Login | Início | Atividades |
| --- | --- | --- |
| ![Login](docs/screenshots/login.png) | ![Início](docs/screenshots/inicio.png) | ![Atividades](docs/screenshots/atividades.png) |

| Registro | Ranking | Perfil |
| --- | --- | --- |
| ![Registro](docs/screenshots/registro.png) | ![Ranking](docs/screenshots/ranking.png) | ![Perfil](docs/screenshots/perfil.png) |

## Demonstração acadêmica

1. Instale e abra o app, crie uma conta e guarde o código de recuperação.
2. Registre 4, 4, 4 e 2 garrafas; confira incrementos de 30, 30, 40 e 0 XP.
3. Registre bicicleta ou energia; informe potência apenas se conhecida.
4. Veja os registros no perfil e o ranking local. Crie outra conta para comparar.
5. Feche e reabra o app para verificar sessão e progresso no aparelho.
6. Teste logout/login e, com o código guardado, recuperação offline.

## Equipe

- Breno Diniz Nascimento — Product Owner.
- Micael Nascimento de Sousa — Scrum Master.
- Samuel Dantas Lima da Silva — Analista de Sistemas.
- Victor Aparecido Sassati — Desenvolvedor.
- Vitor Landim de Carvalho Rosa — Desenvolvedor.

Os papéis são os informados nos requisitos; não se atribuem contribuições individuais não verificadas. O histórico Git local foi preservado. O remoto privado configurado é [oTchulo/ecohabit-v3](https://github.com/oTchulo/ecohabit-v3), com branch de trabalho `main`; o acesso depende de autorização no GitHub.
