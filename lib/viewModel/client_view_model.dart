import 'package:aftaler_og_regnskab/data/client_repository.dart';
import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:flutter/material.dart';

class ClientViewModel extends ChangeNotifier {
  ClientViewModel(this._repo);
  final ClientRepository _repo;

  Stream<List<ClientModel>> get clientsStream => _repo.watchClients();

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
    String? imageUrl, // keep as URL string (upload to Storage elsewhere)
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

      final created = await _repo.addClient(model);
      _lastAdded = created;
      return true;
    } catch (e) {
      _error = 'Kunne ikke tilføje klient: ${e.toString()}';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> delete(String id) => _repo.deleteClient(id);
}
