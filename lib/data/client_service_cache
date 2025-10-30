import 'package:aftaler_og_regnskab/data/client_repository.dart';
import 'package:aftaler_og_regnskab/data/service_repository.dart';
import 'package:aftaler_og_regnskab/model/client_model.dart';
import 'package:aftaler_og_regnskab/model/service_model.dart';

class ClientServiceCache {
  ClientServiceCache(this._clientRepo, this._serviceRepo);

  final ClientRepository _clientRepo;
  final ServiceRepository _serviceRepo;

  final Map<String, ClientModel?> _clientCache = {};
  final Map<String, ServiceModel?> _serviceCache = {};

  Future<Map<String, ClientModel?>> fetchClients(Set<String> ids) async {
    final missing = ids.where((id) => !_clientCache.containsKey(id)).toSet();
    if (missing.isNotEmpty) {
      final batched = await _clientRepo.getClients(missing);
      _clientCache.addAll(batched);
    }
    return { for (final id in ids) id: _clientCache[id] };
  }

  Future<Map<String, ServiceModel?>> fetchServices(Set<String> ids) async {
    final missing = ids.where((id) => !_serviceCache.containsKey(id)).toSet();
    if (missing.isNotEmpty) {
      final batched = await _serviceRepo.getServices(missing);
      _serviceCache.addAll(batched);
    }
    return { for (final id in ids) id: _serviceCache[id] };
  }

  /// Optional getters to read cached instances directly.
  ClientModel? getClient(String id) => _clientCache[id];
  ServiceModel? getService(String id) => _serviceCache[id];
}
