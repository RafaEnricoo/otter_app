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

    final bool disableAutoLampu = (key == 'lampu_kamar' || key == 'lampu_tamu' || key == 'lampu_dapur');
    final bool disableAutoKipas = (key == 'kipas_kamar');

    if (_isUsingFallback) {
      final perangkatMap = _localState!.perangkat.toMap();
      perangkatMap[key] = value;
      
      SmarthomeOtomatisasi newOto = _localState!.otomatisasi;
      if (disableAutoLampu || disableAutoKipas) {
        final otoMap = _localState!.otomatisasi.toMap();
        if (disableAutoLampu) otoMap['mode_auto_lampu'] = false;
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
      if (disableAutoLampu) {
        updates['otomatisasi/mode_auto_lampu'] = false;
      }
      if (disableAutoKipas) {
        updates['otomatisasi/mode_auto_kipas'] = false;
      }
      await _dbRef.update(updates);
    }
  }

  Future<void> updateOtomatisasi(String key, dynamic value) async {
    if (_localState == null) return;

    if (_isUsingFallback) {
      final otomatisasiMap = _localState!.otomatisasi.toMap();
      otomatisasiMap[key] = value;
      _localState = _localState!.copyWith(otomatisasi: SmarthomeOtomatisasi.fromMap(otomatisasiMap));
      stateNotifier.value = _localState;
      _runAutomationRulesIfNeeded();
    } else {
      await _dbRef.child('otomatisasi/$key').set(value);
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
    
    bool newKipasKamar = state.perangkat.kipasKamar;
    int newKecepatanKipas = state.perangkat.kecepatanKipas;

    bool newLedMerahDapur = state.perangkat.ledMerahDapur;
    bool newBuzzerAlrm = state.perangkat.buzzerAlrm;

    // 1. Auto Light Mode (mode_auto_lampu)
    if (state.otomatisasi.modeAutoLampu) {
      // If cahaya_atap < batas_gelap_lampu, turn lights on
      final isDark = state.sensor.cahayaAtap < state.otomatisasi.batasGelapLampu;
      if (isDark != state.perangkat.lampuTamu) {
        newLampuTamu = isDark;
        newLampuKamar = isDark;
        newLampuDapur = isDark;
        changed = true;
      }
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
      // Clear buzzer and warning LED only if flame has just transitioned from detected to cleared
      if (state.sensor.dapurFlame == 0 && _lastSmokeValue > 0) {
        newLedMerahDapur = false;
        newBuzzerAlrm = false;
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
