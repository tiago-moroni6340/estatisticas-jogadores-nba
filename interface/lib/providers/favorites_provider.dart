import 'package:flutter/foundation.dart';
import '../services/favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final _service = FavoritesService();
  Set<int> _ids = {};

  Set<int> get ids => _ids;

  FavoritesProvider() {
    _carregar();
  }

  Future<void> _carregar() async {
    _ids = await _service.carregar();
    notifyListeners();
  }

  bool isFavorito(int id) => _ids.contains(id);

  Future<void> alternar(int id) async {
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    notifyListeners();
    await _service.salvar(_ids);
  }
}
