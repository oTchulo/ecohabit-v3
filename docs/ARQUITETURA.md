# Arquitetura e decisões

O aplicativo Android funciona sem backend. `main.dart` abre SQLite e injeta os repositórios em `AppState`. A apresentação observa esse estado com Provider. Telas não executam SQL nem calculam hashes de senha.

- `models/domain.dart`: modelos, faixas, níveis e datas civis.
- `core/database/app_database.dart`: abertura, schema v1, catálogo inicial, índices e integridade referencial.
- `repositories/auth_repository.dart`: cadastro, login, sessão protegida, troca e recuperação de senha.
- `repositories/activity_repository.dart`: consultas e transação de registro.
- `services/password_service.dart`: PBKDF2 em isolate e aleatoriedade segura.
- `services/impact_service.dart`: cálculos independentes de XP.
- `providers/app_state.dart`: carregamento, erros, atualização de dados e proteção de ações em andamento.
- `screens/` e `widgets/`: apresentação Material 3 e navegação.

## Consistência e pontuação

Cada confirmação recebe um identificador aleatório persistido com restrição UNIQUE. Dentro de uma transação SQLite, o repositório verifica a idempotência, lê o catálogo vigente, soma quantidades e XP já concedido naquele dia, calcula a diferença não negativa e insere o registro. O SQLite serializa as transações. A repetição do identificador com a mesma carga retorna o resultado existente; com carga diferente, falha.

XP total, nível e ranking são derivados dos registros. Não existe campo editável de XP no usuário. Quantidades são inteiros positivos; a aplicação limita cada entrada a 2.147.483.647, sem alterar as faixas aprovadas. Registros com zero XP são preservados. Uma configuração de teto menor limita a faixa; um teto maior não cria bônus. Alterações futuras de faixas devem incrementar `configuracoes.versao_regra` em migração e manter as faixas monotônicas.

O dia usa a data civil local do dispositivo no momento da transação; `criado_em` é UTC. A semana vai de segunda-feira inclusiva à próxima segunda exclusiva. A data civil é preservada, inclusive se o fuso do aparelho mudar posteriormente. Não há temporizador que apague dados na meia-noite: as consultas começam naturalmente um novo agrupamento diário. O estado é atualizado ao retomar o app e verifica a mudança de dia a cada 15 segundos enquanto ativo.

## Banco e evolução

`usuarios`, `atividades`, `faixas_pontuacao`, `registros`, `configuracoes` e `recuperacao` têm chaves, restrições e índices definidos no código do banco. `registros` inclui potência informada e versão dos fatores, além dos campos solicitados. `recuperacao` mantém somente hash, salt e custo do código secreto. O e-mail tem unicidade COLLATE NOCASE e é normalizado antes da gravação. O catálogo é inserido somente na criação.

O schema inicial é a versão 1. `onUpgrade` é o ponto explícito de migração e rejeita caminhos não implementados; não há migração histórica fictícia nem descarte automático de banco. Uma próxima versão deve implementar migrações incrementais antes de aumentar `version`. `PRAGMA foreign_keys=ON` é verificado ao abrir e `foreign_key_check` detecta referências quebradas. Consultas com dados do usuário são parametrizadas.

## Segurança e limites offline

As senhas usam PBKDF2-HMAC-SHA256, 600.000 iterações, salt individual aleatório de 128 bits e saída de 256 bits. O custo fica em cada linha para futuras evoluções. A comparação percorre os bytes sem retorno antecipado. O serviço usa `compute` para executar a derivação em isolate no Android. O código de recuperação contém 256 bits de entropia e recebe o mesmo tratamento de hash. Ele é mostrado uma vez e deve ser guardado fora do app. A recuperação autentica a posse desse código, atualiza a senha e rotaciona o código atomicamente. Reutilização não é permitida.

A sessão contém apenas o ID da conta dentro de `flutter_secure_storage`, com preferências criptografadas no Android e proteção via Keystore. Não há senha/token em preferências comuns. O backup automático Android está desabilitado para evitar restauração inconsistente do Keystore. Falha no armazenamento seguro gera mensagem; não há fallback inseguro.

Os dados de atividades e e-mails permanecem no SQLite privado do app, sem criptografia adicional. Autenticação local não resiste a root, engenharia reversa, adulteração do banco ou comprometimento do sistema. Não comprova a veracidade das ações nem impede manipulação do relógio. Sem senha, código de recuperação e sessão preservados, não há recuperação de identidade por e-mail. Reinstalar/apagar os dados pode destruir o progresso. Não há sincronização, recuperação remota ou ranking entre aparelhos.

## Impacto ambiental v1

A versão `impacto-v1` é persistida em cada registro, separada de `xp-v1`.

| Indicador | Regra e hipótese | Disponibilidade |
| --- | --- | --- |
| Energia | `potência_W × minutos / 60.000`; pressupõe uma lâmpada que ficaria ligada durante todo o intervalo, com potência nominal informada a partir da etiqueta | Calculado somente com potência válida |
| CO₂ de bicicleta | Compararia a distância com um deslocamento motorizado substituído; exige definir veículo, ocupação, combustível e fator de emissão aplicável | Não calculado: cenário/fator não validados |
| CO₂ de reciclagem | Exige material, massa e fator de ciclo de vida apropriado; contar garrafas não informa esses dados | Não calculado |
| CO₂ de energia | Exige fator de emissão da rede, local e período aplicáveis | Não calculado |

Fonte da relação de energia: [U.S. Energy Information Administration — Measuring electricity](https://www.eia.gov/energyexplained/electricity/measuring-electricity.php), consultada em 09/11/2026. Um kW corresponde a 1.000 W; Wh representa energia de um watt durante uma hora. Não foi assumida potência padrão. Os valores são estimativas contrafactuais, não medições nem créditos certificados. `NULL` significa não calculado, não zero. A soma de kWh cobre apenas os registros com potência; isso é informado na interface.

## Testes

Os testes do domínio/repositórios usam SQLite real via FFI, bancos independentes e relógio injetável. Um teste fecha e reabre arquivo em diretório temporário. Testes de widget verificam validação, níveis e fluxo de navegação conectado a SQLite. O custo PBKDF2 é reduzido exclusivamente no dublê `TestPasswords`; o algoritmo real também é confrontado com um vetor PBKDF2-SHA256 conhecido de uma iteração. Isso não constitui benchmark do custo de produção. A sessão protegida é substituída por memória nos testes; o Keystore depende de validação em Android real.
