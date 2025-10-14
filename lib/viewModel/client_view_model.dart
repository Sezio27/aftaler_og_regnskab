import 'dart:async';

import 'package:aftaler_og_regnskab/data/client_repository.dart';
import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ClientViewModel extends ChangeNotifier {
  ClientViewModel(this._repo, this._imageStorage);
  final ClientRepository _repo;
  final ImageStorage _imageStorage;

  StreamSubscription<List<ClientModel>>? _sub;

  String _query = '';
  ClientModel? _client;
  List<ClientModel> _all = const [];
  List<ClientModel> _allFiltered = const [];
  List<ClientModel> _private = const [];
  List<ClientModel> _business = const [];

  ClientModel? get client => _client;
  List<ClientModel> get allClients => _allFiltered;
  List<ClientModel> get privateClients => _private;
  List<ClientModel> get businessClients => _business;

  int get privateCount => _private.length;
  int get businessCount => _business.length;

  final Map<String, ClientModel> _clientCache = {};

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> prefetchClient(String? id) async {
    final key = (id ?? '').trim();
    if (key.isEmpty) return;

    if (_clientCache.containsKey(key)) return; // already cached

    final fetched = await _repo.getClientOnce(key);
    if (fetched != null) {
      _clientCache[key] = fetched;
      // also keep _client if you still use it anywhere
      _client = fetched;
      notifyListeners(); // triggers UI rebuilds using select()
    }
  }

  void initClientFilters({String initialQuery = ''}) {
    if (_sub != null) return; // already initialized
    _query = initialQuery.trim();

    _sub = _repo.watchClients().listen((items) {
      _all = items;
      _recompute();
    });
  }

  ClientModel? getClient(String id) {
    // try cache first
    final cached = _clientCache[id];
    if (cached != null) return cached;

    // then from the list populated by initClientFilters/watchClients
    for (final c in _all) {
      if (c.id == id) {
        _clientCache[id] = c;
        return c;
      }
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
    bool m(String? v) => (v ?? '').toLowerCase().contains(q);

    final searched = q.isEmpty
        ? _all
        : _all.where((c) => m(c.name) || m(c.phone) || m(c.email)).toList();

    _allFiltered = searched;

    bool hasCvr(ClientModel c) => (c.cvr ?? '').trim().isNotEmpty;

    final business = <ClientModel>[];
    final priv = <ClientModel>[];

    for (final c in searched) {
      (hasCvr(c) ? business : priv).add(c);
      final id = (c.id ?? '').trim();
      if (id.isNotEmpty) {
        _clientCache[id] = c;
      }
    }

    _business = business;
    _private = priv;

    notifyListeners();
  }

  Stream<List<ClientModel>> get clientsStream => _repo.watchClients();
  Stream<ClientModel?> watchClient(String id) => _repo.watchClient(id);
  Future<ClientModel?> getClientOnce(String id) => _repo.getClientOnce(id);

  bool _saving = false;
  String? _error;
  ClientModel? _lastAdded;

  bool get saving => _saving;
  String? get error => _error;
  ClientModel? get lastAdded => _lastAdded;

  Future<bool> addClient({
    required String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? postal,
    String? cvr,
    XFile? image, // keep as URL string (upload to Storage elsewhere)
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
        debugPrint('upload start');
        imageUrl = await _imageStorage.uploadClientImage(
          clientId: docRef.id,
          file: image,
        );
        debugPrint('upload done: $imageUrl');
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

      _lastAdded = model;
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
    XFile? newImage,
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
      put('phone', phone);
      put('email', email);
      put('address', address);
      put('city', city);
      put('postal', postal);
      put('cvr', cvr);

      if (newImage != null) {
        final url = await _imageStorage.uploadClientImage(
          clientId: id,
          file: newImage,
        );
        fields['image'] = url;
      }

      if (fields.isNotEmpty) {
        await _repo.updateClient(id, fields: fields);
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

  Future<void> delete(String id, String? imageUrl) async {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      await _imageStorage.deleteClientImage(id);
    }
    await _repo.deleteClient(id);
  }
}
