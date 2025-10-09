import 'dart:async';
import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/model/appointmentModel.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/model/serviceModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

typedef UploadAppointmentImages =
    Future<List<String>> Function({
      required String appointmentId,
      required List<XFile> files,
    });
typedef DeleteAppointmentImages = Future<void> Function(String appointmentId);

typedef FetchClient = Future<ClientModel?> Function(String clientId);
typedef FetchService = Future<ServiceModel?> Function(String serviceId);

class AppointmentViewModel extends ChangeNotifier {
  AppointmentViewModel(
    this._repo, {
    required this.fetchClient,
    required this.fetchService,
    this.uploadImages,
    this.deleteImages,
  });

  final AppointmentRepository _repo;
  final FetchClient fetchClient;
  final FetchService fetchService;
  final UploadAppointmentImages? uploadImages;
  final DeleteAppointmentImages? deleteImages;

  StreamSubscription<List<AppointmentModel>>? _sub;

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

  // ---------- Create ----------
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
      // Prefer custom price; else fall back to service.price
      String? price = _clean(customPriceText);
      if ((price == null || price.isEmpty) && (serviceId ?? '').isNotEmpty) {
        final svc = await fetchService(serviceId!);
        price = _clean(svc?.price);
      }

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

  // ---------- Update (patch fields) ----------
  Future<bool> updateAppointmentFields(
    String id, {
    String? clientId,
    String? serviceId,
    List<String>? checklistIds,
    DateTime? dateTime,
    String? location,
    String? note,
    String? customPrice,
    String? servicePrice, // optional direct override
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

      // choose customPrice > servicePrice if provided
      final chosen = _firstNonEmpty([
        _clean(customPrice),
        _clean(servicePrice),
      ]);
      if (chosen != null) put('price', chosen);

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

  // ---------- Delete ----------
  Future<void> delete(String id, {bool deleteStorage = true}) async {
    if (deleteStorage && deleteImages != null) {
      await deleteImages!(id);
    }
    await _repo.deleteAppointment(id);
  }

  // ---------- Projection for Calendar UI ----------
  /// Build *UI-ready* card models for all appointments on [day] (local time).
  Future<List<AppointmentCardModel>> cardsForDate(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final todays = _all.where((a) {
      final dt = a.dateTime;
      return dt != null && !dt.isBefore(start) && dt.isBefore(end);
    }).toList()..sort((a, b) => a.dateTime!.compareTo(b.dateTime!));

    return Future.wait(
      todays.map((appt) async {
        // Fetch needed fields from related models
        ClientModel? client;
        ServiceModel? service;

        if ((appt.clientId ?? '').isNotEmpty) {
          client = await fetchClient(appt.clientId!);
        }
        if ((appt.serviceId ?? '').isNotEmpty) {
          service = await fetchService(appt.serviceId!);
        }

        // Prefer stored appointment price, else service price
        final price = _firstNonEmpty([
          _clean(appt.price),
          _clean(service?.price),
        ]);

        return AppointmentCardModel(
          clientName: _or(client?.name, 'Klient'),
          serviceName: _or(service?.name, 'Service'),
          phone: client?.phone,
          email: client?.email,
          time: appt.dateTime!,
          price: price,
          duration: service?.duration,
          status: appt.status ?? 'ufaktureret',
        );
      }).toList(),
    );
  }

  // ---------- helpers ----------
  String? _clean(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? null : t;
  }

  String? _firstNonEmpty(List<String?> xs) {
    for (final x in xs) {
      final t = (x ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  String _or(String? s, String fallback) {
    final t = (s ?? '').trim();
    return t.isEmpty ? fallback : t;
  }
}
