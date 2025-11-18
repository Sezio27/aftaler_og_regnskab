import 'dart:async';
import 'package:aftaler_og_regnskab/domain/cache/checklist_cache.dart';
import 'package:aftaler_og_regnskab/data/repositories/checklist_repository.dart';
import 'package:aftaler_og_regnskab/domain/checklist_model.dart';
import 'package:flutter/material.dart';

class ChecklistViewModel extends ChangeNotifier {
  ChecklistViewModel(this._repo, this._cache);
  final ChecklistRepository _repo;
  final ChecklistCache _cache;

  StreamSubscription<List<ChecklistModel>>? _sub;

  String _query = '';
  List<ChecklistModel> _allFiltered = const [];
  List<ChecklistModel> get allChecklists => _allFiltered;

  bool _saving = false;
  String? _error;

  bool get saving => _saving;
  String? get error => _error;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void initChecklistFilters({String initialQuery = ''}) {
    if (_sub != null) return;
    _query = initialQuery.trim();
    _sub = _repo.watchChecklists().listen((items) {
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

  ChecklistModel? getChecklist(String id) => _cache.getChecklist(id);

  void clearSearch() {
    if (_query.isEmpty) return;
    _query = '';
    _recompute();
  }

  void _recompute() {
    final q = _query.toLowerCase();
    bool matches(String? v) => (v ?? '').toLowerCase().contains(q);
    final checklists = _cache.allCachedChecklists;
    final searched = q.isEmpty
        ? checklists
        : checklists
              .where((c) => matches(c.name) || matches(c.description))
              .toList();
    _allFiltered = searched;
    notifyListeners();
  }

  Future<void> prefetchChecklists(Iterable<String> ids) async {
    final missing = <String>{
      for (final id in ids)
        if (_cache.getChecklist(id) == null) id,
    };
    if (missing.isEmpty) return;

    final res = await _cache.fetchChecklists(missing);
    if (res.values.any((v) => v != null)) notifyListeners();
  }

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
        _recompute();
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
      handleUpdateFields(fields, name, description, points);

      if (fields.isNotEmpty) {
        await _repo.updateChecklist(id, fields: fields);
        cacheUpdated(id, fields);
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

  void cacheUpdated(String id, Map<String, Object?> fields) {
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
      _recompute();
    }
  }

  void handleUpdateFields(
    Map<String, Object?> fields,
    String? name,
    String? description,
    List<String>? points,
  ) {
    void put(String k, String? v) {
      if (v == null) return;
      final t = v.trim();
      fields[k] = t.isEmpty ? null : t;
    }

    void putPoints(List<String>? pts) {
      if (pts == null) return;
      final cleaned = <String>[
        for (final p in pts)
          if (p.trim().isNotEmpty) p.trim(),
      ];
      fields['points'] = cleaned;
    }

    put('name', name);
    put('description', description);
    putPoints(points);
  }

  Future<void> delete(String id) async {
    await _repo.deleteChecklist(id);
    _cache.remove(id);
    _recompute();
  }

  void reset() {
    _sub?.cancel();
    _sub = null;
    _query = '';
    _allFiltered = const [];
    notifyListeners();
  }

  List<String> _normalize(List<String> points) =>
      points.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}
