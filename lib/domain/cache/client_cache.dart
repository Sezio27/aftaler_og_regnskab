import 'package:aftaler_og_regnskab/data/repositories/client_repository.dart';
import 'package:aftaler_og_regnskab/domain/client_model.dart';

class ClientCache {
  ClientCache(this._clientRepo);

  final ClientRepository _clientRepo;

  final Map<String, ClientModel?> _clientCache = {};

  void cacheClient(ClientModel model) {
    final id = model.id;
    if (id != null) _clientCache[id] = model;
  }

  void cacheClients(Iterable<ClientModel> models) {
    for (final c in models) {
      final id = c.id;
      if (id != null) _clientCache[id] = c;
    }
  }

  Future<Map<String, ClientModel?>> fetchClients(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final missing = ids.where((id) => !_clientCache.containsKey(id)).toSet();
    if (missing.isNotEmpty) {
      final batched = await _clientRepo.getClients(missing);
      _clientCache.addAll(batched);
    }
    return {for (final id in ids) id: _clientCache[id]};
  }

  ClientModel? getClient(String id) => _clientCache[id];
  void remove(String id) => _clientCache.remove(id);
  void clear() => _clientCache.clear();
}
