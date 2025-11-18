import 'dart:async';
import 'dart:typed_data';
import 'package:aftaler_og_regnskab/domain/cache/service_cache.dart';
import 'package:aftaler_og_regnskab/data/repositories/service_repository.dart';
import 'package:aftaler_og_regnskab/domain/service_model.dart';
import 'package:aftaler_og_regnskab/data/services/image_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ServiceViewModel extends ChangeNotifier {
  ServiceViewModel(this._repo, this._imageStorage, this._cache);
  final ServiceRepository _repo;
  final ImageStorage _imageStorage;
  final ServiceCache _cache;

  StreamSubscription<List<ServiceModel>>? _sub;

  String _query = '';
  List<ServiceModel> _allFiltered = const [];
  List<ServiceModel> get allServices => _allFiltered;

  bool _saving = false;
  String? _error;

  bool get saving => _saving;
  String? get error => _error;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  ServiceModel? getService(String id) => _cache.getService(id);

  void initServiceFilters({String initialQuery = ''}) {
    if (_sub != null) return;
    _query = initialQuery.trim();
    _sub = _repo.watchServices().listen((items) {
      _cache.cacheServices(items);
      _recompute();
    });
  }

  Future<ServiceModel?> prefetchService(String id) async {
    final cached = _cache.getService(id);
    if (cached != null) return cached;

    final result = await _cache.fetchServices({id});
    final fetched = result[id];
    if (fetched != null) notifyListeners();
    return fetched;
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
    bool matches(String? v) => (v ?? '').toLowerCase().contains(q);
    final services = _cache.allCachedServices;
    final searched = q.isEmpty
        ? services
        : services.where((s) => matches(s.name)).toList();

    _allFiltered = searched;
    notifyListeners();
  }

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

      imageUrl = await handleUploadImage(image, imageUrl, docRef);

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
      cacheNewService(model, docRef);

      return true;
    } catch (e) {
      _error = 'Kunne ikke tilføje service: ${e.toString()}';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void cacheNewService(
    ServiceModel model,
    DocumentReference<Map<String, dynamic>> docRef,
  ) {
    final created = model.copyWith(id: docRef.id);
    _cache.cacheService(created);
    _recompute();
  }

  Future<String?> handleUploadImage(
    ({Uint8List bytes, String? mimeType, String name})? image,
    String? imageUrl,
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    if (image != null) {
      imageUrl = await _imageStorage.uploadServiceImage(
        serviceId: docRef.id,
        image: image,
      );
    }
    return imageUrl;
  }

  Future<bool> updateServiceFields(
    String id, {
    String? name,
    String? description,
    String? duration,
    double? price,
    ({Uint8List bytes, String name, String? mimeType})? newImage,
    bool removeImage = false,
  }) async {
    try {
      _saving = true;
      _error = null;
      notifyListeners();

      final fields = <String, Object?>{};
      final deletes = <String>{};

      await handleUpdateFields(
        deletes,
        fields,
        name,
        description,
        duration,
        price,
        newImage,
        id,
        removeImage,
      );

      if (fields.isNotEmpty || deletes.isNotEmpty) {
        await _repo.updateService(id, fields: fields, deletes: deletes);
        cacheUpdatedService(id, fields, deletes);
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

  void cacheUpdatedService(
    String id,
    Map<String, Object?> fields,
    Set<String> deletes,
  ) {
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
      _recompute();
    }
  }

  Future<void> handleUpdateFields(
    Set<String> deletes,
    Map<String, Object?> fields,
    String? name,
    String? description,
    String? duration,
    double? price,
    ({Uint8List bytes, String? mimeType, String name})? newImage,
    String id,
    bool removeImage,
  ) async {
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

    if (price != null) {
      fields['price'] = price;
    }

    if (newImage != null) {
      final url = await _imageStorage.uploadServiceImage(
        serviceId: id,
        image: newImage,
      );
      fields['image'] = url;
    } else if (removeImage) {
      deletes.add('image');

      try {
        await _imageStorage.deleteServiceImage(id);
      } catch (_) {}
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

    cacheDelete(id);
  }

  void cacheDelete(String id) {
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
}
