import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/domain.dart';
import '../providers/app_state.dart';
import '../widgets/shared.dart';
import '../widgets/activity_card.dart';

class RegisterActivityScreen extends StatefulWidget {
  final Activity activity;
  const RegisterActivityScreen({super.key, required this.activity});
  @override
  State<RegisterActivityScreen> createState() => _RegisterActivityScreenState();
}

class _RegisterActivityScreenState extends State<RegisterActivityScreen> {
  final quantity = TextEditingController(), watts = TextEditingController();
  final reference = TextEditingController();
  final form = GlobalKey<FormState>();
  late final String operation;
  bool saved = false;
  @override
  void initState() {
    super.initState();
    operation = context.read<AppState>().auth.passwords.randomToken();
    if (widget.activity.type == ScoringType.unique) quantity.text = '1';
  }

  @override
  void dispose() {
    quantity.dispose();
    watts.dispose();
    reference.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final state = context.read<AppState>();
    if (saved || state.busy || !form.currentState!.validate()) return;
    var delta = 0;
    final oldLevel = state.level.number;
    final success = await state.run(() async {
      delta = await state.activities.register(
          userId: state.account!.id,
          activityId: widget.activity.id,
          quantity: int.parse(quantity.text),
          operationId: operation,
          actionReference: reference.text,
          watts: watts.text.isEmpty
              ? null
              : double.parse(watts.text.replaceAll(',', '.')));
      saved = true;
      await state.refresh();
    });
    if (!mounted) return;
    if (success || saved) {
      final promotion = state.level.number > oldLevel
          ? ' Você subiu para ${state.level.name}!'
          : '';
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ação registrada! +$delta XP.$promotion')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>(), a = widget.activity;
    final totals = state.periods[a.id] ?? const PeriodTotals();
    final before = totals.quantity;
    final completed = a.type == ScoringType.unique && totals.completed;
    final input = int.tryParse(quantity.text) ?? 0;
    return Scaffold(
        appBar: AppBar(title: const Text('Registrar ação')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Icon(activityIcon(a.code),
                      size: 64, color: const Color(0xFF2E7D32)),
                  const SizedBox(height: 16),
                  Text(a.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                      '${a.type.label} · ${periodLabel(a, state.activities.clock())}'),
                  if (a.code == 'carro_eletrico')
                    const Text(
                        'Sem emissões pelo escapamento não significa impacto ambiental zero: geração de eletricidade e ciclo de vida também importam.'),
                  const Text(
                      'Cada ação conta, mesmo quando não gera XP adicional.'),
                  const SizedBox(height: 24),
                  Form(
                      key: form,
                      child: Column(children: [
                        TextFormField(
                            controller: quantity,
                            readOnly: a.type == ScoringType.unique,
                            decoration: InputDecoration(
                                labelText: 'Quantidade (${a.unit})'),
                            keyboardType: TextInputType.number,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return !RegExp(r'^[0-9]+$').hasMatch(v ?? '') ||
                                      n == null ||
                                      n <= 0 ||
                                      n > 2147483647
                                  ? 'Informe um inteiro positivo até 2147483647.'
                                  : null;
                            }),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: reference,
                            maxLength: 120,
                            decoration: InputDecoration(
                                labelText: a.requiresActionReference
                                    ? 'Referência do trajeto/evento (obrigatória)'
                                    : 'Referência da ação (opcional)',
                                helperText:
                                    'Código sem dados pessoais. Repita o mesmo código apenas ao identificar o mesmo evento.',
                                helperMaxLines: 3),
                            validator: (value) => a.requiresActionReference &&
                                    (value == null || value.trim().isEmpty)
                                ? 'Identifique o trajeto ou evento real.'
                                : null),
                        if (a.code == 'luzes_apagadas') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: watts,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText:
                                      'Potência da lâmpada (W), opcional',
                                  helperText:
                                      'Use a potência indicada na etiqueta da lâmpada.'),
                              validator: (v) {
                                if (v == null || v.isEmpty) return null;
                                final n =
                                    double.tryParse(v.replaceAll(',', '.'));
                                return n == null || !n.isFinite || n <= 0
                                    ? 'Informe uma potência positiva.'
                                    : null;
                              })
                        ],
                      ])),
                  const SizedBox(height: 24),
                  SectionCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Seu progresso no período',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Text('Antes: $before ${a.unit}'),
                        Text('Depois: ${before + input} ${a.unit}'),
                        const SizedBox(height: 12),
                        Text(
                            '+${completed ? 0 : a.additional(before, input, granted: totals.xp)} XP estimados',
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text(
                            'XP no período: ${totals.xp}. Limite: ${a.limit} XP. Quantidade em ${a.unit}.'),
                        if (completed)
                          const Text('Concluída — conquista já registrada.'),
                      ])),
                  if (state.error != null)
                    Text(state.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  FilledButton.icon(
                      onPressed: state.busy || saved || completed ? null : save,
                      icon: const Icon(Icons.check),
                      label: Text(
                          state.busy ? 'Salvando…' : 'Confirmar registro')),
                  const SizedBox(height: 16),
                  const Text(
                      'O XP final considera o acumulado do período na confirmação. Somente registros do momento atual são aceitos, no horário local do dispositivo; não há lançamento retroativo.'),
                ]))));
  }
}
