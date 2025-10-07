import 'dart:async';
import 'package:aftaler_og_regnskab/data/checklist_repository.dart';
import 'package:aftaler_og_regnskab/model/checklistModel.dart';
import 'package:flutter/material.dart';

class ChecklistViewModel extends ChangeNotifier {
  ChecklistViewModel(this._repo);
  final ChecklistRepository _repo;

  StreamSubscription<List<ChecklistModel>>? _sub;

  String _query = '';
  List<ChecklistModel> _all = const [];
  List<ChecklistModel> _allFiltered = const [];
  List<ChecklistModel> get allChecklists => _allFiltered;

  bool _saving = false;
  String? _error;
  ChecklistModel? _lastAdded;

  bool get saving => _saving;
  String? get error => _error;
  ChecklistModel? get lastAdded => _lastAdded;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ------------ Filters / search ------------
  void initChecklistFilters({String initialQuery = ''}) {
    if (_sub != null) return; // already wired
    _query = initialQuery.trim();
    _sub = _repo.watchChecklists().listen((items) {
      _all = items;
      _recompute();
    });
  }

  void setChecklistSearch(String q) {
    final nq = q.trim();
    if (nq == _query) return;
    _query = nq;
    _recompute();
  }

  void clearSearch() {
    if (_query.isEmpty) return;
    _query = '';
    _recompute();
  }

  void _recompute() {
    final q = _query.toLowerCase();
    bool m(String? v) => (v ?? '').toLowerCase().contains(q);
    final searched = q.isEmpty
        ? _all
        : _all.where((c) => m(c.name) || m(c.description)).toList();
    _allFiltered = searched;
    notifyListeners();
  }

  // ------------ Streams / fetch ------------
  Stream<List<ChecklistModel>> get checklistsStream => _repo.watchChecklists();

  /// Latest checklist (repo orders by createdAt in Firestore).
  Stream<ChecklistModel?> watchLatestChecklist() => _repo.watchChecklist();

  /// Derive single-doc stream without repo change.
  Stream<ChecklistModel?> watchChecklistById(String id) => _repo
      .watchChecklists()
      .map(
        (list) => list.firstWhere(
          (c) => c.id == id,
          orElse: () => const ChecklistModel(),
        ),
      )
      .map((c) => c.id == null ? null : c);

  Future<ChecklistModel?> getChecklist(String id) => _repo.getChecklistOnce(id);

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
      _lastAdded = created;
      return true;
    } catch (e) {
      _error = 'Kunne ikke tilføje checklist: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Create when you already have a full list (single write).
  Future<bool> addChecklistWithPoints({
    required String? name,
    String? description,
    required List<String> points,
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
      final clean = _normalize(points);
      final created = await _repo.addChecklist(
        ChecklistModel(
          name: nm,
          description: (description ?? '').trim().isEmpty
              ? null
              : description!.trim(),
          points: clean,
        ),
      );
      _lastAdded = created;
      return true;
    } catch (e) {
      _error = 'Kunne ikke tilføje checklist: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // ------------ Update (fields only) ------------
  Future<bool> updateChecklistFields(
    String id, {
    String? name,
    String? description,
  }) async {
    try {
      _saving = true;
      _error = null;
      notifyListeners();

      final fields = <String, Object?>{};
      void put(String k, String? v) {
        if (v == null) return;
        final t = v.trim();
        fields[k] = t.isEmpty ? null : t;
      }

      put('name', name);
      put('description', description);

      if (fields.isNotEmpty) {
        await _repo.updateChecklist(id, fields: fields);
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
  }

  // ------------ Points (always single-write replace) ------------
  Future<void> addPoint(String checklistId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    final m = await _getFromCacheOrFetch(checklistId);
    if (m == null) return;

    final updated = [...m.points, t];
    await _repo.setPoints(checklistId, _normalize(updated));
  }

  Future<void> updatePointAt(
    String checklistId, {
    required int index,
    required String newText,
  }) async {
    final t = newText.trim();
    final m = await _getFromCacheOrFetch(checklistId);
    if (m == null) return;

    final list = [...m.points];
    if (index < 0 || index >= list.length) return;

    if (t.isEmpty) {
      // treat empty as remove
      list.removeAt(index);
    } else {
      list[index] = t;
    }
    await _repo.setPoints(checklistId, _normalize(list));
  }

  Future<void> removePointAt(String checklistId, int index) async {
    final m = await _getFromCacheOrFetch(checklistId);
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
  Future<ChecklistModel?> _getFromCacheOrFetch(String id) async {
    final cached = _all.firstWhere(
      (c) => c.id == id,
      orElse: () => const ChecklistModel(),
    );
    if (cached.id != null) return cached;
    return _repo.getChecklistOnce(id);
  }

  List<String> _normalize(List<String> points) =>
      points.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}
