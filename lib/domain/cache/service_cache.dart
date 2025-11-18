import 'package:aftaler_og_regnskab/data/repositories/service_repository.dart';
import 'package:aftaler_og_regnskab/domain/service_model.dart';

class ServiceCache {
  ServiceCache(this._serviceRepo);

  final ServiceRepository _serviceRepo;

  final Map<String, ServiceModel?> _serviceCache = {};

  void cacheService(ServiceModel model) {
    final id = model.id;
    if (id != null) _serviceCache[id] = model;
  }

  void cacheServices(Iterable<ServiceModel> models) {
    for (final s in models) {
      final id = s.id;
      if (id != null) _serviceCache[id] = s;
    }
  }

  Future<Map<String, ServiceModel?>> fetchServices(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final missing = ids.where((id) => !_serviceCache.containsKey(id)).toSet();
    if (missing.isNotEmpty) {
      final batched = await _serviceRepo.getServices(missing);
      _serviceCache.addAll(batched);
    }
    return {for (final id in ids) id: _serviceCache[id]};
  }

  ServiceModel? getService(String id) => _serviceCache[id];
  List<ServiceModel> get allCachedServices =>
      _serviceCache.values.whereType<ServiceModel>().toList(growable: false);

  void remove(String id) => _serviceCache.remove(id);
  void clear() => _serviceCache.clear();
}
