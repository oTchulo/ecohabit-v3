import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import '../models/domain.dart';
import '../services/password_service.dart';

abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  final FlutterSecureStorage storage;
  const SecureSessionStore(
      [this.storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true))]);
  @override
  Future<String?> read() => storage.read(key: 'session_account');
  @override
  Future<void> write(String value) =>
      storage.write(key: 'session_account', value: value);
  @override
  Future<void> clear() => storage.delete(key: 'session_account');
}

class AuthRepository {
  final Database db;
  final SessionStore session;
  final PasswordService passwords;
  String? lastRecoveryCode;
  AuthRepository(this.db, this.session, {PasswordService? passwords})
      : passwords = passwords ?? PasswordService();

  static String? validate(
      String name, String email, String password, String confirm) {
    if (name.trim().isEmpty) return 'Informe seu nome completo.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      return 'Informe um e-mail válido.';
    }
    if (password.length < 8) return 'A senha deve ter pelo menos 8 caracteres.';
    if (password != confirm) return 'As senhas não coincidem.';
    return null;
  }

  Future<Account> register(
      String name, String email, String password, String confirm) async {
    final error = validate(name, email, password, confirm);
    if (error != null) throw DomainError(error);
    final salt = passwords.randomToken(16);
    final hash = await passwords.derive(password, salt);
    final recovery = passwords.randomToken();
    final recoverySalt = passwords.randomToken(16);
    final recoveryHash = await passwords.derive(recovery, recoverySalt);
    int id;
    try {
      id = await db.transaction((txn) async {
        final id = await txn.insert('usuarios', {
          'nome': name.trim(),
          'email': email.trim().toLowerCase(),
          'senha_hash': hash,
          'senha_salt': salt,
          'senha_iteracoes': PasswordService.iterations,
          'criado_em': DateTime.now().toUtc().toIso8601String()
        });
        await txn.insert('recuperacao', {
          'usuario_id': id,
          'codigo_hash': recoveryHash,
          'codigo_salt': recoverySalt,
          'iteracoes': PasswordService.iterations
        });
        return id;
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const DomainError('Este e-mail já está cadastrado.');
      }
      rethrow;
    }
    await session.write('$id');
    lastRecoveryCode = recovery;
    return Account(id, name.trim(), email.trim().toLowerCase());
  }

  Future<Account> login(String email, String password) async {
    final rows = await db.query('usuarios',
        where: 'email = ?', whereArgs: [email.trim().toLowerCase()]);
    if (rows.isEmpty || !await passwords.verify(password, rows.first)) {
      throw const DomainError('E-mail ou senha inválidos.');
    }
    final account = Account.fromMap(rows.first);
    await session.write('${account.id}');
    return account;
  }

  Future<Account?> restore() async {
    final value = await session.read();
    if (value == null) return null;
    final rows = await db.query('usuarios',
        where: 'id = ?', whereArgs: [int.tryParse(value) ?? -1]);
    if (rows.isEmpty) {
      await session.clear();
      return null;
    }
    return Account.fromMap(rows.first);
  }

  Future<void> logout() => session.clear();
  Future<String> recover(
      String email, String code, String password, String confirm) async {
    final error = validate('Recuperação', email, password, confirm);
    if (error != null) throw DomainError(error);
    final rows = await db.rawQuery('''SELECT u.id, r.codigo_hash AS senha_hash,
      r.codigo_salt AS senha_salt, r.iteracoes AS senha_iteracoes
      FROM usuarios u JOIN recuperacao r ON r.usuario_id=u.id WHERE u.email = ?''',
        [email.trim().toLowerCase()]);
    if (rows.isEmpty || !await passwords.verify(code.trim(), rows.single)) {
      throw const DomainError('E-mail ou código de recuperação inválidos.');
    }
    final oldHash = rows.single['senha_hash'];
    final salt = passwords.randomToken(16),
        nextCode = passwords.randomToken(),
        recoverySalt = passwords.randomToken(16);
    final hash = await passwords.derive(password, salt);
    final recoveryHash = await passwords.derive(nextCode, recoverySalt);
    await db.transaction((txn) async {
      final changed = await txn.update(
          'recuperacao',
          {
            'codigo_hash': recoveryHash,
            'codigo_salt': recoverySalt,
            'iteracoes': PasswordService.iterations
          },
          where: 'usuario_id = ? AND codigo_hash = ?',
          whereArgs: [rows.single['id'], oldHash]);
      if (changed != 1) throw const DomainError('Código já utilizado.');
      await txn.update(
          'usuarios',
          {
            'senha_hash': hash,
            'senha_salt': salt,
            'senha_iteracoes': PasswordService.iterations
          },
          where: 'id = ?',
          whereArgs: [rows.single['id']]);
    });
    await session.clear();
    return nextCode;
  }

  Future<void> changePassword(
      Account account, String current, String password, String confirm) async {
    final error = validate(account.name, account.email, password, confirm);
    if (error != null) throw DomainError(error);
    final row =
        (await db.query('usuarios', where: 'id = ?', whereArgs: [account.id]))
            .single;
    if (!await passwords.verify(current, row)) {
      throw const DomainError('Senha atual inválida.');
    }
    final salt = passwords.randomToken(16);
    final hash = await passwords.derive(password, salt);
    await db.update(
        'usuarios',
        {
          'senha_hash': hash,
          'senha_salt': salt,
          'senha_iteracoes': PasswordService.iterations
        },
        where: 'id = ?',
        whereArgs: [account.id]);
  }
}
