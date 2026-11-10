import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/domain.dart';
import '../repositories/auth_repository.dart';
import '../repositories/activity_repository.dart';

class AppState extends ChangeNotifier {
  final AuthRepository auth;
  final ActivityRepository activities;
  Account? account;
  bool busy = false, ready = false;
  String? error;
  List<Activity> catalog = [];
  Map<int, int> quantities = {};
  Map<String, Object?> summary = {};
  List<Map<String, Object?>> history = [], general = [], weekly = [];
  Timer? _timer;
  String _day = '';
  AppState(this.auth, this.activities);
  int get xp => (summary['xp'] as int?) ?? 0;
  Level get level => Level.forXp(xp);
  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e, stack) {
      if (e is! DomainError) debugPrint('EcoHabit: $e\n$stack');
      error = e is DomainError
          ? e.message
          : 'Não foi possível concluir. Tente novamente.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    await run(() async {
      account = await auth.restore();
      await refresh();
    });
    ready = true;
    notifyListeners();
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      if (account != null && !busy && _day != localDay(activities.clock())) {
        run(refresh);
      }
    });
  }

  Future<void> refresh() async {
    if (account == null) return;
    catalog = await activities.catalog();
    quantities = await activities.today(account!.id);
    summary = await activities.summary(account!.id);
    history = await activities.history(account!.id);
    general = await activities.ranking();
    weekly = await activities.ranking(weekly: true);
    _day = localDay(activities.clock());
  }

  Future<bool> login(String email, String password) => run(() async {
        account = await auth.login(email, password);
        await refresh();
      });
  Future<bool> register(
          String name, String email, String password, String confirm) =>
      run(() async {
        account = await auth.register(name, email, password, confirm);
        await refresh();
      });
  Future<bool> logout() => run(() async {
        await auth.logout();
        account = null;
        summary = {};
        quantities = {};
        history = [];
        general = [];
        weekly = [];
      });
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
