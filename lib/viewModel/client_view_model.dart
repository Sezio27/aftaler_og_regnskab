import 'dart:async';
import 'dart:typed_data';

import 'package:aftaler_og_regnskab/domain/cache/client_cache.dart';
import 'package:aftaler_og_regnskab/data/repositories/client_repository.dart';
import 'package:aftaler_og_regnskab/domain/client_model.dart';
import 'package:aftaler_og_regnskab/data/services/image_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClientViewModel extends ChangeNotifier {
  ClientViewModel(this._repo, this._imageStorage, this._cache);
  final ClientRepository _repo;
  final ImageStorage _imageStorage;
  final ClientCache _cache;

  StreamSubscription<List<ClientModel>>? _sub;

  String _query = '';

  List<ClientModel> _allFiltered = const [];
  List<ClientModel> _private = const [];
  List<ClientModel> _business = const [];

  List<ClientModel> get allClients => _allFiltered;
  List<ClientModel> get privateClients => _private;
  List<ClientModel> get businessClients => _business;

  int get privateCount => _private.length;
  int get businessCount => _business.length;

  bool _saving = false;
  String? _error;

  bool get saving => _saving;
  String? get error => _error;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<ClientModel?> prefetchClient(String id) async {
    final cached = _cache.getClient(id);
    if (cached != null) return cached;

    final res = await _cache.fetchClients({id});
    final fetched = res[id];
    if (fetched != null) notifyListeners();
    return fetched;
  }

  void initClientFilters({String initialQuery = ''}) {
    if (_sub != null) return;
    _query = initialQuery.trim();

    _sub = _repo.watchClients().listen((items) {
      _cache.cacheClients(items);
      _recompute();
    });
  }

  ClientModel? getClient(String id) => _cache.getClient(id);

  void setClientSearch(String q) {
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

    final clients = _cache.allCachedClients;

    final searched = q.isEmpty
        ? clients
        : clients
              .where(
                (c) => matches(c.name) || matches(c.phone) || matches(c.email),
              )
              .toList();

    _allFiltered = searched;
    _business = searched.where((c) => (c.cvr ?? '').trim().isNotEmpty).toList();
    _private = searched.where((c) => (c.cvr ?? '').trim().isEmpty).toList();
    notifyListeners();
  }

  Future<bool> addClient({
    required String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? postal,
    String? cvr,
    ({Uint8List bytes, String name, String? mimeType})? image,
  }) async {
    final nm = (name ?? '').trim();
    final em = (email ?? '').trim();
    if (nm.isEmpty && em.isEmpty) {
      _error = 'Angiv mindst navn eller e-mail';
      notifyListeners();
      return false;
    }
    _saving = true;
    _error = null;
    notifyListeners();

    try {
      final docRef = _repo.newClientRef();
      String? imageUrl;

      imageUrl = await handleUploadImage(image, imageUrl, docRef);

      final model = ClientModel(
        name: nm.isEmpty ? null : nm,
        phone: (phone ?? '').trim().isEmpty ? null : phone!.trim(),
        email: em.isEmpty ? null : em,
        address: (address ?? '').trim().isEmpty ? null : address!.trim(),
        city: (city ?? '').trim().isEmpty ? null : city!.trim(),
        postal: (postal ?? '').trim().isEmpty ? null : postal!.trim(),
        cvr: (cvr ?? '').trim().isEmpty ? null : cvr!.trim(),
        image: imageUrl,
      );
      await _repo.createClientWithId(docRef.id, model);

      cacheNewClient(model, docRef);

      return true;
    } catch (e) {
      _error = 'Kunne ikke tilføje klient: ${e.toString()}';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void cacheNewClient(
    ClientModel model,
    DocumentReference<Map<String, dynamic>> docRef,
  ) {
    final created = model.copyWith(id: docRef.id);
    _cache.cacheClient(created);
    _recompute();
  }

  Future<String?> handleUploadImage(
    ({Uint8List bytes, String? mimeType, String name})? image,
    String? imageUrl,
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    if (image != null) {
      imageUrl = await _imageStorage.uploadClientImage(
        clientId: docRef.id,
        image: image,
      );
    }
    return imageUrl;
  }

  Future<bool> updateClientFields(
    String id, {
    String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? postal,
    String? cvr,
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
        phone,
        email,
        address,
        city,
        postal,
        cvr,
        newImage,
        id,
        removeImage,
      );

      if (fields.isNotEmpty || deletes.isNotEmpty) {
        await _repo.updateClient(id, fields: fields, deletes: deletes);
        cacheUpdatedClient(id, fields, deletes);
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

  void cacheUpdatedClient(
    String id,
    Map<String, Object?> fields,
    Set<String> deletes,
  ) {
    final cached = _cache.getClient(id);
    if (cached != null) {
      final updated = cached.copyWith(
        name: fields.containsKey('name')
            ? fields['name'] as String?
            : (deletes.contains('name') ? null : cached.name),
        phone: fields.containsKey('phone')
            ? fields['phone'] as String?
            : (deletes.contains('phone') ? null : cached.phone),
        email: fields.containsKey('email')
            ? fields['email'] as String?
            : (deletes.contains('email') ? null : cached.email),
        address: fields.containsKey('address')
            ? fields['address'] as String?
            : (deletes.contains('address') ? null : cached.address),
        city: fields.containsKey('city')
            ? fields['city'] as String?
            : (deletes.contains('city') ? null : cached.city),
        postal: fields.containsKey('postal')
            ? fields['postal'] as String?
            : (deletes.contains('postal') ? null : cached.postal),
        cvr: fields.containsKey('cvr')
            ? fields['cvr'] as String?
            : (deletes.contains('cvr') ? null : cached.cvr),
        image: fields.containsKey('image')
            ? fields['image'] as String?
            : (deletes.contains('image') ? null : cached.image),
      );

      _cache.cacheClient(updated);
      _recompute();
    }
  }

  Future<void> handleUpdateFields(
    Set<String> deletes,
    Map<String, Object?> fields,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? postal,
    String? cvr,
    ({Uint8List bytes, String? mimeType, String name})? newImage,
    String id,
    bool removeImage,
  ) async {
    void put(String key, String? v) {
      if (v == null) return;
      final t = v.trim();
      if (t.isEmpty) {
        deletes.add(key);
      } else {
        fields[key] = t;
      }
    }

    put('name', name);
    put('phone', phone);
    put('email', email);
    put('address', address);
    put('city', city);
    put('postal', postal);
    put('cvr', cvr);

    if (newImage != null) {
      final url = await _imageStorage.uploadClientImage(
        clientId: id,
        image: newImage,
      );
      fields['image'] = url;
    } else if (removeImage) {
      deletes.add('image');

      try {
        await _imageStorage.deleteClientImage(id);
      } catch (_) {}
    }
  }

  Future<void> delete(String id) async {
    try {
      await _imageStorage.deleteClientImage(id);
    } catch (_) {}

    await _repo.deleteClient(id);
    _cache.remove(id);
    _recompute();
  }

  void reset() {
    _sub?.cancel();
    _sub = null;
    _query = '';
    _allFiltered = const [];
    _private = const [];
    _business = const [];
    notifyListeners();
  }
}
