# Arquitetura e decisões

O aplicativo Android funciona sem backend. `main.dart` abre SQLite e injeta os repositórios em `AppState`. A apresentação observa esse estado com Provider. Telas não executam SQL nem calculam hashes de senha.

- `models/domain.dart`: modelos, faixas, níveis e datas civis.
- `core/database/app_database.dart`: abertura, schema v1 e migração atômica para v2, índices e integridade referencial.
- `core/constants/activity_catalog.dart`: catálogo aprovado com 20 códigos estáveis e 66 faixas.
- `core/constants/activity_categories.dart`: seis categorias, busca sem acentos, ícones e cores.
- `repositories/auth_repository.dart`: cadastro, login, sessão protegida, troca e recuperação de senha.
- `repositories/activity_repository.dart`: consultas e transação de registro.
- `services/password_service.dart`: PBKDF2 em isolate e aleatoriedade segura.
- `services/impact_service.dart`: cálculos independentes de XP.
- `providers/app_state.dart`: carregamento, erros, atualização de dados e proteção de ações em andamento.
- `screens/` e `widgets/`: apresentação Material 3 e navegação.

## Consistência e pontuação

Cada confirmação recebe um identificador aleatório persistido com restrição UNIQUE. Dentro de uma transação SQLite, o repositório verifica a idempotência (inclusive referência/potência), lê e valida o catálogo, verifica conquista/referência duplicada, soma quantidade e XP no período e insere o registro. O SQLite serializa as transações. Repetir a operação com a mesma carga retorna seu resultado; mudar a carga falha.

O período é definido por modalidade: DIARIA/DIA usa `YYYY-MM-DD`, PERIODICA/MES usa `YYYY-MM`, UNICA/VIDA usa `VIDA`. O XP adicional é `max(0, min(faixa da quantidade acumulada, limite) - XP já concedido)`. Conquistas aceitam uma unidade, uma vez por usuário/atividade, com índice único parcial além da validação Dart. Não se inserem registros adicionais de uma conquista concluída. Diárias/mensais preservam registros mesmo sem XP adicional.

Referências são obrigatórias em mobilidade e eventos mensais, opcionais nas demais ações. São normalizadas com trim, espaços internos únicos e letras minúsculas, limitadas a 120 caracteres. O grupo `TRAJETO` é compartilhado pelas cinco modalidades de mobilidade: o mesmo trecho não pode pontuar em duas delas. Nos demais grupos, o código estável da atividade identifica o tipo do evento. O índice único `(usuario_id, grupo_acao, referencia_acao)` impede a repetição inclusive em outro dia/mês. Uma viagem multimodal deve usar referências de trechos distintos, sem reutilizar o mesmo trecho. A veracidade e a escolha da referência continuam autodeclaradas.

XP total, nível e ranking são derivados dos registros. Não existe campo editável de XP no usuário. Quantidades são inteiros positivos até 2.147.483.647 por entrada, inclusive para kg/kWh/km. Uma configuração de teto menor limita a faixa; teto maior não cria bônus. Alterações futuras devem incrementar a versão da atividade e a configuração correspondente em migração, mantendo faixas contíguas, sem sobreposição/lacunas e XP não decrescente. O serviço rejeita modalidade/período incompatíveis e faixas inválidas. A prévia usa o XP efetivamente concedido; a transação recalcula no instante da confirmação.

O MVP aceita somente o momento atual: a API de registro não recebe data e a interface não oferece lançamentos retroativos. Data civil, chave do período e instante UTC são capturados juntos; nunca são recalculados após mudança de fuso. O relógio é injetável exclusivamente para testar fronteiras. O dispositivo ainda pode ter seu relógio adulterado: não há fonte confiável de tempo offline. A semana vai de segunda inclusiva à próxima segunda exclusiva. O ranking semanal soma o XP concedido na data de cada registro, inclusive para atividades mensais/únicas. Não há apagamento na meia-noite ou virada de mês: muda o agrupamento consultado. Provider atualiza ao retomar e verifica a virada de dia a cada 15 segundos.

## Banco e evolução

`usuarios`, `atividades`, `faixas_pontuacao`, `registros`, `configuracoes` e `recuperacao` mantêm seus dados. A versão 2 acrescenta código único, modalidade, período, limite, grupo e versão em `atividades`; `registros` recebe modalidade/período/chave e referência/grupo de ação. Faixas são substituídas pelas 66 faixas aprovadas durante a migração. Registros recebem snapshots do tipo/período e versão; mudanças futuras não alteram XP histórico. `recuperacao` mantém somente hash, salt e custo do código secreto. O e-mail segue único COLLATE NOCASE.

O schema vigente é v2. Novos bancos aplicam o schema v1 e a mesma migração usada no upgrade. `onUpgrade` faz v1 → v2 dentro da transação de versão do sqflite; não apaga/recria o banco. Os IDs legados 1/2/3 são preservados como `garrafas_pet`/`bicicleta`/`luzes_apagadas`. A chave de período antiga é preenchida pela `data_local` original, sem converter o UTC nem recalcular XP; versões antigas continuam `xp-v1`. Códigos extras locais são preservados como `legado_<id>` inativos, mantendo seu histórico. Os limites aprovados de v2 ficam em `limite_xp`; `limite_xp_diario` é mantido por compatibilidade de schema, sem leituras no motor v2.

O catálogo é configurado só na criação/migração, sem reseed ao reabrir: novas inicializações não duplicam atividades/faixas nem desfazem configurações. Índices de consulta cobrem usuário/dia, semana e usuário/atividade/período. Índices únicos parciais impõem conquistas e referências; trigger valida chave/modalidade/período e a unidade da conquista. `PRAGMA foreign_keys=ON` é verificado ao abrir e `foreign_key_check` detecta referências quebradas. Consultas com entrada do usuário são parametrizadas. Testes induzem falha na migração e verificam rollback de DDL/dados/versão. Caminhos de versão não implementados são rejeitados, sem descarte automático.

## Segurança e limites offline

As senhas usam PBKDF2-HMAC-SHA256, 600.000 iterações, salt individual aleatório de 128 bits e saída de 256 bits. O custo fica em cada linha para futuras evoluções. A comparação percorre os bytes sem retorno antecipado. O serviço usa `compute` para executar a derivação em isolate no Android. O código de recuperação contém 256 bits de entropia e recebe o mesmo tratamento de hash. Ele é mostrado uma vez e deve ser guardado fora do app. A recuperação autentica a posse desse código, atualiza a senha e rotaciona o código atomicamente. Reutilização não é permitida.

A sessão contém apenas o ID da conta dentro de `flutter_secure_storage`, com preferências criptografadas no Android e proteção via Keystore. Não há senha/token em preferências comuns. O backup automático Android está desabilitado para evitar restauração inconsistente do Keystore. Falha no armazenamento seguro gera mensagem; não há fallback inseguro.

Os dados de atividades e e-mails permanecem no SQLite privado do app, sem criptografia adicional. Autenticação local não resiste a root, engenharia reversa, adulteração do banco ou comprometimento do sistema. Não comprova a veracidade das ações nem impede manipulação do relógio. Sem senha, código de recuperação e sessão preservados, não há recuperação de identidade por e-mail. Reinstalar/apagar os dados pode destruir o progresso. Não há sincronização, recuperação remota ou ranking entre aparelhos.

## Impacto ambiental v1

A versão `impacto-v1` é persistida em cada registro, separada de `xp-v1`/`xp-v2`. O serviço usa códigos estáveis, sem depender do ID numérico.

| Indicador | Regra e hipótese | Disponibilidade |
| --- | --- | --- |
| Energia | `potência_W × minutos / 60.000`; pressupõe uma lâmpada que ficaria ligada durante todo o intervalo, com potência nominal informada a partir da etiqueta | Calculado somente com potência válida |
| CO₂ de bicicleta | Compararia a distância com um deslocamento motorizado substituído; exige definir veículo, ocupação, combustível e fator de emissão aplicável | Não calculado: cenário/fator não validados |
| CO₂ de reciclagem | Exige material, massa e fator de ciclo de vida apropriado; contar garrafas não informa esses dados | Não calculado |
| CO₂ de energia | Exige fator de emissão da rede, local e período aplicáveis | Não calculado |

Fonte da relação de energia: [U.S. Energy Information Administration — Measuring electricity](https://www.eia.gov/energyexplained/electricity/measuring-electricity.php), consultada em 09/11/2026. Um kW corresponde a 1.000 W; Wh representa energia de um watt durante uma hora. Não foi assumida potência padrão. Os valores são estimativas contrafactuais, não medições nem créditos certificados. `NULL` significa não calculado, não zero. A soma de kWh cobre apenas os registros com potência; isso é informado na interface.

Para as novas atividades sem fator validado, só a quantidade declarada aparece nos cards e no histórico. Energia solar registra kWh gerados, não kWh evitados; aparelhos desligados registram horas, sem assumir potência. Carros elétricos não emitem gases pelo escapamento, mas geração elétrica e ciclo de vida têm impactos. Não há conversão implícita para CO2 ou alegação de emissão zero.

## Testes

Os testes usam SQLite real via FFI, bancos independentes e relógio injetável. Uma matriz independente dos requisitos verifica cada fronteira das 20 atividades. São verificados múltiplos registros, referências, limites diários/mensais, viradas de dia/mês/ano, conquistas vitalícias, corridas, registros sem XP, ranking e reabertura. Migração usa arquivo v1 com conta/sessão/histórico e também falha induzida para conferir atomicidade. Widgets verificam filtros/busca, referência obrigatória, quantidade fixa da conquista e botão “Concluída” desabilitado. O custo PBKDF2 é reduzido só no dublê `TestPasswords`; o algoritmo real tem vetor conhecido. Isso não é benchmark do custo de produção nem validação nativa do Keystore.
