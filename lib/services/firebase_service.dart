import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_database/firebase_database.dart';
import '../models/device_model.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final _dbRef = FirebaseDatabase.instance.ref('otter_smarthome');
  final ValueNotifier<SmarthomeState?> stateNotifier = ValueNotifier<SmarthomeState?>(null);
  
  bool _isInitialized = false;
  bool _isUsingFallback = false;

  bool get isInitialized => _isInitialized;
  bool get isUsingFallback => _isUsingFallback;
  
  SmarthomeState? _localState;
  StreamSubscription? _subscription;
  int _lastSmokeValue = 0;
  bool _lastPirValue = false;
  Timer? _flameBlinkerTimer;
  Timer? _settingsNotificationTimer;
  Map<String, dynamic> _localRfidCards = {};
  final _rfidStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Test Firebase database connection
      final snapshot = await _dbRef.get().timeout(const Duration(seconds: 4));
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _localState = SmarthomeState.fromMap(data);
        stateNotifier.value = _localState;
      } else {
        // Database is empty, seed it with firebase.json
        await _seedDatabase();
      }

      // Start listening to live changes
      _subscription = _dbRef.onValue.listen((event) {
        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          _localState = SmarthomeState.fromMap(data);
          stateNotifier.value = _localState;
          _runAutomationRulesIfNeeded();
        }
      }, onError: (err) {
        print("Firebase stream error, falling back to local simulation: $err");
        _setupLocalFallback();
      });

      _isInitialized = true;
      _isUsingFallback = false;
    } catch (e) {
      print("Firebase initialization failed, using local JSON fallback: $e");
      await _setupLocalFallback();
    }
  }

  Future<void> _seedDatabase() async {
    try {
      final jsonString = await rootBundle.loadString('lib/assets/firebase.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      final rawData = jsonMap['otter_smarthome'] as Map<String, dynamic>;
      
      await _dbRef.set(rawData);
      _localState = SmarthomeState.fromMap(rawData);
      stateNotifier.value = _localState;
    } catch (e) {
      print("Seeding database failed: $e");
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
        await _dbRef.set(rawData);
        _localState = SmarthomeState.fromMap(rawData);
        stateNotifier.value = _localState;
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
      // Hardcoded fallback matching firebase.json
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
      await _dbRef.child('sensor/$key').set(value);
    }
  }

  Future<void> updatePerangkat(String key, dynamic value) async {
    if (_localState == null) return;

    final currentVal = _localState!.perangkat.toMap()[key];
    if (currentVal == value) return; // No change, don't log duplication

    // Log the change event to Notification Service
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
      final Map<String, dynamic> updates = {
        'perangkat/$key': value,
      };
      if (autoLampuKeyToDisable != null) {
        updates['otomatisasi/$autoLampuKeyToDisable'] = false;
      }
      if (disableAutoKipas) {
        updates['otomatisasi/mode_auto_kipas'] = false;
      }
      await _dbRef.update(updates);
    }
  }

  Future<void> disarmAllAlarms() async {
    if (_localState == null) return;

    // Cancel blinker timer
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
      final Map<String, dynamic> updates = {
        'perangkat/buzzer_alrm': false,
        'perangkat/led_merah_dapur': false,
        'sensor/tamu_gerak': false,
        'sensor/dapur_flame': 0,
      };
      await _dbRef.update(updates);
    }
  }

  Future<void> updateOtomatisasi(String key, dynamic value) async {
    if (_localState == null) return;

    final currentVal = _localState!.otomatisasi.toMap()[key];
    if (currentVal == value) return; // No change, don't log duplication

    // Log update otomatisasi
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
      if (key == 'mode_auto_lampu') {
        otomatisasiMap['auto_lampu_kamar'] = value;
        otomatisasiMap['auto_lampu_tamu'] = value;
        otomatisasiMap['auto_lampu_kamar_mandi'] = value;
        otomatisasiMap['auto_lampu_dapur'] = value;
      }
      _localState = _localState!.copyWith(otomatisasi: SmarthomeOtomatisasi.fromMap(otomatisasiMap));
      stateNotifier.value = _localState;
      _runAutomationRulesIfNeeded();
    } else {
      if (key == 'mode_auto_lampu') {
        await _dbRef.child('otomatisasi').update({
          'mode_auto_lampu': value,
          'auto_lampu_kamar': value,
          'auto_lampu_tamu': value,
          'auto_lampu_kamar_mandi': value,
          'auto_lampu_dapur': value,
        });
      } else {
        await _dbRef.child('otomatisasi/$key').set(value);
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
      return _dbRef.child('rfid_terdaftar').onValue.map((event) {
        if (event.snapshot.value == null) return {};
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        return Map<String, dynamic>.from(data);
      });
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
      await _dbRef.child('rfid_terdaftar/$uidClean').set({
        'nama_pemilik': namaPemilik.trim(),
        'status': 'aktif',
      });
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
      final snapshot = await _dbRef.child('rfid_terdaftar/$uidClean').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        namaPemilik = data['nama_pemilik'] ?? 'Kartu RFID';
      }
      await _dbRef.child('rfid_terdaftar/$uidClean').remove();
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
      await _dbRef.child('rfid_terdaftar/$uidClean/status').set(status);
    }
  }

  // Automation logic
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

    // 1. Auto Light Mode
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

    // 2. Auto Fan Mode (mode_auto_kipas)
    if (state.otomatisasi.modeAutoKipas) {
      if (state.sensor.kamarSuhu >= state.otomatisasi.batasPanasKamar) {
        newKipasKamar = true;
        // Scale fan speed based on how hot it is
        final diff = state.sensor.kamarSuhu - state.otomatisasi.batasPanasKamar;
        if (diff > 4.0) {
          newKecepatanKipas = 255; // high
        } else if (diff > 2.0) {
          newKecepatanKipas = 170; // medium
        } else {
          newKecepatanKipas = 85; // low
        }
      } else {
        newKipasKamar = false;
        newKecepatanKipas = 0;
      }
      if (newKipasKamar != state.perangkat.kipasKamar || newKecepatanKipas != state.perangkat.kecepatanKipas) {
        changed = true;
      }
    }

    // 3. Flame/Fire Alarm (dapur_flame)
    // If fire is detected, turn on Kitchen Buzzer, send notification, and blink Red LED!
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
      // Start blinking timer for the kitchen red LED if not already active
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
      // Clear warning LED only if flame has just transitioned from detected to cleared
      if (state.sensor.dapurFlame == 0 && _lastSmokeValue > 0) {
        newLedMerahDapur = false;
        changed = true;
        _flameBlinkerTimer?.cancel();
        _flameBlinkerTimer = null;
      }
    }
    _lastSmokeValue = state.sensor.dapurFlame;

    // 4. PIR Sensor Motion Alarm (tamu_gerak)
    // If motion is detected, trigger notification and buzzer alarm
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
        // Write the updated automatic states back to Firebase
        _dbRef.child('perangkat').update({
          'lampu_tamu': newLampuTamu,
          'lampu_kamar': newLampuKamar,
          'lampu_dapur': newLampuDapur,
          'lampu_kamar_mandi': newLampuKamarMandi,
          'kipas_kamar': newKipasKamar,
          'kecepatan_kipas': newKecepatanKipas,
          'buzzer_alrm': newBuzzerAlrm,
          'led_merah_dapur': newLedMerahDapur,
        });
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _flameBlinkerTimer?.cancel();
  }
}
