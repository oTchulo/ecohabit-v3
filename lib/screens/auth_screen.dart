import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../repositories/auth_repository.dart';
import '../models/domain.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool signup = false, hidden = true;
  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    final ok = signup
        ? await state.register(
            _name.text, _email.text, _password.text, _confirm.text)
        : await state.login(_email.text, _password.text);
    if (ok && mounted) {
      _password.clear();
      _confirm.clear();
    }
  }

  Future<void> recover() async {
    final email = TextEditingController(text: _email.text),
        code = TextEditingController(),
        password = TextEditingController(),
        confirm = TextEditingController();
    String? error, nextCode;
    bool saving = false;
    final auth = context.read<AppState>().auth;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => StatefulBuilder(
            builder: (_, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                    title: Text(nextCode == null
                        ? 'Recuperar acesso offline'
                        : 'Guarde o novo código'),
                    content: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: nextCode != null
                                ? [
                                    const Text(
                                        'Senha redefinida. O código anterior foi invalidado. Guarde este novo código com segurança:'),
                                    const SizedBox(height: 16),
                                    SelectableText(nextCode!),
                                  ]
                                : [
                                    const Text(
                                        'Informe o código secreto entregue no cadastro. Nenhum e-mail será enviado.'),
                                    const SizedBox(height: 12),
                                    TextField(
                                        controller: email,
                                        decoration: const InputDecoration(
                                            labelText: 'E-mail')),
                                    const SizedBox(height: 12),
                                    TextField(
                                        controller: code,
                                        decoration: const InputDecoration(
                                            labelText: 'Código de recuperação'),
                                        obscureText: true),
                                    const SizedBox(height: 12),
                                    TextField(
                                        controller: password,
                                        decoration: const InputDecoration(
                                            labelText: 'Nova senha'),
                                        obscureText: true),
                                    const SizedBox(height: 12),
                                    TextField(
                                        controller: confirm,
                                        decoration: const InputDecoration(
                                            labelText: 'Confirmar senha'),
                                        obscureText: true),
                                    if (error != null) Text(error!),
                                  ])),
                    actions: [
                      TextButton(
                          onPressed:
                              saving ? null : () => Navigator.pop(dialog),
                          child: Text(nextCode == null
                              ? 'Cancelar'
                              : 'Guardei meu código')),
                      if (nextCode == null)
                        FilledButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    update(() {
                                      saving = true;
                                      error = null;
                                    });
                                    try {
                                      final result = await auth.recover(
                                          email.text,
                                          code.text,
                                          password.text,
                                          confirm.text);
                                      if (dialog.mounted) {
                                        update(() {
                                          nextCode = result;
                                          saving = false;
                                        });
                                      }
                                    } catch (e) {
                                      if (dialog.mounted) {
                                        update(() {
                                          error = e is DomainError
                                              ? e.message
                                              : 'Não foi possível recuperar o acesso. Tente novamente.';
                                          saving = false;
                                        });
                                      }
                                    }
                                  },
                            child: Text(saving ? 'Verificando…' : 'Recuperar')),
                    ]))));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    email.dispose();
    code.dispose();
    password.dispose();
    confirm.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Form(
                            key: _form,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Icon(Icons.eco,
                                      size: 72, color: Color(0xFF2E7D32)),
                                  const SizedBox(height: 12),
                                  Text('EcoHabit',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'Pequenas ações. Uma cidade melhor.',
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 36),
                                  Text(
                                      signup
                                          ? 'Comece sua jornada verde'
                                          : 'Que bom ter você por aqui',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 20),
                                  if (signup) ...[
                                    TextFormField(
                                        controller: _name,
                                        decoration: const InputDecoration(
                                            labelText: 'Nome completo'),
                                        textCapitalization:
                                            TextCapitalization.words,
                                        validator: (v) => v!.trim().isEmpty
                                            ? 'Informe seu nome.'
                                            : null),
                                    const SizedBox(height: 14)
                                  ],
                                  TextFormField(
                                      controller: _email,
                                      decoration: const InputDecoration(
                                          labelText: 'E-mail',
                                          prefixIcon: Icon(Icons.mail_outline)),
                                      keyboardType: TextInputType.emailAddress,
                                      autocorrect: false,
                                      validator: (v) =>
                                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                  .hasMatch(v!.trim())
                                              ? null
                                              : 'E-mail inválido.'),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                      controller: _password,
                                      obscureText: hidden,
                                      decoration: InputDecoration(
                                          labelText: 'Senha',
                                          prefixIcon:
                                              const Icon(Icons.lock_outline),
                                          suffixIcon: IconButton(
                                              tooltip:
                                                  'Mostrar ou ocultar senha',
                                              onPressed: () => setState(
                                                  () => hidden = !hidden),
                                              icon: Icon(hidden
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                      .visibility_off_outlined))),
                                      validator: (v) =>
                                          v!.isEmpty || (signup && v.length < 8)
                                              ? 'Use pelo menos 8 caracteres.'
                                              : null),
                                  if (signup) ...[
                                    const SizedBox(height: 14),
                                    TextFormField(
                                        controller: _confirm,
                                        obscureText: true,
                                        decoration: const InputDecoration(
                                            labelText: 'Confirmar senha'),
                                        validator: (v) =>
                                            AuthRepository.validate(
                                                _name.text,
                                                _email.text,
                                                _password.text,
                                                v ?? ''))
                                  ],
                                  if (state.error != null)
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: Text(state.error!,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error))),
                                  const SizedBox(height: 20),
                                  FilledButton(
                                      onPressed: state.busy ? null : submit,
                                      child: state.busy
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : Text(signup
                                              ? 'Criar conta'
                                              : 'Entrar')),
                                  TextButton(
                                      onPressed: state.busy
                                          ? null
                                          : () => setState(() {
                                                signup = !signup;
                                                state.error = null;
                                              }),
                                      child: Text(signup
                                          ? 'Já tenho conta'
                                          : 'Criar minha conta')),
                                  if (!signup)
                                    TextButton(
                                        onPressed: state.busy ? null : recover,
                                        child:
                                            const Text('Esqueci minha senha')),
                                  const SizedBox(height: 20),
                                  const Text(
                                      '100% offline · Dados neste dispositivo\nODS 7 e 11 · UMC',
                                      textAlign: TextAlign.center,
                                      style:
                                          TextStyle(color: Color(0xFF757575))),
                                ])))))));
  }
}
