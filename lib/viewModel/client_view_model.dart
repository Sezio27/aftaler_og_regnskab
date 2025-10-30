import 'dart:async';
import 'dart:typed_data';

import 'package:aftaler_og_regnskab/data/client_cache.dart';
import 'package:aftaler_og_regnskab/data/client_repository.dart';
import 'package:aftaler_og_regnskab/model/client_model.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:flutter/material.dart';

class ClientViewModel extends ChangeNotifier {
  ClientViewModel(this._repo, this._imageStorage, this._cache);
  final ClientRepository _repo;
  final ImageStorage _imageStorage;
  final ClientCache _cache;

  StreamSubscription<List<ClientModel>>? _sub;
  final Map<String, StreamSubscription<ClientModel?>> _clientSubscriptions = {};

  String _query = '';
  List<ClientModel> _all = const [];
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
    for (final s in _clientSubscriptions.values) {
      s.cancel();
    }
    _clientSubscriptions.clear();
    super.dispose();
  }

  void subscribeToClient(String id) {
    if (_clientSubscriptions.containsKey(id)) return;
    _clientSubscriptions[id] = _repo.watchClient(id).listen((doc) {
      if (doc != null) {
        _cache.cacheClient(doc);
      } else {
        _cache.remove(id);
      }
      notifyListeners();
    });
  }

  void unsubscribeFromClient(String id) {
    _clientSubscriptions.remove(id)?.cancel();
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
      _all = items;
      _cache.cacheClients(items);
      _recompute();
    });
  }

  ClientModel? getClient(String id) {
    final fromCache = _cache.getClient(id);
    if (fromCache != null) return fromCache;

    // manual search to allow returning null safely
    for (final c in _all) {
      if (c.id == id) return c;
    }
    return null;
  }

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

    final searched = q.isEmpty
        ? _all
        : _all
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
    ({Uint8List bytes, String name, String? mimeType})?
    image, // keep as URL string (upload to Storage elsewhere)
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

      if (image != null) {
        imageUrl = await _imageStorage.uploadClientImage(
          clientId: docRef.id,
          image: image,
        );
      }

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

      final created = model.copyWith(id: docRef.id);
      _cache.cacheClient(created);
      _all = [..._all, created];
      _recompute(); // single notify inside

      return true;
    } catch (e) {
      _error = 'Kunne ikke tilføje klient: ${e.toString()}';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
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

      if (fields.isNotEmpty || deletes.isNotEmpty) {
        await _repo.updateClient(id, fields: fields, deletes: deletes);
      }

      // Optional: best-effort cache touch
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

  Future<void> delete(String id) async {
    try {
      await _imageStorage.deleteClientImage(id);
    } catch (_) {}

    await _repo.deleteClient(id);
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
    _private = const [];
    _business = const [];
    notifyListeners();
  }
}
