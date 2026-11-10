import 'package:flutter/material.dart';

class ActivityCategory {
  final String code, label;
  final IconData icon;
  final Color color;
  const ActivityCategory(this.code, this.label, this.icon, this.color);
  static const all = [
    ActivityCategory('MOBILIDADE', 'Mobilidade sustentável',
        Icons.directions_bike, Color(0xFF1565C0)),
    ActivityCategory('ENERGIA', 'Energia', Icons.bolt, Color(0xFF9C6500)),
    ActivityCategory(
        'RECICLAGEM', 'Reciclagem', Icons.recycling, Color(0xFF2E7D32)),
    ActivityCategory(
        'AGUA', 'Água', Icons.water_drop_outlined, Color(0xFF007C91)),
    ActivityCategory('CONSUMO', 'Consumo consciente',
        Icons.shopping_bag_outlined, Color(0xFF795548)),
    ActivityCategory(
        'NATUREZA', 'Natureza', Icons.forest_outlined, Color(0xFF558B2F)),
  ];
  static ActivityCategory byCode(String code) =>
      all.firstWhere((category) => category.code == code,
          orElse: () => const ActivityCategory(
              'OUTRA', 'Outra atividade', Icons.eco, Color(0xFF2E7D32)));
}

String searchText(String value) {
  var result = value.toLowerCase().trim();
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'é': 'e',
    'ê': 'e',
    'í': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ü': 'u',
    'ç': 'c'
  };
  replacements.forEach((from, to) {
    result = result.replaceAll(from, to);
  });
  return result;
}
