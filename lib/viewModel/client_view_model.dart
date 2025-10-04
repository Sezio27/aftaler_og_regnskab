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

  // UI input
  String _query = '';

  // Derived lists (already filtered by search & CVR)
  List<ClientModel> _all = const [];
  List<ClientModel> _allFiltered = const [];
  List<ClientModel> _private = const [];
  List<ClientModel> _business = const [];

  // Public getters (read-only views)
  List<ClientModel> get allClients => _allFiltered;
  List<ClientModel> get privateClients => _private;
  List<ClientModel> get businessClients => _business;

  int get privateCount => _private.length;
  int get businessCount => _business.length;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void initClientFilters({String initialQuery = ''}) {
    if (_sub != null) return; // already initialized
    _query = initialQuery.trim();

    _sub = _repo.watchClients().listen((items) {
      _all = items;
      _recompute();
    });
  }

  // ---- UI actions ----
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
    // 1) search
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
  bool _hasCvr(ClientModel c) => (c.cvr ?? '').trim().isNotEmpty;

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

  // Optional: for changing a client’s photo later
  Future<bool> updateClientPhoto(String clientId, XFile photo) async {
    try {
      _saving = true;
      notifyListeners();
      final url = await _imageStorage.uploadClientImage(
        clientId: clientId,
        file: photo,
      );
      await _repo.updateClient(clientId, fields: {'image': url});
      return true;
    } catch (e) {
      _error = 'Kunne ikke opdatere billede: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Stream<List<ClientModel>> filteredClients(String query, {bool? hasCvr}) {
    final q = query.trim().toLowerCase();
    return clientsStream.map((items) {
      bool m(String? v) => (v ?? '').toLowerCase().contains(q);
      var result = q.isEmpty
          ? items
          : items.where((c) => m(c.name) || m(c.phone) || m(c.email)).toList();
      bool _hasCvr(ClientModel c) => (c.cvr ?? '').trim().isNotEmpty;
      if (hasCvr != null) {
        result = result
            .where((c) => hasCvr ? _hasCvr(c) : !_hasCvr(c))
            .toList();
      }
      return result;
    });
  }

  Future<void> delete(String id) => _repo.deleteClient(id);
}
