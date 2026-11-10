import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/domain.dart';
import '../providers/app_state.dart';
import '../widgets/shared.dart';
import '../widgets/activity_card.dart';
import '../core/constants/activity_categories.dart';
import 'register_activity_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int selected = 0;
  String category = 'Todas';
  String query = '';
  final searchController = TextEditingController();
  bool weekly = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AppState>().auth;
      final code = auth.lastRecoveryCode;
      if (code == null) return;
      auth.lastRecoveryCode = null;
      showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialog) => PopScope(
              canPop: false,
              child: AlertDialog(
                  title: const Text('Guarde seu código de recuperação'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'Este código permite recuperar sua conta offline. Guarde em um local seguro fora do aplicativo. Ele será mostrado apenas agora.'),
                    const SizedBox(height: 16),
                    SelectableText(code),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('Guardei meu código'))
                  ])));
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final app = context.read<AppState>();
      app.run(app.refresh);
    }
  }

  void open(Activity activity) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => RegisterActivityScreen(activity: activity)));
  Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold)));
  List<Widget> home(AppState s) => [
        Text('Olá, ${s.account!.name.split(' ').first}',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Cultive um futuro melhor, uma ação por vez.'),
        const SizedBox(height: 24),
        ProgressCard(xp: s.xp),
        ImpactCard(data: s.summary),
        title('Qual será sua próxima ação?'),
        ...s.catalog.take(3).map((a) => activityCard(s, a)),
        FilledButton.tonal(
            onPressed: () => setState(() => selected = 1),
            child: Text('Explorar as ${s.catalog.length} atividades')),
        const SizedBox(height: 16),
        const Text(
            'Seu progresso é salvo neste dispositivo.\nSustentabilidade urbana · ODS 7 e ODS 11',
            textAlign: TextAlign.center),
      ];
  Widget activityCard(AppState s, Activity a) {
    return ActivityCard(
        activity: a,
        totals: s.periods[a.id] ?? const PeriodTotals(),
        now: s.activities.clock(),
        onRegister: s.busy ? null : () => open(a));
  }

  List<Widget> activities(AppState s) => [
        title('Ações para uma cidade melhor'),
        TextField(
            controller: searchController,
            key: const ValueKey('activity-search'),
            decoration: const InputDecoration(
                labelText: 'Buscar atividade', prefixIcon: Icon(Icons.search)),
            onChanged: (value) => setState(() => query = value)),
        const SizedBox(height: 12),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: ['Todas', ...ActivityCategory.all.map((c) => c.code)]
                    .map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            avatar: c == 'Todas'
                                ? null
                                : Icon(ActivityCategory.byCode(c).icon,
                                    size: 18,
                                    color: ActivityCategory.byCode(c).color),
                            label: Text(c == 'Todas'
                                ? c
                                : ActivityCategory.byCode(c).label),
                            selected: category == c,
                            onSelected: (_) => setState(() => category = c))))
                    .toList())),
        const SizedBox(height: 20),
        ...s.catalog
            .where((a) =>
                (category == 'Todas' || a.category == category) &&
                searchText(
                        '${a.name} ${a.code} ${ActivityCategory.byCode(a.category).label}')
                    .contains(searchText(query)))
            .map((a) => activityCard(s, a)),
        if (!s.catalog.any((a) =>
            (category == 'Todas' || a.category == category) &&
            searchText(
                    '${a.name} ${a.code} ${ActivityCategory.byCode(a.category).label}')
                .contains(searchText(query))))
          const SectionCard(
              child: Text(
                  'Nenhuma atividade encontrada. Altere a busca ou a categoria.')),
        const SectionCard(
            child: Text(
                'Impactos ambientais: as quantidades são autodeclaradas. Carros elétricos não emitem gases pelo escapamento, mas a geração de energia e o ciclo de vida também têm impactos. Não há fator de CO2 validado neste MVP.')),
      ];
  List<Widget> ranking(AppState s) {
    final rows = weekly ? s.weekly : s.general;
    return [
      title('Juntos, fazemos mais'),
      const Text('Ranking local · Apenas contas deste dispositivo'),
      const SizedBox(height: 20),
      SegmentedButton<bool>(segments: const [
        ButtonSegment(value: true, label: Text('Semana atual')),
        ButtonSegment(value: false, label: Text('Geral'))
      ], selected: {
        weekly
      }, onSelectionChanged: (v) => setState(() => weekly = v.single)),
      const SizedBox(height: 12),
      const Text(
          'Semana: segunda a domingo. Empates: cadastro mais antigo e ID.'),
      const SizedBox(height: 20),
      if (rows.isEmpty) const Text('Ainda não há participantes.'),
      for (var i = 0; i < rows.length; i++)
        Card(
            color:
                rows[i]['id'] == s.account!.id ? const Color(0xFFE8F5E9) : null,
            child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(
                    '${rows[i]['nome']}${rows[i]['id'] == s.account!.id ? ' (você)' : ''}'),
                subtitle: Text(
                    'Nível ${Level.forXp(rows[i]['total_xp'] as int).number}'),
                trailing: Text('${rows[i]['xp']} XP'))),
    ];
  }

  Future<void> changePassword(AppState s) async {
    final current = TextEditingController(),
        next = TextEditingController(),
        confirm = TextEditingController();
    String? error;
    bool saving = false;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => StatefulBuilder(
            builder: (context, setDialog) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                    title: const Text('Alterar senha'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: current,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Senha atual')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: next,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Nova senha')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: confirm,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'Confirmar nova senha')),
                      if (error != null) Text(error!),
                    ])),
                    actions: [
                      TextButton(
                          onPressed:
                              saving ? null : () => Navigator.pop(dialog),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  setDialog(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    await s.auth.changePassword(s.account!,
                                        current.text, next.text, confirm.text);
                                    if (dialog.mounted) Navigator.pop(dialog);
                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text('Senha alterada.')));
                                    }
                                  } catch (e) {
                                    if (dialog.mounted) {
                                      setDialog(() {
                                        error = e is DomainError
                                            ? e.message
                                            : 'Não foi possível alterar a senha.';
                                        saving = false;
                                      });
                                    }
                                  }
                                },
                          child: Text(saving ? 'Salvando…' : 'Salvar'))
                    ]))));
    // Esperar o encerramento da animação antes de descartar os controladores.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  List<Widget> profile(AppState s) => [
        const CircleAvatar(
            radius: 36, child: Icon(Icons.person_outline, size: 42)),
        const SizedBox(height: 16),
        Text(s.account!.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
        Text(s.account!.email, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ProgressCard(xp: s.xp),
        ImpactCard(data: s.summary),
        OutlinedButton.icon(
            onPressed: s.busy ? null : () => changePassword(s),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Alterar senha com autenticação')),
        title('Seu histórico'),
        if (s.history.isEmpty)
          const SectionCard(
              child: Text(
                  'Sua jornada começa com a primeira ação. Registre uma atividade!')),
        ...s.history.map((r) => Card(
            child: ListTile(
                leading: Icon(activityIcon(r['codigo'] as String)),
                title: Text('${r['nome']}'),
                subtitle: Text(
                    '${r['quantidade']} ${r['unidade']} · ${r['data_local']}\n${ScoringType.parse(r['tipo_pontuacao'] as String).label}: ${r['chave_periodo']} · ${r['versao_regra']}'),
                isThreeLine: true,
                trailing: Text('+${r['xp_concedido']} XP')))),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: s.busy ? null : s.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Sair da conta')),
      ];
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final contents = switch (selected) {
      0 => home(s),
      1 => activities(s),
      2 => ranking(s),
      _ => profile(s)
    };
    return Scaffold(
      appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.eco, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('EcoHabit')
          ]),
          actions: [
            IconButton(
                tooltip: 'Atualizar',
                onPressed: s.busy ? null : () => s.run(s.refresh),
                icon: const Icon(Icons.refresh))
          ]),
      body: Column(children: [
        if (s.busy) const LinearProgressIndicator(),
        if (s.error != null)
          MaterialBanner(content: Text(s.error!), actions: [
            TextButton(
                onPressed: () => s.run(s.refresh),
                child: const Text('Tentar novamente'))
          ]),
        Expanded(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: RefreshIndicator(
                        onRefresh: () async {
                          await s.run(s.refresh);
                        },
                        child: ListView(
                            key: ValueKey(selected),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            children: contents)))))
      ]),
      bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) => setState(() => selected = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Início'),
            NavigationDestination(
                icon: Icon(Icons.eco_outlined), label: 'Atividades'),
            NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined), label: 'Ranking'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Perfil')
          ]),
    );
  }
}
