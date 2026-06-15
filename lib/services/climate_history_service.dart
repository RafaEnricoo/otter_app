import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

class ClimateHistoryService {
  static final ClimateHistoryService _instance = ClimateHistoryService._internal();
  factory ClimateHistoryService() => _instance;
  ClimateHistoryService._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Home Screen historical data (10 seconds intervals, last 7 points)
  final ValueNotifier<List<double>> homeKamarTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> homeDapurTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> homeKamarHumid = ValueNotifier([]);
  final ValueNotifier<List<double>> homeDapurHumid = ValueNotifier([]);
  final ValueNotifier<List<String>> homeLabels = ValueNotifier([]);

  // Monitor 24H Screen historical data (15 minutes intervals, last 6 points)
  final ValueNotifier<List<double>> monitor24hKamarTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor24hKamarHumid = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor24hDapurTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor24hDapurHumid = ValueNotifier([]);
  final ValueNotifier<List<String>> monitor24hLabels = ValueNotifier([]);

  // Monitor 7D Screen historical data (1 day intervals, last 7 points)
  final ValueNotifier<List<double>> monitor7dKamarTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor7dKamarHumid = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor7dDapurTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor7dDapurHumid = ValueNotifier([]);
  final ValueNotifier<List<String>> monitor7dLabels = ValueNotifier([]);

  // Monitor 30D Screen historical data (5 days intervals, last 6 points)
  final ValueNotifier<List<double>> monitor30dKamarTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor30dKamarHumid = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor30dDapurTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor30dDapurHumid = ValueNotifier([]);
  final ValueNotifier<List<String>> monitor30dLabels = ValueNotifier([]);

  Timer? _homeTimer;
  Timer? _monitor24hTimer;
  Timer? _monitor7dTimer;
  Timer? _monitor30dTimer;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    _loadOrSeedData();
    _startTimers();

    _isInitialized = true;
  }

  void dispose() {
    _homeTimer?.cancel();
    _monitor24hTimer?.cancel();
    _monitor7dTimer?.cancel();
    _monitor30dTimer?.cancel();
  }

  void _loadOrSeedData() {
    final now = DateTime.now();

    // 1. Home Data
    homeKamarTemp.value = _getListDouble('homeKamarTemp') ?? [26.5, 27.2, 28.0, 27.5, 28.5, 27.8, 27.0];
    homeDapurTemp.value = _getListDouble('homeDapurTemp') ?? [30.0, 31.2, 31.8, 30.5, 32.0, 31.5, 31.0];
    homeKamarHumid.value = _getListDouble('homeKamarHumid') ?? [58.0, 56.0, 54.0, 55.0, 53.0, 56.0, 55.0];
    homeDapurHumid.value = _getListDouble('homeDapurHumid') ?? [62.0, 60.0, 61.5, 59.0, 63.0, 60.5, 61.0];
    
    List<String> defaultHomeLabels = [];
    // Round to the nearest 10 seconds boundary to make them clean (e.g. 09:10:10, 09:10:20)
    final int secondsToSubtract = now.second % 10;
    final baseHomeTime = now.subtract(Duration(seconds: secondsToSubtract, milliseconds: now.millisecond));
    for (int i = 6; i >= 1; i--) {
      final time = baseHomeTime.subtract(Duration(seconds: i * 10));
      defaultHomeLabels.add("${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}");
    }
    defaultHomeLabels.add('Live');
    homeLabels.value = _getListString('homeLabels') ?? defaultHomeLabels;

    // 2. Monitor 24H (15 minutes)
    monitor24hKamarTemp.value = _getListDouble('monitor24hKamarTemp') ?? [26.0, 27.5, 29.0, 28.5, 27.2, 26.8];
    monitor24hKamarHumid.value = _getListDouble('monitor24hKamarHumid') ?? [55.0, 57.0, 54.0, 56.0, 58.0, 55.0];
    monitor24hDapurTemp.value = _getListDouble('monitor24hDapurTemp') ?? [27.5, 28.8, 30.2, 29.8, 28.5, 28.0];
    monitor24hDapurHumid.value = _getListDouble('monitor24hDapurHumid') ?? [60.0, 58.0, 62.0, 61.0, 59.0, 60.0];

    List<String> default24hLabels = [];
    // Round to the nearest 15 minutes to keep it clean and even (e.g. 09:00, 08:45, 08:30)
    final int minutesToSubtract = now.minute % 15;
    final baseTime = now.subtract(Duration(minutes: minutesToSubtract, seconds: now.second, milliseconds: now.millisecond));
    for (int i = 5; i >= 0; i--) {
      final time = baseTime.subtract(Duration(minutes: i * 15));
      default24hLabels.add("${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}");
    }
    monitor24hLabels.value = _getListString('monitor24hLabels') ?? default24hLabels;

    // 3. Monitor 7D (Daily - Fixed week starting from Senin to Minggu)
    final weekdays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    
    // Seed initial mock data aligned with Senin-Minggu
    monitor7dKamarTemp.value = _getListDouble('monitor7dKamarTemp') ?? [26.5, 27.0, 28.2, 27.8, 28.8, 29.5, 28.1];
    monitor7dKamarHumid.value = _getListDouble('monitor7dKamarHumid') ?? [54.0, 56.0, 55.0, 57.0, 56.0, 55.0, 54.0];
    monitor7dDapurTemp.value = _getListDouble('monitor7dDapurTemp') ?? [28.0, 28.5, 29.3, 29.0, 30.1, 30.5, 29.2];
    monitor7dDapurHumid.value = _getListDouble('monitor7dDapurHumid') ?? [61.0, 63.0, 60.0, 62.0, 64.0, 61.0, 62.0];
    monitor7dLabels.value = _getListString('monitor7dLabels') ?? weekdays;

    // 4. Monitor 30D (Every 5 days)
    monitor30dKamarTemp.value = _getListDouble('monitor30dKamarTemp') ?? [27.2, 28.0, 28.5, 27.9, 27.1, 26.8];
    monitor30dKamarHumid.value = _getListDouble('monitor30dKamarHumid') ?? [53.0, 55.0, 56.0, 54.0, 55.0, 53.0];
    monitor30dDapurTemp.value = _getListDouble('monitor30dDapurTemp') ?? [28.2, 29.1, 29.5, 28.9, 28.3, 28.0];
    monitor30dDapurHumid.value = _getListDouble('monitor30dDapurHumid') ?? [59.0, 61.0, 60.0, 62.0, 60.0, 59.0];

    List<String> default30dLabels = [];
    for (int i = 5; i >= 0; i--) {
      final date = now.subtract(Duration(days: i * 5));
      default30dLabels.add("${date.day}/${date.month}");
    }
    monitor30dLabels.value = _getListString('monitor30dLabels') ?? default30dLabels;
  }

  void _startTimers() {
    // 1. Home Page Timer (Every 10 seconds)
    _homeTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _appendHomeRecord();
    });

    // 2. Monitor 24H Timer (Every 15 minutes)
    _monitor24hTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _append24hRecord();
    });

    // 3. Monitor 7D Timer (Every 24 hours)
    _monitor7dTimer = Timer.periodic(const Duration(hours: 24), (timer) {
      _append7dRecord();
    });

    // 4. Monitor 30D Timer (Every 5 days)
    _monitor30dTimer = Timer.periodic(const Duration(hours: 120), (timer) {
      _append30dRecord();
    });
  }

  void _appendHomeRecord() {
    final state = FirebaseService().stateNotifier.value;
    if (state == null) return;

    final kTemp = state.sensor.kamarSuhu;
    final dTemp = state.sensor.dapurSuhu;
    final kHumid = state.sensor.kamarKelembapan;
    final dHumid = state.sensor.dapurKelembapan;

    final List<double> kTempList = List.from(homeKamarTemp.value)..removeAt(0)..add(kTemp);
    final List<double> dTempList = List.from(homeDapurTemp.value)..removeAt(0)..add(dTemp);
    final List<double> kHumidList = List.from(homeKamarHumid.value)..removeAt(0)..add(kHumid);
    final List<double> dHumidList = List.from(homeDapurHumid.value)..removeAt(0)..add(dHumid);

    final now = DateTime.now();
    final int secondsToSubtract = now.second % 10;
    final roundedTime = now.subtract(Duration(seconds: secondsToSubtract, milliseconds: now.millisecond));
    final newTimeLabel = "${roundedTime.hour.toString().padLeft(2, '0')}:${roundedTime.minute.toString().padLeft(2, '0')}:${roundedTime.second.toString().padLeft(2, '0')}";
    
    final List<String> labelList = List.from(homeLabels.value);
    labelList.removeAt(0);
    labelList.insert(labelList.length - 1, newTimeLabel);

    homeKamarTemp.value = kTempList;
    homeDapurTemp.value = dTempList;
    homeKamarHumid.value = kHumidList;
    homeDapurHumid.value = dHumidList;
    homeLabels.value = labelList;

    _saveListDouble('homeKamarTemp', kTempList);
    _saveListDouble('homeDapurTemp', dTempList);
    _saveListDouble('homeKamarHumid', kHumidList);
    _saveListDouble('homeDapurHumid', dHumidList);
    _saveListString('homeLabels', labelList);
  }

  void _append24hRecord() {
    final state = FirebaseService().stateNotifier.value;
    if (state == null) return;

    final kTemp = state.sensor.kamarSuhu;
    final dTemp = state.sensor.dapurSuhu;
    final kHumid = state.sensor.kamarKelembapan;
    final dHumid = state.sensor.dapurKelembapan;

    final List<double> kTempList = List.from(monitor24hKamarTemp.value)..removeAt(0)..add(kTemp);
    final List<double> kHumidList = List.from(monitor24hKamarHumid.value)..removeAt(0)..add(kHumid);
    final List<double> dTempList = List.from(monitor24hDapurTemp.value)..removeAt(0)..add(dTemp);
    final List<double> dHumidList = List.from(monitor24hDapurHumid.value)..removeAt(0)..add(dHumid);

    final now = DateTime.now();
    final int minutesToSubtract = now.minute % 15;
    final roundedTime = now.subtract(Duration(minutes: minutesToSubtract, seconds: now.second, milliseconds: now.millisecond));
    final newLabel = "${roundedTime.hour.toString().padLeft(2, '0')}:${roundedTime.minute.toString().padLeft(2, '0')}";
    final List<String> labelList = List.from(monitor24hLabels.value)..removeAt(0)..add(newLabel);

    monitor24hKamarTemp.value = kTempList;
    monitor24hKamarHumid.value = kHumidList;
    monitor24hDapurTemp.value = dTempList;
    monitor24hDapurHumid.value = dHumidList;
    monitor24hLabels.value = labelList;

    _saveListDouble('monitor24hKamarTemp', kTempList);
    _saveListDouble('monitor24hKamarHumid', kHumidList);
    _saveListDouble('monitor24hDapurTemp', dTempList);
    _saveListDouble('monitor24hDapurHumid', dHumidList);
    _saveListString('monitor24hLabels', labelList);
  }

  void _append7dRecord() {
    final state = FirebaseService().stateNotifier.value;
    if (state == null) return;

    final kTemp = state.sensor.kamarSuhu;
    final dTemp = state.sensor.dapurSuhu;
    final kHumid = state.sensor.kamarKelembapan;
    final dHumid = state.sensor.dapurKelembapan;

    final now = DateTime.now();
    final int weekdayIndex = now.weekday - 1; // 0 for Monday (Senin) to 6 for Sunday (Minggu)

    final List<double> kTempList = List.from(monitor7dKamarTemp.value);
    final List<double> kHumidList = List.from(monitor7dKamarHumid.value);
    final List<double> dTempList = List.from(monitor7dDapurTemp.value);
    final List<double> dHumidList = List.from(monitor7dDapurHumid.value);

    // If list is not initialized to length 7, initialize it
    while (kTempList.length < 7) kTempList.add(25.0);
    while (kHumidList.length < 7) kHumidList.add(50.0);
    while (dTempList.length < 7) dTempList.add(25.0);
    while (dHumidList.length < 7) dHumidList.add(50.0);

    // If it's Monday, we start a new week, so we can clear/reset other days in the list
    if (weekdayIndex == 0) {
      for (int i = 1; i < 7; i++) {
        kTempList[i] = 0.0;
        kHumidList[i] = 0.0;
        dTempList[i] = 0.0;
        dHumidList[i] = 0.0;
      }
    }

    kTempList[weekdayIndex] = kTemp;
    kHumidList[weekdayIndex] = kHumid;
    dTempList[weekdayIndex] = dTemp;
    dHumidList[weekdayIndex] = dHumid;

    monitor7dKamarTemp.value = kTempList;
    monitor7dKamarHumid.value = kHumidList;
    monitor7dDapurTemp.value = dTempList;
    monitor7dDapurHumid.value = dHumidList;

    final weekdays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    monitor7dLabels.value = weekdays;

    _saveListDouble('monitor7dKamarTemp', kTempList);
    _saveListDouble('monitor7dKamarHumid', kHumidList);
    _saveListDouble('monitor7dDapurTemp', dTempList);
    _saveListDouble('monitor7dDapurHumid', dHumidList);
    _saveListString('monitor7dLabels', weekdays);
  }

  void _append30dRecord() {
    final state = FirebaseService().stateNotifier.value;
    if (state == null) return;

    final kTemp = state.sensor.kamarSuhu;
    final dTemp = state.sensor.dapurSuhu;
    final kHumid = state.sensor.kamarKelembapan;
    final dHumid = state.sensor.dapurKelembapan;

    final List<double> kTempList = List.from(monitor30dKamarTemp.value)..removeAt(0)..add(kTemp);
    final List<double> kHumidList = List.from(monitor30dKamarHumid.value)..removeAt(0)..add(kHumid);
    final List<double> dTempList = List.from(monitor30dDapurTemp.value)..removeAt(0)..add(dTemp);
    final List<double> dHumidList = List.from(monitor30dDapurHumid.value)..removeAt(0)..add(dHumid);

    final now = DateTime.now();
    final newLabel = "${now.day}/${now.month}";
    final List<String> labelList = List.from(monitor30dLabels.value)..removeAt(0)..add(newLabel);

    monitor30dKamarTemp.value = kTempList;
    monitor30dKamarHumid.value = kHumidList;
    monitor30dDapurTemp.value = dTempList;
    monitor30dDapurHumid.value = dHumidList;
    monitor30dLabels.value = labelList;

    _saveListDouble('monitor30dKamarTemp', kTempList);
    _saveListDouble('monitor30dKamarHumid', kHumidList);
    _saveListDouble('monitor30dDapurTemp', dTempList);
    _saveListDouble('monitor30dDapurHumid', dHumidList);
    _saveListString('monitor30dLabels', labelList);
  }

  // Trigger manually for debugging and instant verification
  void triggerManualDebugTick() {
    _appendHomeRecord();
    _append24hRecord();
    _append7dRecord();
    _append30dRecord();
  }

  List<double>? _getListDouble(String key) {
    final list = _prefs.getStringList(key);
    if (list == null) return null;
    return list.map((e) => double.tryParse(e) ?? 0.0).toList();
  }

  void _saveListDouble(String key, List<double> list) {
    final strList = list.map((e) => e.toString()).toList();
    _prefs.setStringList(key, strList);
  }

  List<String>? _getListString(String key) {
    return _prefs.getStringList(key);
  }

  void _saveListString(String key, List<String> list) {
    _prefs.setStringList(key, list);
  }
}
