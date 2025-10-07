import 'dart:async';
import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/data/service_repository.dart';
import 'package:aftaler_og_regnskab/model/appointmentModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// If you upload images to storage, inject a storage service like your existing ImageStorage.
/// For brevity, this VM accepts ready-made `imageUrls` or uploads via an optional callback.
typedef FetchServicePrice = Future<String?> Function(String serviceId);
typedef UploadAppointmentImages =
    Future<List<String>> Function({
      required String appointmentId,
      required List<XFile> files,
    });
typedef DeleteAppointmentImages = Future<void> Function(String appointmentId);

class AppointmentViewModel extends ChangeNotifier {
  AppointmentViewModel(
    this._repo, {
    required this.fetchServicePrice,
    this.uploadImages,
    this.deleteImages,
  });
  final AppointmentRepository _repo;
  final FetchServicePrice fetchServicePrice;
  final UploadAppointmentImages? uploadImages;
  final DeleteAppointmentImages? deleteImages;

  StreamSubscription<List<AppointmentModel>>? _sub;

  // Optional filters/search (add later if you need)
  List<AppointmentModel> _all = const [];
  List<AppointmentModel> get all => _all;

  bool _saving = false;
  String? _error;
  AppointmentModel? _lastAdded;

  bool get saving => _saving;
  String? get error => _error;
  AppointmentModel? get lastAdded => _lastAdded;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void init() {
    if (_sub != null) return;
    _sub = _repo.watchAppointments().listen((items) {
      _all = items;
      notifyListeners();
    });
  }

  // Streams / fetch
  Stream<List<AppointmentModel>> watchAppointments() =>
      _repo.watchAppointments();
  Stream<AppointmentModel?> watchLatestAppointment() =>
      _repo.watchAppointment();
  Stream<AppointmentModel?> watchAppointmentById(String id) =>
      _repo.watchAppointmentById(id);
  Future<AppointmentModel?> getAppointment(String id) =>
      _repo.getAppointmentOnce(id);

  Future<bool> addAppointment({
    required String? clientId,
    required String? serviceId,
    required DateTime? dateTime,
    required List<String> checklistIds,
    String? location,
    String? note,
    String? customPriceText,
    List<XFile>? images,
    String status = 'not_invoiced',
  }) async {
    if ((clientId ?? '').isEmpty) {
      _error = 'Vælg klient';
      notifyListeners();
      return false;
    }
    if (dateTime == null) {
      _error = 'Vælg dato og tid';
      notifyListeners();
      return false;
    }

    _saving = true;
    _error = null;
    notifyListeners();
    try {
      // resolve price
      String? servicePrice;
      if ((serviceId ?? '').isNotEmpty) {
        final sp = await fetchServicePrice(serviceId!);
        servicePrice = (sp ?? '').trim().isEmpty ? null : sp!.trim();
      }
      final custom = (customPriceText ?? '').trim();
      final price = custom.isNotEmpty ? custom : servicePrice;

      // 1) create appointment with empty imageUrls
      final created = await _repo.addAppointment(
        AppointmentModel(
          clientId: clientId,
          serviceId: serviceId,
          checklistIds: checklistIds,
          dateTime: dateTime,
          price: price,
          location: _clean(location),
          note: _clean(note),
          imageUrls: const [],
          status: status,
        ),
      );

      // 2) upload images (if any) and update doc once
      if (uploadImages != null &&
          (images?.isNotEmpty ?? false) &&
          (created.id ?? '').isNotEmpty) {
        final urls = await uploadImages!(
          appointmentId: created.id!,
          files: images!,
        );
        if (urls.isNotEmpty) {
          await _repo.updateAppointment(
            created.id!,
            fields: {'imageUrls': urls},
          );
          _lastAdded = created.copyWith(imageUrls: urls);
        } else {
          _lastAdded = created;
        }
      } else {
        _lastAdded = created;
      }

      return true;
    } catch (e) {
      _error = 'Kunne ikke oprette aftale: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // ------------ Update (patch fields) ------------
  Future<bool> updateAppointmentFields(
    String id, {
    String? clientId,
    String? serviceId,
    List<String>? checklistIds,
    DateTime? dateTime,
    String? location,
    String? note,
    String? customPrice,
    String? servicePrice,
    String? status,
    List<String>? imageUrls,
  }) async {
    try {
      _saving = true;
      _error = null;
      notifyListeners();
      final fields = <String, Object?>{};
      void put(String k, Object? v) {
        if (v != null) fields[k] = v;
      }

      put('clientId', _clean(clientId));
      put('serviceId', _clean(serviceId));
      if (checklistIds != null) {
        put(
          'checklistIds',
          checklistIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        );
      }
      if (dateTime != null) put('dateTime', Timestamp.fromDate(dateTime));
      put('location', _clean(location));
      put('note', _clean(note));
      put('status', _clean(status));
      if (imageUrls != null) {
        put(
          'imageUrls',
          imageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        );
      }

      if (customPrice != null || servicePrice != null) {
        put('price', _resolvePrice(servicePrice, customPrice));
      }

      if (fields.isNotEmpty) await _repo.updateAppointment(id, fields: fields);
      return true;
    } catch (e) {
      _error = 'Kunne ikke opdatere: $e';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // ---- delete (also remove images in storage) ----
  Future<void> delete(String id, {bool deleteStorage = true}) async {
    if (deleteStorage && deleteImages != null) {
      await deleteImages!(id);
    }
    await _repo.deleteAppointment(id);
  }

  // ---- helpers ----
  String? _resolvePrice(String? servicePrice, String? customPrice) {
    final custom = _clean(customPrice);
    if (custom != null && custom.isNotEmpty) return custom;
    final service = _clean(servicePrice);
    if (service != null && service.isNotEmpty) return service;
    return null;
  }

  String? _clean(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? null : t;
  }
}
