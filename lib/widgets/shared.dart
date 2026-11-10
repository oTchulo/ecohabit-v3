import 'package:flutter/material.dart';
import '../models/domain.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  const SectionCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) =>
      Card(child: Padding(padding: const EdgeInsets.all(20), child: child));
}

class ProgressCard extends StatelessWidget {
  final int xp;
  const ProgressCard({super.key, required this.xp});
  @override
  Widget build(BuildContext context) {
    final level = Level.forXp(xp);
    return SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.eco, color: Color(0xFF2E7D32), size: 36),
        const SizedBox(width: 12),
        Expanded(
            child: Text('Nível ${level.number} · ${level.name}',
                style: Theme.of(context).textTheme.titleMedium))
      ]),
      const SizedBox(height: 20),
      Text('$xp XP', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 12),
      TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 400),
          tween: Tween(begin: 0, end: level.progress(xp)),
          builder: (_, value, child) => LinearProgressIndicator(
              value: value,
              minHeight: 10,
              borderRadius: BorderRadius.circular(8))),
      const SizedBox(height: 10),
      Text(level.number == 5
          ? 'Nível máximo alcançado!'
          : '${Level.all[level.number].threshold - xp} XP para o próximo nível'),
    ]));
  }
}

class ImpactCard extends StatelessWidget {
  final Map<String, Object?> data;
  const ImpactCard({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    String number(Object? value, String unit) => value == null
        ? 'Não calculado'
        : '${(value as num).toStringAsFixed(3)} $unit';
    Widget indicator(IconData icon, String text) => Row(children: [
          Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]);
    return SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Seu impacto estimado',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      indicator(
          Icons.eco_outlined, 'CO2 evitado: ${number(data['co2'], 'kg')}'),
      const SizedBox(height: 8),
      indicator(Icons.bolt_outlined, 'Energia: ${number(data['kwh'], 'kWh')}'),
      const SizedBox(height: 8),
      indicator(Icons.check_circle_outline,
          'Ações registradas: ${data['acoes'] ?? 0}'),
      const SizedBox(height: 12),
      const Text(
          'Estimativas, não medições. Energia considera apenas registros com potência informada. CO2 aguarda fatores validados.',
          style: TextStyle(color: Color(0xFF757575), fontSize: 12)),
    ]));
  }
}

IconData activityIcon(String code) => switch (code) {
      'garrafas_pet' || 'latinhas' || 'papel_papelao' => Icons.recycling,
      'bicicleta' => Icons.directions_bike,
      'caminhada' => Icons.directions_walk,
      'carro_eletrico' => Icons.electric_car_outlined,
      'carona' => Icons.people_outline,
      'transporte_publico' => Icons.directions_bus_outlined,
      'luzes_apagadas' => Icons.lightbulb_outline,
      'aparelhos_desligados' => Icons.power_settings_new,
      'energia_solar' || 'instalar_solar' => Icons.solar_power_outlined,
      'eletronicos' => Icons.devices_other,
      'banho_reduzido' => Icons.shower_outlined,
      'agua_reutilizada' || 'vazamento_corrigido' => Icons.water_drop_outlined,
      'copos_evitados' => Icons.local_drink_outlined,
      'sacola_reutilizavel' => Icons.shopping_bag_outlined,
      'arvores_plantadas' => Icons.forest_outlined,
      'criar_composteira' => Icons.compost_outlined,
      _ => Icons.eco_outlined,
    };
