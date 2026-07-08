import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _carregando = false;

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailCtrl.text.trim(), _senhaCtrl.text);
    setState(() => _carregando = false);
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.erro ?? 'Erro ao fazer login')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.sports_basketball,
                      color: AppTheme.primary, size: 72),
                  const SizedBox(height: 16),
                  Text('NBA Stats',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text('Jogadores, times e estatísticas em um só lugar',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        hintText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senhaCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        hintText: 'Senha', prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Informe a senha' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _carregando ? null : _entrar,
                    child: _carregando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text('Não tem conta? Criar conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
