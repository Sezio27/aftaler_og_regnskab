import 'dart:async';
import 'package:aftaler_og_regnskab/data/checklist_cache.dart';
import 'package:aftaler_og_regnskab/data/checklist_repository.dart';
import 'package:aftaler_og_regnskab/model/checklist_model.dart';
import 'package:flutter/material.dart';

class ChecklistViewModel extends ChangeNotifier {
  ChecklistViewModel(this._repo, this._cache);
  final ChecklistRepository _repo;
  final ChecklistCache _cache;

  StreamSubscription<List<ChecklistModel>>? _sub;
  final Map<String, StreamSubscription<ChecklistModel?>>
  _checklistSubscriptions = {};

  String _query = '';
  List<ChecklistModel> _all = const [];
  List<ChecklistModel> _allFiltered = const [];
  List<ChecklistModel> get allChecklists => _allFiltered;

  bool _saving = false;
  String? _error;

  bool get saving => _saving;
  String? get error => _error;

  @override
  void dispose() {
    _sub?.cancel();
    for (final s in _checklistSubscriptions.values) {
      s.cancel();
    }
    _checklistSubscriptions.clear();
    super.dispose();
  }

  void subscribeToChecklist(String id) {
    if (_checklistSubscriptions.containsKey(id)) return;
    _checklistSubscriptions[id] = _repo.watchChecklist(id).listen((doc) {
      if (doc != null) {
        _cache.cacheChecklist(doc);
      } else {
        _cache.remove(id);
      }
      notifyListeners();
    });
  }

  void unsubscribeFromChecklist(String id) {
    _checklistSubscriptions.remove(id)?.cancel();
  }

  void initChecklistFilters({String initialQuery = ''}) {
    if (_sub != null) return;
    _query = initialQuery.trim();
    _sub = _repo.watchChecklists().listen((items) {
      _all = items;
      _cache.cacheChecklists(items);
      _recompute();
    });
  }

  void setChecklistSearch(String q) {
    final nq = q.trim();
    if (nq == _query) return;
    _query = nq;
    _recompute();
  }

  ChecklistModel? getChecklist(String id) {
    final fromCache = _cache.getChecklist(id);
    if (fromCache != null) return fromCache;

    for (final c in _all) {
      if (c.id == id) return c;
    }
    return null;
  }

  void clearSearch() {
    if (_query.isEmpty) return;
    _query = '';
    _recompute();
  }

  void _recompute() {
    final q = _query.toLowerCase();
    bool matches(String? v) => (v ?? '').toLowerCase().contains(q);
    final searched = q.isEmpty
        ? _all
        : _all.where((c) => matches(c.name) || matches(c.description)).toList();
    _allFiltered = searched;
    notifyListeners();
  }

  ChecklistModel? getById(String? id) {
    if (id == null || id.isEmpty) return null;
    return _cache.getChecklist(id);
  }

  Future<void> prefetchChecklists(Iterable<String> ids) async {
    final missing = <String>{
      for (final id in ids)
        if (_cache.getChecklist(id) == null) id,
    };
    if (missing.isEmpty) return;

    final res = await _cache.fetchChecklists(missing);
    // If any non-null came in, notify so UI can rebuild
    if (res.values.any((v) => v != null)) notifyListeners();
  }

  // ------------ Create (single write) ------------
  Future<bool> addChecklist({
    required String? name,
    String? description,
    List<String>? pointTexts,
  }) async {
    final nm = (name ?? '').trim();
    if (nm.isEmpty) {
      _error = 'Angiv navn på checklisten';
      notifyListeners();
      return false;
    }

    _saving = true;
    _error = null;
    notifyListeners();

    try {
      final cleanPoints = _normalize(pointTexts ?? const []);
      final created = await _repo.addChecklist(
        ChecklistModel(
          name: nm,
          description: (description ?? '').trim().isEmpty
              ? null
              : description!.trim(),
          points: cleanPoints,
        ),
      );

      if (created.id != null) {
        _cache.cacheChecklist(created);
        _all = [..._all, created];
        _recompute(); // single notify inside}
      }
      return true;
    } catch (e) {
      _error = 'Kunne ikke tilføje checklist: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> addChecklistWithPoints({
    required String? name,
    String? description,
    required List<String> points,
  }) async {
    return addChecklist(
      name: name,
      description: description,
      pointTexts: points,
    );
  }

  // ------------ Update (fields only) ------------
  Future<bool> updateChecklistFields(
    String id, {
    String? name,
    String? description,
    List<String>? points,
  }) async {
    _saving = true;
    _error = null;
    notifyListeners();

    try {
      final fields = <String, Object?>{};
      void put(String k, String? v) {
        if (v == null) return;
        final t = v.trim();
        fields[k] = t.isEmpty ? null : t;
      }

      void putPoints(List<String>? pts) {
        if (pts == null) return; // no change
        final cleaned = <String>[
          for (final p in pts)
            if (p.trim().isNotEmpty) p.trim(),
        ];
        fields['points'] = cleaned; // write [] if all empty
      }

      put('name', name);
      put('description', description);
      putPoints(points);

      if (fields.isNotEmpty) {
        await _repo.updateChecklist(id, fields: fields);
      }
      final cached = _cache.getChecklist(id);
      if (cached != null) {
        final updated = cached.copyWith(
          name: fields.containsKey('name')
              ? fields['name'] as String?
              : cached.name,
          description: fields.containsKey('description')
              ? fields['description'] as String?
              : cached.description,
          points: fields.containsKey('points')
              ? (fields['points'] as List<String>)
              : cached.points,
        );
        _cache.cacheChecklist(updated);
        _all = [for (final c in _all) (c.id == id) ? updated : c];
        _recompute();
      }
      return true;
    } catch (e) {
      _error = 'Kunne ikke opdatere: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // ------------ Delete ------------
  Future<void> delete(String id) async {
    await _repo.deleteChecklist(id);
    _all = _all.where((c) => c.id != id).toList();
    _allFiltered = _allFiltered.where((c) => c.id != id).toList();
    _cache.remove(id);
    notifyListeners();
  }

  void reset() {
    _sub?.cancel();
    _sub = null;
    _query = '';
    _all = const [];
    _allFiltered = const [];
    notifyListeners();
  }

  Future<void> addPoint(String checklistId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final m = await _fetchChecklist(checklistId);
    if (m == null) return;

    final updated = [...m.points, trimmed];
    await _repo.setPoints(checklistId, _normalize(updated));
  }

  Future<void> updatePointAt(
    String checklistId, {
    required int index,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    final m = await _fetchChecklist(checklistId);
    if (m == null) return;

    final list = [...m.points];
    if (index < 0 || index >= list.length) return;

    if (trimmed.isEmpty) {
      list.removeAt(index);
    } else {
      list[index] = trimmed;
    }
    await _repo.setPoints(checklistId, _normalize(list));
  }

  Future<void> removePointAt(String checklistId, int index) async {
    final m = await _fetchChecklist(checklistId);
    if (m == null) return;

    final list = [...m.points];
    if (index < 0 || index >= list.length) return;

    list.removeAt(index);
    await _repo.setPoints(checklistId, _normalize(list));
  }

  /// Replace all points at once (e.g., after drag-reorder).
  Future<void> setPoints(String checklistId, List<String> points) async {
    await _repo.setPoints(checklistId, _normalize(points));
  }

  // ------------ Utils ------------
  Future<ChecklistModel?> _fetchChecklist(String id) async {
    final cached = _cache.getChecklist(id);
    if (cached != null) return cached;

    final res = await _cache.fetchChecklists({id});
    return res[id];
  }

  List<String> _normalize(List<String> points) =>
      points.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}
