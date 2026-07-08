// services/auth_service.dart
import 'api_client.dart';

class AuthService {
  final _api = ApiClient.instance;

  Future<void> login(String email, String senha) async {
    final resp = await _api.post(
      '/auth/login',
      body: {
        'email': email, 
        'senha': senha,
      },
      auth: false,
    );

    // Sincronizado com o retorno do backend Python (access_token)
    final token = resp is Map ? resp['access_token'] : null;

    if (token == null) {
      throw ApiException(500,
          'Login retornou sucesso, mas nenhum token foi encontrado na resposta.');
    }

    await _api.saveToken(token.toString());
  }

  Future<void> criarConta({
    required String nome,
    required String email,
    required String equipe,
    required String cargo,
    required String senha,
    required String confirmacaoSenha,
  }) async {
    await _api.post(
      '/auth/criar_conta',
      body: {
        'nome': nome,
        'email': email,
        'equipe': equipe,
        'cargo': cargo,
        'senha': senha,
        'confirmacao_senha': confirmacaoSenha, // Sincronizado com UsuarioSchema do Python
        'ativo': true,
      },
      auth: false,
    );
  }

  Future<void> refreshToken() async {
    final resp = await _api.get('/auth/refresh');
    final token = resp is Map ? resp['access_token'] : null;
    if (token != null) {
      await _api.saveToken(token.toString());
    }
  }

  Future<void> deletarConta(String nomeUsuario) async {
    await _api.delete('/auth/deletar_conta/$nomeUsuario');
  }

  Future<void> logout() async {
    await _api.clearToken();
  }

  Future<bool> estaLogado() async {
    final token = await _api.getToken();
    return token != null && token.isNotEmpty;
  }
}