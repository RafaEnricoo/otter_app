import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/device_model.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

class SmartHomeService {
  static final SmartHomeService _instance = SmartHomeService._internal();
  factory SmartHomeService() => _instance;
  SmartHomeService._internal();

  final ValueNotifier<SmarthomeState?> stateNotifier = ValueNotifier<SmarthomeState?>(null);
  
  bool _isInitialized = false;
  bool _isUsingFallback = false;

  bool get isInitialized => _isInitialized;
  bool get isUsingFallback => _isUsingFallback;
  
  SmarthomeState? _localState;
  Timer? _pollingTimer;
  int _lastSmokeValue = 0;
  bool _lastPirValue = false;
  Timer? _flameBlinkerTimer;
  Timer? _settingsNotificationTimer;
  Map<String, dynamic> _localRfidCards = {};
  final _rfidStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _rfidPollingTimer;
  final Set<String> _notifiedPendingUids = {};

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Test REST API connection
      final response = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/status')).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _localState = SmarthomeState.fromMap(data);
        stateNotifier.value = _localState;
        _isUsingFallback = false;
      } else {
        await _setupLocalFallback();
      }

      // Start periodic status polling (every 2 seconds)
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (_isUsingFallback) return;
        try {
          final res = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/status')).timeout(const Duration(seconds: 2));
          if (res.statusCode == 200) {
            final Map<String, dynamic> data = jsonDecode(res.body);
            
            final oldLockState = _localState?.perangkat.kunciPintuRfid;
            final newLockState = data['perangkat']?['kunci_pintu_rfid'] as bool?;

            _localState = SmarthomeState.fromMap(data);
            stateNotifier.value = _localState;

            if (oldLockState != null && newLockState != null && oldLockState != newLockState) {
              NotificationService().addNotification(
                title: newLockState == true ? 'RFID Pintu Terkunci' : 'RFID Pintu Terbuka',
                message: 'Pintu utama berhasil ${newLockState == true ? 'dikunci secara aman' : 'dibuka menggunakan akses RFID/Biometrik'}.',
                category: NotificationCategory.security,
                priority: newLockState == true ? NotificationPriority.info : NotificationPriority.warning,
              );
            }

            _runAutomationRulesIfNeeded();
          }
        } catch (e) {
          print("Status polling error: $e");
        }
      });

      _isInitialized = true;
    } catch (e) {
      print("API Server connection failed, using local JSON fallback: $e");
      await _setupLocalFallback();
    }
  }

  Future<void> resetDatabase() async {
    try {
      final jsonString = await rootBundle.loadString('lib/assets/firebase.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final rawData = jsonMap['otter_smarthome'] as Map<String, dynamic>;
      
      if (_isUsingFallback) {
        _localState = SmarthomeState.fromMap(rawData);
        stateNotifier.value = _localState;
        _runAutomationRulesIfNeeded();
      } else {
        await http.put(
          Uri.parse('${AppConfig.apiBaseUrl}/perangkat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(rawData['perangkat']),
        );
        await http.put(
          Uri.parse('${AppConfig.apiBaseUrl}/otomatisasi'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(rawData['otomatisasi']),
        );
      }
    } catch (e) {
      print("Reset database failed: $e");
    }
  }

  Future<void> _setupLocalFallback() async {
    try {
      _isUsingFallback = true;
      _isInitialized = true;
      
      final jsonString = await rootBundle.loadString('lib/assets/firebase.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final rawData = jsonMap['otter_smarthome'] as Map<String, dynamic>;
      
      _localState = SmarthomeState.fromMap(rawData);
      _localRfidCards = rawData['rfid_terdaftar'] as Map<String, dynamic>? ?? {};
      stateNotifier.value = _localState;
      _runAutomationRulesIfNeeded();
    } catch (e) {
      print("Local JSON load failed, using hardcoded state: $e");
      _localState = SmarthomeState(
        sensor: SmarthomeSensor(
          cahayaAtap: 80,
          dapurSuhu: 32.5,
          dapurKelembapan: 60.0,
          dapurFlame: 0,
          kamarSuhu: 28.0,
          kamarKelembapan: 55.0,
          tamuGerak: false,
        ),
        perangkat: SmarthomePerangkat(
          lampuKamar: false,
          lampuTamu: false,
          lampuKamarMandi: false,
          lampuDapur: false,
          kipasKamar: false,
          kecepatanKipas: 255,
          buzzerAlrm: false,
          ledMerahDapur: false,
          kunciPintuRfid: true,
        ),
        otomatisasi: SmarthomeOtomatisasi(
          modeAutoLampu: true,
          autoLampuKamar: true,
          autoLampuTamu: true,
          autoLampuKamarMandi: true,
          autoLampuDapur: true,
          modeAutoKipas: true,
          batasGelapLampu: 30,
          batasPanasKamar: 29.0,
        ),
      );
      stateNotifier.value = _localState;
    }
  }

  // Generic Update Methods
  Future<void> updateSensor(String key, dynamic value) async {
    if (_localState == null) return;
    
    if (_isUsingFallback) {
      final sensorMap = _localState!.sensor.toMap();
      sensorMap[key] = value;
      _localState = _localState!.copyWith(sensor: SmarthomeSensor.fromMap(sensorMap));
      stateNotifier.value = _localState;
      _runAutomationRulesIfNeeded();
    } else {
      try {
        final res = await http.post(
          Uri.parse('${AppConfig.apiBaseUrl}/sensor'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({key: value}),
        );
        if (res.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(res.body);
          if (data['status'] == 'sukses' && data['sensor'] != null) {
            final sensorMap = _localState!.sensor.toMap();
            sensorMap[key] = value;
            _localState = _localState!.copyWith(sensor: SmarthomeSensor.fromMap(sensorMap));
            stateNotifier.value = _localState;
          }
        }
      } catch (e) {
        print("Gagal update/simulasi sensor di server: $e");
      }
    }
  }

  Future<void> updatePerangkat(String key, dynamic value) async {
    if (_localState == null) return;

    final currentVal = _localState!.perangkat.toMap()[key];
    if (currentVal == value) return; // No change, don't log duplication

    String? title;
    String? message;
    NotificationCategory category = NotificationCategory.system;
    NotificationPriority priority = NotificationPriority.info;

    if (key == 'lampu_kamar') {
      title = value == true ? 'Lampu Kamar Menyala' : 'Lampu Kamar Mati';
      message = 'Lampu Kamar tidur telah ${value == true ? 'dinyalakan' : 'dimatikan'}.';
      category = NotificationCategory.system;
    } else if (key == 'lampu_tamu') {
      title = value == true ? 'Lampu Tamu Menyala' : 'Lampu Tamu Mati';
      message = 'Lampu Ruang Tamu telah ${value == true ? 'dinyalakan' : 'dimatikan'}.';
      category = NotificationCategory.system;
    } else if (key == 'lampu_kamar_mandi') {
      title = value == true ? 'Lampu Kamar Mandi Menyala' : 'Lampu Kamar Mandi Mati';
      message = 'Lampu Kamar Mandi telah ${value == true ? 'dinyalakan' : 'dimatikan'}.';
      category = NotificationCategory.system;
    } else if (key == 'lampu_dapur') {
      title = value == true ? 'Lampu Dapur Menyala' : 'Lampu Dapur Mati';
      message = 'Lampu Dapur telah ${value == true ? 'dinyalakan' : 'dimatikan'}.';
      category = NotificationCategory.system;
    } else if (key == 'kipas_kamar') {
      title = value == true ? 'Kipas Kamar Aktif' : 'Kipas Kamar Mati';
      message = 'Kipas Kamar tidur telah ${value == true ? 'dinyalakan' : 'dimatikan'}.';
      category = NotificationCategory.climate;
    } else if (key == 'buzzer_alrm') {
      title = value == true ? 'Sirine Rumah Aktif' : 'Sirine Rumah Siaga';
      message = 'Sirine keamanan darurat telah ${value == true ? 'diaktifkan' : 'dinonaktifkan'}.';
      category = NotificationCategory.security;
      priority = value == true ? NotificationPriority.critical : NotificationPriority.info;
    } else if (key == 'kunci_pintu_rfid') {
      title = value == true ? 'RFID Pintu Terkunci' : 'RFID Pintu Terbuka';
      message = 'Pintu utama berhasil ${value == true ? 'dikunci secara aman' : 'dibuka menggunakan akses RFID/Biometrik'}.';
      category = NotificationCategory.security;
      priority = value == true ? NotificationPriority.info : NotificationPriority.warning;
    } else if (key == 'kecepatan_kipas') {
      title = 'Kecepatan Kipas Diubah';
      message = 'Kecepatan kipas kamar tidur disetel ke tingkat ${value == 255 ? '3 (Maksimal)' : value == 170 ? '2 (Sedang)' : '1 (Rendah)'}.';
      category = NotificationCategory.climate;
    }

    if (title != null && message != null) {
      NotificationService().addNotification(
        title: title,
        message: message,
        category: category,
        priority: priority,
      );
    }

    String? autoLampuKeyToDisable;
    if (key == 'lampu_kamar') autoLampuKeyToDisable = 'auto_lampu_kamar';
    if (key == 'lampu_tamu') autoLampuKeyToDisable = 'auto_lampu_tamu';
    if (key == 'lampu_dapur') autoLampuKeyToDisable = 'auto_lampu_dapur';
    if (key == 'lampu_kamar_mandi') autoLampuKeyToDisable = 'auto_lampu_kamar_mandi';
    final bool disableAutoKipas = (key == 'kipas_kamar');

    if (_isUsingFallback) {
      final perangkatMap = _localState!.perangkat.toMap();
      perangkatMap[key] = value;
      
      SmarthomeOtomatisasi newOto = _localState!.otomatisasi;
      if (autoLampuKeyToDisable != null || disableAutoKipas) {
        final otoMap = _localState!.otomatisasi.toMap();
        if (autoLampuKeyToDisable != null) otoMap[autoLampuKeyToDisable] = false;
        if (disableAutoKipas) otoMap['mode_auto_kipas'] = false;
        newOto = SmarthomeOtomatisasi.fromMap(otoMap);
      }

      _localState = _localState!.copyWith(
        perangkat: SmarthomePerangkat.fromMap(perangkatMap),
        otomatisasi: newOto,
      );
      stateNotifier.value = _localState;
      _runAutomationRulesIfNeeded();
    } else {
      final updatedPerangkat = _localState!.perangkat.toMap();
      updatedPerangkat[key] = value;

      try {
        await http.put(
          Uri.parse('${AppConfig.apiBaseUrl}/perangkat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(updatedPerangkat),
        );

        if (autoLampuKeyToDisable != null || disableAutoKipas) {
          final updatedOto = _localState!.otomatisasi.toMap();
          if (autoLampuKeyToDisable != null) updatedOto[autoLampuKeyToDisable] = false;
          if (disableAutoKipas) updatedOto['mode_auto_kipas'] = false;

          await http.put(
            Uri.parse('${AppConfig.apiBaseUrl}/otomatisasi'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updatedOto),
          );
        }
      } catch (e) {
        print("Gagal update perangkat di server: $e");
      }
    }
  }

  Future<void> disarmAllAlarms() async {
    if (_localState == null) return;

    _flameBlinkerTimer?.cancel();
    _flameBlinkerTimer = null;

    NotificationService().addNotification(
      title: 'Sistem Keamanan Dinonaktifkan',
      message: 'Seluruh alarm, sirine, dan sensor bahaya berhasil dinonaktifkan (disarmed).',
      category: NotificationCategory.security,
      priority: NotificationPriority.info,
    );

    if (_isUsingFallback) {
      final perangkatMap = _localState!.perangkat.toMap();
      perangkatMap['buzzer_alrm'] = false;
      perangkatMap['led_merah_dapur'] = false;

      final sensorMap = _localState!.sensor.toMap();
      sensorMap['tamu_gerak'] = false;
      sensorMap['dapur_flame'] = 0;

      _localState = _localState!.copyWith(
        perangkat: SmarthomePerangkat.fromMap(perangkatMap),
        sensor: SmarthomeSensor.fromMap(sensorMap),
      );
      stateNotifier.value = _localState;
    } else {
      try {
        // Reset sensor simulasi di server agar tidak men-trigger alarm lagi
        await http.post(
          Uri.parse('${AppConfig.apiBaseUrl}/sensor'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'dapur_flame': 0,
            'tamu_gerak': false,
          }),
        );

        final updatedPerangkat = _localState!.perangkat.toMap();
        updatedPerangkat['buzzer_alrm'] = false;
        updatedPerangkat['led_merah_dapur'] = false;

        await http.put(
          Uri.parse('${AppConfig.apiBaseUrl}/perangkat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(updatedPerangkat),
        );
      } catch (e) {
        print("Gagal disarm perangkat di server: $e");
      }
    }
  }

  Future<void> updateOtomatisasi(String key, dynamic value) async {
    if (_localState == null) return;

    final currentVal = _localState!.otomatisasi.toMap()[key];
    if (currentVal == value) return; // No change, don't log duplication

    String? title;
    String? message;
    if (key == 'mode_auto_lampu') {
      title = value == true ? 'Otomatisasi Lampu Aktif' : 'Otomatisasi Lampu Mati';
      message = 'Mode otomatisasi lampu berdasarkan sensor cahaya atap telah ${value == true ? 'diaktifkan' : 'dimatikan'}.';
    } else if (key == 'mode_auto_kipas') {
      title = value == true ? 'Otomatisasi Kipas Aktif' : 'Otomatisasi Kipas Mati';
      message = 'Mode otomatisasi kipas berdasarkan suhu kamar telah ${value == true ? 'diaktifkan' : 'dimatikan'}.';
    }

    if (title != null && message != null) {
      NotificationService().addNotification(
        title: title,
        message: message,
        category: NotificationCategory.system,
        priority: NotificationPriority.info,
      );
    } else if (key == 'batas_gelap_lampu' || key == 'batas_panas_kamar') {
      _settingsNotificationTimer?.cancel();
      _settingsNotificationTimer = Timer(const Duration(seconds: 3), () {
        if (_localState == null) return;
        final currentVal = _localState!.otomatisasi.toMap()[key];
        String debouncedTitle;
        String debouncedMessage;
        if (key == 'batas_gelap_lampu') {
          debouncedTitle = 'Ambang Cahaya Diperbarui';
          debouncedMessage = 'Ambang batas kegelapan sensor LDR disetel ke $currentVal%.';
        } else {
          debouncedTitle = 'Ambang Suhu Diperbarui';
          debouncedMessage = 'Ambang batas panas kamar disetel ke ${currentVal.toStringAsFixed(1)}°C.';
        }
        NotificationService().addNotification(
          title: debouncedTitle,
          message: debouncedMessage,
          category: NotificationCategory.system,
          priority: NotificationPriority.info,
        );
      });
    }

    if (_isUsingFallback) {
      final otomatisasiMap = _localState!.otomatisasi.toMap();
      otomatisasiMap[key] = value;
      _localState = _localState!.copyWith(otomatisasi: SmarthomeOtomatisasi.fromMap(otomatisasiMap));
      stateNotifier.value = _localState;
      _runAutomationRulesIfNeeded();
    } else {
      final updatedOto = _localState!.otomatisasi.toMap();
      updatedOto[key] = value;

      try {
        await http.put(
          Uri.parse('${AppConfig.apiBaseUrl}/otomatisasi'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(updatedOto),
        );
      } catch (e) {
        print("Gagal update otomatisasi di server: $e");
      }
    }
  }

  // ─── RFID Management Methods ───
  Stream<Map<String, dynamic>> getRfidCardsStream() {
    if (_isUsingFallback) {
      Timer.run(() {
        _rfidStreamController.add(_localRfidCards);
      });
      return _rfidStreamController.stream;
    } else {
      _rfidPollingTimer?.cancel();
      _rfidPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        try {
          final res = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/rfid')).timeout(const Duration(seconds: 2));
          if (res.statusCode == 200) {
            final List<dynamic> list = jsonDecode(res.body);
            final Map<String, dynamic> rfidMap = {};
            for (var card in list) {
              rfidMap[card['uid']] = {
                'nama_pemilik': card['nama_pemilik'],
                'status': card['status'],
              };
            }
            _rfidStreamController.add(rfidMap);
          }
        } catch (e) {
          print("Rfid stream polling error: $e");
        }
      });
      return _rfidStreamController.stream;
    }
  }

  Future<void> addRfidCard(String uid, String namaPemilik) async {
    final uidClean = uid.trim().toUpperCase().replaceAll(' ', '');
    if (uidClean.isEmpty || namaPemilik.trim().isEmpty) return;

    if (_isUsingFallback) {
      _localRfidCards[uidClean] = {
        'nama_pemilik': namaPemilik.trim(),
        'status': 'aktif',
      };
      _rfidStreamController.add(_localRfidCards);
    } else {
      try {
        await http.post(
          Uri.parse('${AppConfig.apiBaseUrl}/rfid'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'uid': uidClean,
            'nama_pemilik': namaPemilik.trim(),
          }),
        );
      } catch (e) {
        print("Gagal add RFID card ke server: $e");
      }
    }
    
    NotificationService().addNotification(
      title: 'Kartu RFID Didaftarkan',
      message: 'Kartu milik ${namaPemilik.trim()} ($uidClean) berhasil didaftarkan.',
      category: NotificationCategory.security,
      priority: NotificationPriority.info,
    );
  }

  Future<void> removeRfidCard(String uid) async {
    final uidClean = uid.trim().toUpperCase().replaceAll(' ', '');
    if (uidClean.isEmpty) return;

    String namaPemilik = 'Kartu RFID';
    if (_isUsingFallback) {
      if (_localRfidCards.containsKey(uidClean)) {
        namaPemilik = _localRfidCards[uidClean]['nama_pemilik'] ?? 'Kartu RFID';
        _localRfidCards.remove(uidClean);
        _rfidStreamController.add(_localRfidCards);
      }
    } else {
      try {
        await http.delete(Uri.parse('${AppConfig.apiBaseUrl}/rfid/$uidClean'));
      } catch (e) {
        print("Gagal hapus RFID card dari server: $e");
      }
    }

    NotificationService().addNotification(
      title: 'Kartu RFID Dihapus',
      message: 'Kartu milik $namaPemilik ($uidClean) telah dihapus dari sistem.',
      category: NotificationCategory.security,
      priority: NotificationPriority.info,
    );
  }

  Future<void> updateRfidCardStatus(String uid, String status) async {
    final uidClean = uid.trim().toUpperCase().replaceAll(' ', '');
    if (uidClean.isEmpty) return;

    if (_isUsingFallback) {
      if (_localRfidCards.containsKey(uidClean)) {
        _localRfidCards[uidClean]['status'] = status;
        _rfidStreamController.add(_localRfidCards);
      }
    } else {
      try {
        await http.put(
          Uri.parse('${AppConfig.apiBaseUrl}/rfid/$uidClean/status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'status': status}),
        );
      } catch (e) {
        print("Gagal update status RFID di server: $e");
      }
    }
  }

  Future<void> approveRfidCard(String uid, String namaPemilik) async {
    final uidClean = uid.trim().toUpperCase().replaceAll(' ', '');
    final cleanName = namaPemilik.trim();
    if (uidClean.isEmpty || cleanName.isEmpty) return;

    if (_isUsingFallback) {
      if (_localRfidCards.containsKey(uidClean)) {
        _localRfidCards[uidClean]['nama_pemilik'] = cleanName;
        _localRfidCards[uidClean]['status'] = 'aktif';
        _rfidStreamController.add(_localRfidCards);
      }
    } else {
      try {
        await http.put(
          Uri.parse('${AppConfig.apiBaseUrl}/rfid/$uidClean/approve'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'nama_pemilik': cleanName}),
        );
      } catch (e) {
        print("Gagal approve RFID di server: $e");
      }
    }

    NotificationService().addNotification(
      title: 'Akses RFID Disetujui',
      message: 'Kartu $uidClean telah diaktifkan untuk $cleanName.',
      category: NotificationCategory.security,
      priority: NotificationPriority.info,
    );
  }

  void _runAutomationRulesIfNeeded() {
    if (_localState == null) return;
    
    final state = _localState!;
    bool changed = false;
    
    bool newLampuKamar = state.perangkat.lampuKamar;
    bool newLampuTamu = state.perangkat.lampuTamu;
    bool newLampuDapur = state.perangkat.lampuDapur;
    bool newLampuKamarMandi = state.perangkat.lampuKamarMandi;
    
    bool newKipasKamar = state.perangkat.kipasKamar;
    int newKecepatanKipas = state.perangkat.kecepatanKipas;

    bool newLedMerahDapur = state.perangkat.ledMerahDapur;
    bool newBuzzerAlrm = state.perangkat.buzzerAlrm;

    if (state.otomatisasi.modeAutoLampu) {
      final isDark = state.sensor.cahayaAtap < state.otomatisasi.batasGelapLampu;
      
      if (state.otomatisasi.autoLampuTamu && newLampuTamu != isDark) {
        newLampuTamu = isDark;
        changed = true;
      }
      if (state.otomatisasi.autoLampuKamar && newLampuKamar != isDark) {
        newLampuKamar = isDark;
        changed = true;
      }
      if (state.otomatisasi.autoLampuDapur && newLampuDapur != isDark) {
        newLampuDapur = isDark;
        changed = true;
      }
      if (state.otomatisasi.autoLampuKamarMandi && newLampuKamarMandi != isDark) {
        newLampuKamarMandi = isDark;
        changed = true;
      }
    }

    if (state.otomatisasi.modeAutoKipas) {
      if (state.sensor.kamarSuhu >= state.otomatisasi.batasPanasKamar) {
        newKipasKamar = true;
        final diff = state.sensor.kamarSuhu - state.otomatisasi.batasPanasKamar;
        if (diff > 4.0) {
          newKecepatanKipas = 255;
        } else if (diff > 2.0) {
          newKecepatanKipas = 170;
        } else {
          newKecepatanKipas = 85;
        }
      } else {
        newKipasKamar = false;
        newKecepatanKipas = 0;
      }
      if (newKipasKamar != state.perangkat.kipasKamar || newKecepatanKipas != state.perangkat.kecepatanKipas) {
        changed = true;
      }
    }

    if (state.sensor.dapurFlame > 0) {
      if (_lastSmokeValue == 0) {
        NotificationService().addNotification(
          title: 'Kebakaran Terdeteksi!',
          message: 'Sensor mendeteksi adanya kobaran api di Dapur! Alarm aktif.',
          category: NotificationCategory.security,
          priority: NotificationPriority.critical,
        );
      }
      if (!state.perangkat.buzzerAlrm) {
        newBuzzerAlrm = true;
        changed = true;
      }
      if (_flameBlinkerTimer == null || !_flameBlinkerTimer!.isActive) {
        _flameBlinkerTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
          if (_localState != null && _localState!.sensor.dapurFlame > 0) {
            final nextLedValue = !_localState!.perangkat.ledMerahDapur;
            updatePerangkat('led_merah_dapur', nextLedValue);
          } else {
            timer.cancel();
            _flameBlinkerTimer = null;
          }
        });
      }
    } else {
      if (state.sensor.dapurFlame == 0 && _lastSmokeValue > 0) {
        newLedMerahDapur = false;
        changed = true;
        _flameBlinkerTimer?.cancel();
        _flameBlinkerTimer = null;
      }
    }
    _lastSmokeValue = state.sensor.dapurFlame;

    if (state.sensor.tamuGerak) {
      if (!_lastPirValue) {
        NotificationService().addNotification(
          title: 'Anomali Terdeteksi',
          message: 'Ada anomali terdeteksi oleh PIR sensor di Ruang Tamu.',
          category: NotificationCategory.security,
          priority: NotificationPriority.critical,
        );
        newBuzzerAlrm = true;
        changed = true;
      }
    }
    _lastPirValue = state.sensor.tamuGerak;

    if (changed) {
      final updatedPerangkat = state.perangkat.toMap();
      updatedPerangkat['lampu_tamu'] = newLampuTamu;
      updatedPerangkat['lampu_kamar'] = newLampuKamar;
      updatedPerangkat['lampu_dapur'] = newLampuDapur;
      updatedPerangkat['lampu_kamar_mandi'] = newLampuKamarMandi;
      updatedPerangkat['kipas_kamar'] = newKipasKamar;
      updatedPerangkat['kecepatan_kipas'] = newKecepatanKipas;
      updatedPerangkat['buzzer_alrm'] = newBuzzerAlrm;
      updatedPerangkat['led_merah_dapur'] = newLedMerahDapur;

      _localState = state.copyWith(perangkat: SmarthomePerangkat.fromMap(updatedPerangkat));
      stateNotifier.value = _localState;

      if (!_isUsingFallback) {
        http.put(
          Uri.parse('${AppConfig.apiBaseUrl}/perangkat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(updatedPerangkat),
        );
      }
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
    _rfidPollingTimer?.cancel();
    _flameBlinkerTimer?.cancel();
  }
}
