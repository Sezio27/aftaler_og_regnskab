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

  /// Convenience: derive a single-doc stream from the list stream (no repo change).
  Stream<ChecklistModel?> watchChecklistById(String id) => _repo
      .watchChecklists()
      .map(
        (list) => list.firstWhere(
          (c) => c.id == id,
          orElse: () => const ChecklistModel(), // will have id == null
        ),
      )
      .map((c) => c.id == null ? null : c);

  Future<ChecklistModel?> getChecklist(String id) => _repo.getChecklistOnce(id);

  // ------------ Create (single write) ------------
  /// Create from raw texts (we build full list and write once).
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
      final points = _buildPointsFromTexts(pointTexts ?? const []);
      final created = await _repo.addChecklist(
        ChecklistModel(
          name: nm,
          description: (description ?? '').trim().isEmpty
              ? null
              : description!.trim(),
          points: points, // Already numbered → one Firestore write
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

  /// Create when you already have a full list of points.
  Future<bool> addChecklistWithPoints({
    required String? name,
    String? description,
    required List<ChecklistPoint> points,
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
      final normalized = _renumber(points);
      final created = await _repo.addChecklist(
        ChecklistModel(
          name: nm,
          description: (description ?? '').trim().isEmpty
              ? null
              : description!.trim(),
          points: normalized,
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

    final nextNumber = (m.points.isEmpty ? 0 : m.points.last.number) + 1;
    final updated = [
      ...m.points,
      ChecklistPoint(id: _newPointId(), number: nextNumber, text: t),
    ];
    await _repo.setPoints(checklistId, updated);
  }

  Future<void> updatePointText(
    String checklistId, {
    required String pointId,
    required String newText,
  }) async {
    final t = newText.trim();
    final m = await _getFromCacheOrFetch(checklistId);
    if (m == null) return;

    if (t.isEmpty) {
      await removePoint(checklistId, pointId);
      return;
    }

    final idx = m.points.indexWhere((p) => p.id == pointId);
    if (idx < 0) return;

    final p = m.points[idx];
    final updated = [...m.points]
      ..[idx] = ChecklistPoint(id: p.id, number: p.number, text: t);
    await _repo.setPoints(checklistId, updated);
  }

  Future<void> removePoint(String checklistId, String pointId) async {
    final m = await _getFromCacheOrFetch(checklistId);
    if (m == null) return;

    final filtered = m.points.where((p) => p.id != pointId).toList();
    await _repo.setPoints(checklistId, _renumber(filtered));
  }

  /// Replace all points at once (e.g., after drag-reorder).
  Future<void> setPoints(
    String checklistId,
    List<ChecklistPoint> points,
  ) async {
    await _repo.setPoints(checklistId, _renumber(points));
  }

  // ------------ Utils ------------
  Future<ChecklistModel?> _getFromCacheOrFetch(String id) async {
    // Try cache first
    final cached = _all.firstWhere(
      (c) => c.id == id,
      orElse: () => const ChecklistModel(),
    );
    if (cached.id != null) return cached;

    // Fallback to Firestore
    return _repo.getChecklistOnce(id);
  }

  String _newPointId() => DateTime.now().microsecondsSinceEpoch.toString();

  List<ChecklistPoint> _buildPointsFromTexts(List<String> texts) {
    final cleaned = texts.where((t) => t.trim().isNotEmpty).toList();
    return List.generate(cleaned.length, (i) {
      final raw = cleaned[i].trim();
      // Accept "1: Haircolor" or "1) ..." or "1. ..." — else auto-number
      final m = RegExp(r'^\s*(\d+)\s*[:.)-]?\s*(.*)$').firstMatch(raw);
      final number = (m != null)
          ? int.tryParse(m.group(1)!) ?? (i + 1)
          : (i + 1);
      final body = (m != null ? m.group(2) : raw)!.trim();
      return ChecklistPoint(id: _newPointId(), number: number, text: body);
    }).sortedByNumber(); // keep user numbers if they provided them
  }

  List<ChecklistPoint> _renumber(List<ChecklistPoint> points) {
    // Keep current order; enforce 1..N
    return List.generate(points.length, (i) {
      final p = points[i];
      return ChecklistPoint(id: p.id, number: i + 1, text: p.text);
    });
  }
}

// Small local extension to sort by number when building from texts.
extension _SortPoints on List<ChecklistPoint> {
  List<ChecklistPoint> sortedByNumber() {
    final copy = [...this];
    copy.sort((a, b) => a.number.compareTo(b.number));
    return copy;
  }
}
