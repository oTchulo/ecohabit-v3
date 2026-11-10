import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/domain.dart';
import '../providers/app_state.dart';
import '../widgets/shared.dart';

class RegisterActivityScreen extends StatefulWidget {
  final Activity activity;
  const RegisterActivityScreen({super.key, required this.activity});
  @override
  State<RegisterActivityScreen> createState() => _RegisterActivityScreenState();
}

class _RegisterActivityScreenState extends State<RegisterActivityScreen> {
  final quantity = TextEditingController(), watts = TextEditingController();
  final form = GlobalKey<FormState>();
  late final String operation;
  bool saved = false;
  @override
  void initState() {
    super.initState();
    operation = context.read<AppState>().auth.passwords.randomToken();
  }

  @override
  void dispose() {
    quantity.dispose();
    watts.dispose();
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
          watts: watts.text.isEmpty
              ? null
              : double.parse(watts.text.replaceAll(',', '.')));
      saved = true;
      await state.refresh();
    });
    if (!mounted) return;
    if (success) {
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
    final before = state.quantities[a.id] ?? 0;
    final input = int.tryParse(quantity.text) ?? 0;
    return Scaffold(
        appBar: AppBar(title: const Text('Registrar ação')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Icon(activityIcon(a.id),
                      size: 64, color: const Color(0xFF2E7D32)),
                  const SizedBox(height: 16),
                  Text(a.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                      'Cada ação conta, mesmo quando não gera XP adicional.'),
                  const SizedBox(height: 24),
                  Form(
                      key: form,
                      child: Column(children: [
                        TextFormField(
                            controller: quantity,
                            decoration: InputDecoration(
                                labelText: 'Quantidade (${a.unit})'),
                            keyboardType: TextInputType.number,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n <= 0 || n > 2147483647
                                  ? 'Informe um inteiro positivo até 2147483647.'
                                  : null;
                            }),
                        if (a.id == 3) ...[
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
                        Text('Seu dia, em evolução',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Text('Antes: $before ${a.unit}'),
                        Text('Depois: ${before + input} ${a.unit}'),
                        const SizedBox(height: 12),
                        Text('+${a.additional(before, input)} XP estimados',
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text(
                            'Limite configurado: ${a.limit} XP/dia. A maior faixa atual concede ${a.bands.last.xp} XP.'),
                      ])),
                  if (state.error != null)
                    Text(state.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  FilledButton.icon(
                      onPressed: state.busy || saved ? null : save,
                      icon: const Icon(Icons.check),
                      label: Text(
                          state.busy ? 'Salvando…' : 'Confirmar registro')),
                  const SizedBox(height: 16),
                  const Text(
                      'O XP final é calculado na confirmação, considerando o total do dia no horário do dispositivo.'),
                ]))));
  }
}
