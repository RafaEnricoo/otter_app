import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'smarthome_service.dart';

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

  // Monitor 24H Screen historical data (last 6 points)
  final ValueNotifier<List<double>> monitor24hKamarTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor24hKamarHumid = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor24hDapurTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor24hDapurHumid = ValueNotifier([]);
  final ValueNotifier<List<String>> monitor24hLabels = ValueNotifier([]);

  // Monitor 7D Screen historical data (last 7 points)
  final ValueNotifier<List<double>> monitor7dKamarTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor7dKamarHumid = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor7dDapurTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor7dDapurHumid = ValueNotifier([]);
  final ValueNotifier<List<String>> monitor7dLabels = ValueNotifier([]);

  // Monitor 30D Screen historical data (last 6 points)
  final ValueNotifier<List<double>> monitor30dKamarTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor30dKamarHumid = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor30dDapurTemp = ValueNotifier([]);
  final ValueNotifier<List<double>> monitor30dDapurHumid = ValueNotifier([]);
  final ValueNotifier<List<String>> monitor30dLabels = ValueNotifier([]);

  Timer? _homeTimer;
  Timer? _fetchTimer;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    _loadOrSeedLocalHomeData();
    await fetchHistoryFromBackend();

    // Start 10-seconds micro log for Home page
    _homeTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _appendHomeRecord();
    });

    // Refresh historical data from backend every 30 seconds
    _fetchTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await fetchHistoryFromBackend();
    });

    _isInitialized = true;
  }

  void dispose() {
    _homeTimer?.cancel();
    _fetchTimer?.cancel();
  }

  void _loadOrSeedLocalHomeData() {
    final now = DateTime.now();
    homeKamarTemp.value = _getListDouble('homeKamarTemp') ?? [26.5, 27.2, 28.0, 27.5, 28.5, 27.8, 27.0];
    homeDapurTemp.value = _getListDouble('homeDapurTemp') ?? [30.0, 31.2, 31.8, 30.5, 32.0, 31.5, 31.0];
    homeKamarHumid.value = _getListDouble('homeKamarHumid') ?? [58.0, 56.0, 54.0, 55.0, 53.0, 56.0, 55.0];
    homeDapurHumid.value = _getListDouble('homeDapurHumid') ?? [62.0, 60.0, 61.5, 59.0, 63.0, 60.5, 61.0];
    
    List<String> defaultHomeLabels = [];
    final int secondsToSubtract = now.second % 10;
    final baseHomeTime = now.subtract(Duration(seconds: secondsToSubtract, milliseconds: now.millisecond));
    for (int i = 6; i >= 1; i--) {
      final time = baseHomeTime.subtract(Duration(seconds: i * 10));
      defaultHomeLabels.add("${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}");
    }
    defaultHomeLabels.add('Live');
    homeLabels.value = _getListString('homeLabels') ?? defaultHomeLabels;
  }

  Future<void> fetchHistoryFromBackend() async {
    if (SmartHomeService().isUsingFallback) {
      _setupLocalFallbackSeed();
      return;
    }

    try {
      await Future.wait([
        _fetchRange('24h', monitor24hKamarTemp, monitor24hKamarHumid, monitor24hDapurTemp, monitor24hDapurHumid, monitor24hLabels, 6),
        _fetchRange('7d', monitor7dKamarTemp, monitor7dKamarHumid, monitor7dDapurTemp, monitor7dDapurHumid, monitor7dLabels, 7),
        _fetchRange('30d', monitor30dKamarTemp, monitor30dKamarHumid, monitor30dDapurTemp, monitor30dDapurHumid, monitor30dLabels, 6),
      ]);
    } catch (e) {
      print("Failed to fetch climate history from server: $e. Falling back to simulated history.");
      _setupLocalFallbackSeed();
    }
  }

  Future<void> _fetchRange(
    String range,
    ValueNotifier<List<double>> kamarTemp,
    ValueNotifier<List<double>> kamarHumid,
    ValueNotifier<List<double>> dapurTemp,
    ValueNotifier<List<double>> dapurHumid,
    ValueNotifier<List<String>> labels,
    int maxPoints,
  ) async {
    final res = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/sensor/history?range=$range')).timeout(const Duration(seconds: 4));
    if (res.statusCode == 200) {
      final List<dynamic> raw = jsonDecode(res.body);
      
      final List<double> kTemp = [];
      final List<double> kHumid = [];
      final List<double> dTemp = [];
      final List<double> dHumid = [];
      final List<String> lbls = [];

      // Take the latest records up to maxPoints
      final startIdx = raw.length > maxPoints ? raw.length - maxPoints : 0;
      for (int i = startIdx; i < raw.length; i++) {
        final item = raw[i];
        kTemp.add((item['kamar_suhu'] as num?)?.toDouble() ?? 0.0);
        kHumid.add((item['kamar_kelembapan'] as num?)?.toDouble() ?? 0.0);
        dTemp.add((item['dapur_suhu'] as num?)?.toDouble() ?? 0.0);
        dHumid.add((item['dapur_kelembapan'] as num?)?.toDouble() ?? 0.0);
        
        final String rawTimestamp = item['timestamp'] ?? '';
        if (range == '24h') {
          // Format from 'YYYY-MM-DD HH:MM' to 'HH:MM'
          if (rawTimestamp.length >= 16) {
            lbls.add(rawTimestamp.substring(11, 16));
          } else {
            lbls.add(rawTimestamp);
          }
        } else if (range == '7d') {
          // Format from YYYY-MM-DD to Indonesian day name or short date
          try {
            final date = DateTime.parse(rawTimestamp);
            final weekdays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
            lbls.add(weekdays[date.weekday - 1]);
          } catch (_) {
            lbls.add(rawTimestamp);
          }
        } else {
          // 30d -> format day/month
          try {
            final date = DateTime.parse(rawTimestamp);
            lbls.add("${date.day}/${date.month}");
          } catch (_) {
            lbls.add(rawTimestamp);
          }
        }
      }

      // If empty, fill with default values
      if (kTemp.isEmpty) {
        kamarTemp.value = List.filled(maxPoints, 26.0);
        kamarHumid.value = List.filled(maxPoints, 55.0);
        dapurTemp.value = List.filled(maxPoints, 29.0);
        dapurHumid.value = List.filled(maxPoints, 60.0);
        labels.value = List.filled(maxPoints, '--');
      } else {
        kamarTemp.value = kTemp;
        kamarHumid.value = kHumid;
        dapurTemp.value = dTemp;
        dapurHumid.value = dHumid;
        labels.value = lbls;
      }
    }
  }

  void _setupLocalFallbackSeed() {
    final now = DateTime.now();

    // 24H Fallback
    monitor24hKamarTemp.value = [26.0, 27.5, 29.0, 28.5, 27.2, 26.8];
    monitor24hKamarHumid.value = [55.0, 57.0, 54.0, 56.0, 58.0, 55.0];
    monitor24hDapurTemp.value = [27.5, 28.8, 30.2, 29.8, 28.5, 28.0];
    monitor24hDapurHumid.value = [60.0, 58.0, 62.0, 61.0, 59.0, 60.0];
    
    List<String> default24hLabels = [];
    final int minutesToSubtract = now.minute % 15;
    final baseTime = now.subtract(Duration(minutes: minutesToSubtract, seconds: now.second, milliseconds: now.millisecond));
    for (int i = 5; i >= 0; i--) {
      final time = baseTime.subtract(Duration(minutes: i * 15));
      default24hLabels.add("${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}");
    }
    monitor24hLabels.value = default24hLabels;

    // 7D Fallback
    monitor7dKamarTemp.value = [26.5, 27.0, 28.2, 27.8, 28.8, 29.5, 28.1];
    monitor7dKamarHumid.value = [54.0, 56.0, 55.0, 57.0, 56.0, 55.0, 54.0];
    monitor7dDapurTemp.value = [28.0, 28.5, 29.3, 29.0, 30.1, 30.5, 29.2];
    monitor7dDapurHumid.value = [61.0, 63.0, 60.0, 62.0, 64.0, 61.0, 62.0];
    monitor7dLabels.value = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    // 30D Fallback
    monitor30dKamarTemp.value = [27.2, 28.0, 28.5, 27.9, 27.1, 26.8];
    monitor30dKamarHumid.value = [53.0, 55.0, 56.0, 54.0, 55.0, 53.0];
    monitor30dDapurTemp.value = [28.2, 29.1, 29.5, 28.9, 28.3, 28.0];
    monitor30dDapurHumid.value = [59.0, 61.0, 60.0, 62.0, 60.0, 59.0];

    List<String> default30dLabels = [];
    for (int i = 5; i >= 0; i--) {
      final date = now.subtract(Duration(days: i * 5));
      default30dLabels.add("${date.day}/${date.month}");
    }
    monitor30dLabels.value = default30dLabels;
  }

  void _appendHomeRecord() {
    final state = SmartHomeService().stateNotifier.value;
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

  void triggerManualDebugTick() {
    _appendHomeRecord();
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
