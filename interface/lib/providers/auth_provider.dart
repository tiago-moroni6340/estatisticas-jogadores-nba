import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();

  bool _logado = false;
  bool _carregando = true;
  String? erro;

  bool get logado => _logado;
  bool get carregando => _carregando;

  AuthProvider() {
    _verificarSessao();
  }

  Future<void> _verificarSessao() async {
    _logado = await _authService.estaLogado();
    _carregando = false;
    notifyListeners();
  }

  Future<bool> login(String email, String senha) async {
    erro = null;
    try {
      await _authService.login(email, senha);
      _logado = true;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      erro = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      erro = 'Não foi possível conectar à API. Verifique a URL configurada.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> criarConta({
    required String nome,
    required String email,
    required String equipe,
    required String cargo,
    required String senha,
    required String confirmacaoSenha,
  }) async {
    erro = null;
    try {
      await _authService.criarConta(
        nome: nome,
        email: email,
        equipe: equipe,
        cargo: cargo,
        senha: senha,
        confirmacaoSenha: confirmacaoSenha,
      );
      return true;
    } on ApiException catch (e) {
      erro = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _logado = false;
    notifyListeners();
  }
}
