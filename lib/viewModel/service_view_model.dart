import 'dart:async';
import 'dart:typed_data';

import 'package:aftaler_og_regnskab/data/service_repository.dart';
import 'package:aftaler_og_regnskab/model/serviceModel.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ServiceViewModel extends ChangeNotifier {
  ServiceViewModel(this._repo, this._imageStorage);
  final ServiceRepository _repo;
  final ImageStorage _imageStorage;

  StreamSubscription<List<ServiceModel>>? _sub;

  String _query = '';

  List<ServiceModel> _all = const [];
  List<ServiceModel> _allFiltered = const [];
  List<ServiceModel> get allServices => _allFiltered;
  final Map<String, ServiceModel> _serviceCache = {};

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void initServiceFilters({String initialQuery = ''}) {
    if (_sub != null) return;
    _query = initialQuery.trim();

    _sub = _repo.watchServices().listen((items) {
      _all = items;
      _serviceCache
        ..clear()
        ..addEntries(
          items
              .where((s) => (s.id ?? '').isNotEmpty)
              .map((s) => MapEntry(s.id!, s)),
        );
      _recompute();
    });
  }

  ServiceModel? getById(String? id) {
    if (id == null || id.isEmpty) return null;
    return _serviceCache[id];
  }

  Future<void> prefetchService(String id) async {
    if (_serviceCache.containsKey(id)) return;
    final one = await _repo.getServiceOnce(id);
    if (one != null && (one.id ?? '').isNotEmpty) {
      _serviceCache[one.id!] = one;
      notifyListeners();
    }
  }

  void setServiceSearch(String q) {
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
    // 1) search
    final q = _query.toLowerCase();
    bool m(String? v) => (v ?? '').toLowerCase().contains(q);

    final searched = q.isEmpty ? _all : _all.where((c) => m(c.name)).toList();

    _allFiltered = searched;
    notifyListeners();
  }

  Stream<List<ServiceModel>> get servicesStream => _repo.watchServices();
  Stream<ServiceModel?> watchService(String id) => _repo.watchService(id);

  bool _saving = false;
  String? _error;
  ServiceModel? _lastAdded;

  bool get saving => _saving;
  String? get error => _error;
  ServiceModel? get lastAdded => _lastAdded;

  ServiceModel? getService(String id) {
    final cached = _serviceCache[id];
    if (cached != null) return cached;

    for (final s in _all) {
      if (s.id == id) {
        _serviceCache[id] = s;
        return s;
      }
    }
    return null;
  }

  Future<bool> addService({
    required String? name,
    String? description,
    String? duration,
    String? price,
    ({Uint8List bytes, String name, String? mimeType})? image,
  }) async {
    final nm = (name ?? '').trim();
    if (nm.isEmpty) {
      _error = 'Angiv navn på servicen';
      notifyListeners();
      return false;
    }

    _saving = true;
    _error = null;
    notifyListeners();

    try {
      final docRef = _repo.newServiceRef();
      String? imageUrl;

      if (image != null) {
        debugPrint('upload start');
        imageUrl = await _imageStorage.uploadServiceImage(
          serviceId: docRef.id,
          image: image,
        );
        debugPrint('upload done: $imageUrl');
      }

      final model = ServiceModel(
        name: nm.isEmpty ? null : nm,
        description: (description ?? '').trim().isEmpty
            ? null
            : description!.trim(),
        duration: (duration ?? '').trim().isEmpty ? null : duration!.trim(),
        price: (price ?? '').trim().isEmpty ? null : price!.trim(),
        image: imageUrl,
      );
      await _repo.createServiceWithId(docRef.id, model);

      _lastAdded = model;
      return true;
    } catch (e) {
      _error = 'Kunne ikke tilføje service: ${e.toString()}';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> updateServiceFields(
    String id, {
    String? name,
    String? description,
    String? duration,
    String? price,
    ({Uint8List bytes, String name, String? mimeType})? newImage,
    bool removeImage = false,
  }) async {
    try {
      _saving = true;
      _error = null;
      notifyListeners();

      final fields = <String, Object?>{};
      final deletes = <String>{};

      // if provided:
      //   empty string => delete
      //   non-empty    => set value
      //   null         => untouched
      void put(String k, String? v) {
        if (v == null) return;
        final t = v.trim();
        if (t.isEmpty) {
          deletes.add(k);
        } else {
          fields[k] = t;
        }
      }

      put('name', name);
      put('description', description);
      put('duration', duration);
      put('price', price);

      // Image precedence: new image > remove flag
      if (newImage != null) {
        final url = await _imageStorage.uploadServiceImage(
          serviceId: id,
          image: newImage,
        );
        fields['image'] = url;
      } else if (removeImage) {
        deletes.add('image');
        // optional storage cleanup
        try {
          await _imageStorage.deleteServiceImage(id);
        } catch (_) {}
      }

      if (fields.isNotEmpty || deletes.isNotEmpty) {
        await _repo.updateService(id, fields: fields, deletes: deletes);
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

  // in ServiceViewModel
  String? priceFor(String? id) {
    if (id == null) return null;
    for (final s in _all) {
      if (s.id == id) {
        final p = (s.price ?? '').trim();
        return p.isEmpty ? null : p;
      }
    }
    return null;
  }

  Future<void> delete(String id) async {
    // Try deleting the image first; ignore if it doesn’t exist.
    try {
      await _imageStorage.deleteServiceImage(id);
    } catch (_) {}
    await _repo.deleteService(id);
  }
}
