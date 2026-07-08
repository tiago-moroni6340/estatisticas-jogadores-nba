import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _equipe = TextEditingController();
  final _cargo = TextEditingController();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _carregando = false;

  InputDecoration _dec(String hint) => InputDecoration(hintText: hint);

  String? _obrigatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_senha.text != _confirmacao.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('As senhas não coincidem')));
      return;
    }
    setState(() => _carregando = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.criarConta(
      nome: _nome.text,
      email: _email.text,
      equipe: _equipe.text,
      cargo: _cargo.text,
      senha: _senha.text,
      confirmacaoSenha: _confirmacao.text,
    );
    setState(() => _carregando = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta criada! Faça login.')));
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.erro ?? 'Erro ao criar conta')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                    controller: _nome,
                    decoration: _dec('Nome'),
                    validator: _obrigatorio),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _email,
                    decoration: _dec('E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'E-mail inválido' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _equipe,
                    decoration: _dec('Equipe'),
                    validator: _obrigatorio),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _cargo,
                    decoration: _dec('Cargo'),
                    validator: _obrigatorio),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _senha,
                    decoration: _dec('Senha'),
                    obscureText: true,
                    validator: _obrigatorio),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _confirmacao,
                    decoration: _dec('Confirmar senha'),
                    obscureText: true,
                    validator: _obrigatorio),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _carregando ? null : _cadastrar,
                  child: _carregando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Cadastrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
