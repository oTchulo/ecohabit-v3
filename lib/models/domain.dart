import 'dart:math';

class Account {
  final int id;
  final String name, email;
  const Account(this.id, this.name, this.email);
  factory Account.fromMap(Map<String, Object?> row) =>
      Account(row['id'] as int, row['nome'] as String, row['email'] as String);
}

class Band {
  final int min;
  final int? max;
  final int xp;
  const Band(this.min, this.max, this.xp);
}

class Activity {
  final int id, limit;
  final String name, category, unit;
  final List<Band> bands;
  const Activity(
      this.id, this.name, this.category, this.unit, this.limit, this.bands);
  int score(int quantity) {
    if (quantity <= 0) return 0;
    for (final band in bands) {
      if (quantity >= band.min && (band.max == null || quantity <= band.max!)) {
        return min(limit, band.xp);
      }
    }
    return 0;
  }

  int additional(int before, int quantity) =>
      max(0, score(before + quantity) - score(before));
}

class Level {
  final int number, threshold;
  final String name;
  const Level(this.number, this.name, this.threshold);
  static const all = [
    Level(1, 'Iniciante Verde', 0),
    Level(2, 'Amigo da Natureza', 200),
    Level(3, 'Protetor Ambiental', 500),
    Level(4, 'Guardião Verde', 1000),
    Level(5, 'Mestre Sustentável', 2000),
  ];
  static Level forXp(int xp) => all.lastWhere((l) => xp >= l.threshold);
  double progress(int xp) => number == 5
      ? 1
      : ((xp - threshold) / (all[number].threshold - threshold))
          .clamp(0, 1)
          .toDouble();
}

String localDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime weekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);

class DomainError implements Exception {
  final String message;
  const DomainError(this.message);
  @override
  String toString() => message;
}
