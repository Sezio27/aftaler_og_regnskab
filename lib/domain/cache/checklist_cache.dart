import 'package:aftaler_og_regnskab/data/repositories/checklist_repository.dart';
import 'package:aftaler_og_regnskab/domain/checklist_model.dart';

class ChecklistCache {
  ChecklistCache(this._checklistRepository);

  final ChecklistRepository _checklistRepository;

  final Map<String, ChecklistModel?> _cache = {};

  void cacheChecklist(ChecklistModel model) {
    final id = model.id;
    if (id != null) _cache[id] = model;
  }

  void cacheChecklists(Iterable<ChecklistModel> models) {
    for (final c in models) {
      final id = c.id;
      if (id != null) _cache[id] = c;
    }
  }

  Future<Map<String, ChecklistModel?>> fetchChecklists(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final missing = ids.where((id) => !_cache.containsKey(id)).toSet();
    if (missing.isNotEmpty) {
      final batched = await _checklistRepository.getChecklists(missing);
      _cache.addAll(batched);
    }
    return {for (final id in ids) id: _cache[id]};
  }

  ChecklistModel? getChecklist(String id) => _cache[id];
  List<ChecklistModel> get allCachedChecklists =>
      _cache.values.whereType<ChecklistModel>().toList(growable: false);
  void remove(String id) => _cache.remove(id);
  void clear() => _cache.clear();
}
