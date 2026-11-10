import 'package:flutter/material.dart';
import '../core/constants/activity_categories.dart';
import '../models/domain.dart';
import 'shared.dart';

class ActivityCard extends StatelessWidget {
  final Activity activity;
  final PeriodTotals totals;
  final DateTime now;
  final VoidCallback? onRegister;
  const ActivityCard(
      {super.key,
      required this.activity,
      required this.totals,
      required this.now,
      this.onRegister});
  @override
  Widget build(BuildContext context) {
    final category = ActivityCategory.byCode(activity.category);
    final complete = activity.type == ScoringType.unique && totals.completed;
    return SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(
            backgroundColor: category.color.withValues(alpha: .12),
            child: Icon(activityIcon(activity.code), color: category.color)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(activity.name,
                style: Theme.of(context).textTheme.titleMedium))
      ]),
      const SizedBox(height: 12),
      Text(category.label, style: TextStyle(color: category.color)),
      const SizedBox(height: 4),
      Text('${activity.type.label} · ${periodLabel(activity, now)}'),
      const SizedBox(height: 12),
      Text('Quantidade: ${totals.quantity} ${activity.unit}'),
      Text('XP conquistado: ${totals.xp} / ${activity.limit} XP'),
      const SizedBox(height: 8),
      LinearProgressIndicator(
          value: (totals.xp / activity.limit).clamp(0, 1),
          borderRadius: BorderRadius.circular(8)),
      const SizedBox(height: 8),
      Text(
          'Limite por ${activity.type == ScoringType.daily ? 'dia' : activity.type == ScoringType.monthly ? 'mês' : 'usuário'}: ${activity.limit} XP · ODS ${activity.ods}'),
      const SizedBox(height: 8),
      Wrap(
          spacing: 6,
          children: activity.bands
              .map((band) => Chip(
                  label: Text(
                      '${band.min}${band.max == band.min ? '' : band.max == null ? '+' : '–${band.max}'}: ${band.xp} XP',
                      style: const TextStyle(fontSize: 11))))
              .toList()),
      const SizedBox(height: 8),
      Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
              onPressed: complete ? null : onRegister,
              icon: Icon(complete ? Icons.check_circle : Icons.add),
              label: Text(complete ? 'Concluída' : 'Registrar'))),
    ]));
  }
}

String periodLabel(Activity activity, DateTime now) => switch (activity.type) {
      ScoringType.daily => 'Dia ${activity.periodKey(now)}',
      ScoringType.monthly => 'Mês ${activity.periodKey(now)}',
      ScoringType.unique => 'Uma vez por usuário',
    };
