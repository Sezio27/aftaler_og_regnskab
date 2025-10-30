import 'dart:async';
import 'dart:typed_data';
import 'package:aftaler_og_regnskab/data/service_cache.dart';
import 'package:aftaler_og_regnskab/data/service_repository.dart';
import 'package:aftaler_og_regnskab/model/service_model.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:flutter/material.dart';

class ServiceViewModel extends ChangeNotifier {
  ServiceViewModel(this._repo, this._imageStorage, this._cache);
  final ServiceRepository _repo;
  final ImageStorage _imageStorage;
  final ServiceCache _cache;

  StreamSubscription<List<ServiceModel>>? _sub;

  String _query = '';
  ServiceModel? _service;
  ServiceModel? get service => _service;
  List<ServiceModel> _all = const [];
  List<ServiceModel> _allFiltered = const [];
  List<ServiceModel> get allServices => _allFiltered;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  ServiceModel? getService(String id) {
    final cached = _cache.getService(id);
    if (cached != null) return cached;
    for (final s in _all) {
      if (s.id == id) {
        _cache.cacheService(s);
        return s;
      }
    }
    return null;
  }

  void initServiceFilters({String initialQuery = ''}) {
    if (_sub != null) return;
    _query = initialQuery.trim();
    _sub = _repo.watchServices().listen((items) {
      _all = items;
      _cache.cacheServices(items);
      _recompute();
    });
  }

  ServiceModel? getById(String? id) {
    if (id == null || id.isEmpty) return null;
    return _cache.getService(id);
  }

  Future<void> prefetchService(String id) async {
    if (_cache.getService(id) != null) return;
    final result = await _cache.fetchServices({id});
    final fetched = result[id];
    if (fetched != null) {
      _cache.cacheService(fetched);
      _service = fetched;
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

  Future<bool> addService({
    required String? name,
    String? description,
    String? duration,
    double? price,
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
        price: price,
        image: imageUrl,
      );
      await _repo.createServiceWithId(docRef.id, model);

      try {
        final cache = model.copyWith(id: docRef.id);
        _cache.cacheService(cache);
      } catch (_) {}

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
    double? price,
    bool clearPrice = false,
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

      if (clearPrice) {
        deletes.add('price');
      } else if (price != null) {
        fields['price'] = price;
      }

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
        final cached = _cache.getService(id);
        if (cached != null) {
          final updated = cached.copyWith(
            name: fields.containsKey('name')
                ? fields['name'] as String?
                : (deletes.contains('name') ? null : cached.name),
            description: fields.containsKey('description')
                ? fields['description'] as String?
                : (deletes.contains('description') ? null : cached.description),
            duration: fields.containsKey('duration')
                ? fields['duration'] as String?
                : (deletes.contains('duration') ? null : cached.duration),
            price: fields.containsKey('price')
                ? (fields['price'] as num?)?.toDouble()
                : (deletes.contains('price') ? null : cached.price),
            image: fields.containsKey('image')
                ? fields['image'] as String?
                : (deletes.contains('image') ? null : cached.image),
          );
          _cache.cacheService(updated);
          _all = [
            for (final s in _all)
              if (s.id == id) updated else s,
          ];
          _allFiltered = [
            for (final s in _allFiltered)
              if (s.id == id) updated else s,
          ];
        }
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

  double? priceFor(String? id) {
    if (id == null || id.isEmpty) return null;
    final s = getService(id);
    return s?.price;
  }

  Future<void> delete(String id) async {
    try {
      await _imageStorage.deleteServiceImage(id);
    } catch (_) {}
    await _repo.deleteService(id);

    _all = _all.where((s) => s.id != id).toList();
    _allFiltered = _allFiltered.where((s) => s.id != id).toList();
    // Purge from cache
    _cache.remove(id);
    notifyListeners();
  }

  void reset() {
    _sub?.cancel();
    _sub = null;
    _query = '';
    _service = null;
    _all = const [];
    _allFiltered = const [];
    notifyListeners();
  }
}
