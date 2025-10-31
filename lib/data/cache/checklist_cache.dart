import 'package:aftaler_og_regnskab/data/checklist_repository.dart';
import 'package:aftaler_og_regnskab/model/checklist_model.dart';

class ChecklistCache {
  ChecklistCache(this._checklistRepository);

  final ChecklistRepository _checklistRepository;

  final Map<String, ChecklistModel?> _cache = {};

  /// Store a single client in the cache.
  void cacheChecklist(ChecklistModel model) {
    final id = model.id;
    if (id != null) _cache[id] = model;
  }

  /// Store multiple clients in the cache at once.
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
  void remove(String id) => _cache.remove(id);
  void clear() => _cache.clear();
}
