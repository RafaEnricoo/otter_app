import 'dart:convert';

class SmarthomeState {
  final SmarthomeSensor sensor;
  final SmarthomePerangkat perangkat;
  final SmarthomeOtomatisasi otomatisasi;

  SmarthomeState({
    required this.sensor,
    required this.perangkat,
    required this.otomatisasi,
  });

  factory SmarthomeState.fromMap(Map<dynamic, dynamic> map) {
    return SmarthomeState(
      sensor: SmarthomeSensor.fromMap(map['sensor'] as Map<dynamic, dynamic>? ?? {}),
      perangkat: SmarthomePerangkat.fromMap(map['perangkat'] as Map<dynamic, dynamic>? ?? {}),
      otomatisasi: SmarthomeOtomatisasi.fromMap(map['otomatisasi'] as Map<dynamic, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sensor': sensor.toMap(),
      'perangkat': perangkat.toMap(),
      'otomatisasi': otomatisasi.toMap(),
    };
  }

  SmarthomeState copyWith({
    SmarthomeSensor? sensor,
    SmarthomePerangkat? perangkat,
    SmarthomeOtomatisasi? otomatisasi,
  }) {
    return SmarthomeState(
      sensor: sensor ?? this.sensor,
      perangkat: perangkat ?? this.perangkat,
      otomatisasi: otomatisasi ?? this.otomatisasi,
    );
  }
}

class SmarthomeSensor {
  final int cahayaAtap;
  final double dapurSuhu;
  final double dapurKelembapan;
  final int dapurFlame;
  final double kamarSuhu;
  final double kamarKelembapan;
  final bool tamuGerak;

  SmarthomeSensor({
    required this.cahayaAtap,
    required this.dapurSuhu,
    required this.dapurKelembapan,
    required this.dapurFlame,
    required this.kamarSuhu,
    required this.kamarKelembapan,
    required this.tamuGerak,
  });

  factory SmarthomeSensor.fromMap(Map<dynamic, dynamic> map) {
    return SmarthomeSensor(
      cahayaAtap: (map['cahaya_atap'] ?? 0) is double
          ? (map['cahaya_atap'] as double).toInt()
          : (map['cahaya_atap'] ?? 0) as int,
      dapurSuhu: (map['dapur_suhu'] ?? 0.0) is int 
          ? (map['dapur_suhu'] as int).toDouble() 
          : (map['dapur_suhu'] ?? 0.0) as double,
      dapurKelembapan: (map['dapur_kelembapan'] ?? 0.0) is int
          ? (map['dapur_kelembapan'] as int).toDouble()
          : (map['dapur_kelembapan'] ?? 0.0) as double,
      dapurFlame: (map['dapur_flame'] ?? 0) is double
          ? (map['dapur_flame'] as double).toInt()
          : (map['dapur_flame'] ?? 0) as int,
      kamarSuhu: (map['kamar_suhu'] ?? 0.0) is int
          ? (map['kamar_suhu'] as int).toDouble()
          : (map['kamar_suhu'] ?? 0.0) as double,
      kamarKelembapan: (map['kamar_kelembapan'] ?? 0.0) is int
          ? (map['kamar_kelembapan'] as int).toDouble()
          : (map['kamar_kelembapan'] ?? 0.0) as double,
      tamuGerak: (map['tamu_gerak'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cahaya_atap': cahayaAtap,
      'dapur_suhu': dapurSuhu,
      'dapur_kelembapan': dapurKelembapan,
      'dapur_flame': dapurFlame,
      'kamar_suhu': kamarSuhu,
      'kamar_kelembapan': kamarKelembapan,
      'tamu_gerak': tamuGerak,
    };
  }
}

class SmarthomePerangkat {
  final bool lampuKamar;
  final bool lampuTamu;
  final bool lampuKamarMandi;
  final bool lampuDapur;
  final bool kipasKamar;
  final int kecepatanKipas;
  final bool buzzerAlrm;
  final bool ledMerahDapur;
  final bool kunciPintuRfid;

  SmarthomePerangkat({
    required this.lampuKamar,
    required this.lampuTamu,
    required this.lampuKamarMandi,
    required this.lampuDapur,
    required this.kipasKamar,
    required this.kecepatanKipas,
    required this.buzzerAlrm,
    required this.ledMerahDapur,
    required this.kunciPintuRfid,
  });

  factory SmarthomePerangkat.fromMap(Map<dynamic, dynamic> map) {
    return SmarthomePerangkat(
      lampuKamar: (map['lampu_kamar'] ?? false) as bool,
      lampuTamu: (map['lampu_tamu'] ?? false) as bool,
      lampuKamarMandi: (map['lampu_kamar_mandi'] ?? false) as bool,
      lampuDapur: (map['lampu_dapur'] ?? false) as bool,
      kipasKamar: (map['kipas_kamar'] ?? false) as bool,
      kecepatanKipas: (map['kecepatan_kipas'] ?? 0) is double
          ? (map['kecepatan_kipas'] as double).toInt()
          : (map['kecepatan_kipas'] ?? 0) as int,
      buzzerAlrm: (map['buzzer_alrm'] ?? false) as bool,
      ledMerahDapur: (map['led_merah_dapur'] ?? false) as bool,
      kunciPintuRfid: (map['kunci_pintu_rfid'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lampu_kamar': lampuKamar,
      'lampu_tamu': lampuTamu,
      'lampu_kamar_mandi': lampuKamarMandi,
      'lampu_dapur': lampuDapur,
      'kipas_kamar': kipasKamar,
      'kecepatan_kipas': kecepatanKipas,
      'buzzer_alrm': buzzerAlrm,
      'led_merah_dapur': ledMerahDapur,
      'kunci_pintu_rfid': kunciPintuRfid,
    };
  }
}

class SmarthomeOtomatisasi {
  final bool modeAutoLampu;
  final bool autoLampuKamar;
  final bool autoLampuTamu;
  final bool autoLampuKamarMandi;
  final bool autoLampuDapur;
  final bool modeAutoKipas;
  final int batasGelapLampu;
  final double batasPanasKamar;
  final bool modeKeamananAktif;

  SmarthomeOtomatisasi({
    required this.modeAutoLampu,
    required this.autoLampuKamar,
    required this.autoLampuTamu,
    required this.autoLampuKamarMandi,
    required this.autoLampuDapur,
    required this.modeAutoKipas,
    required this.batasGelapLampu,
    required this.batasPanasKamar,
    required this.modeKeamananAktif,
  });

  factory SmarthomeOtomatisasi.fromMap(Map<dynamic, dynamic> map) {
    return SmarthomeOtomatisasi(
      modeAutoLampu: (map['mode_auto_lampu'] ?? false) as bool,
      autoLampuKamar: (map['auto_lampu_kamar'] ?? false) as bool,
      autoLampuTamu: (map['auto_lampu_tamu'] ?? false) as bool,
      autoLampuKamarMandi: (map['auto_lampu_kamar_mandi'] ?? false) as bool,
      autoLampuDapur: (map['auto_lampu_dapur'] ?? false) as bool,
      modeAutoKipas: (map['mode_auto_kipas'] ?? false) as bool,
      batasGelapLampu: (map['batas_gelap_lampu'] ?? 0) is double
          ? (map['batas_gelap_lampu'] as double).toInt()
          : (map['batas_gelap_lampu'] ?? 0) as int,
      batasPanasKamar: (map['batas_panas_kamar'] ?? 0.0) is int
          ? (map['batas_panas_kamar'] as int).toDouble()
          : (map['batas_panas_kamar'] ?? 0.0) as double,
      modeKeamananAktif: (map['mode_keamanan_aktif'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode_auto_lampu': modeAutoLampu,
      'auto_lampu_kamar': autoLampuKamar,
      'auto_lampu_tamu': autoLampuTamu,
      'auto_lampu_kamar_mandi': autoLampuKamarMandi,
      'auto_lampu_dapur': autoLampuDapur,
      'mode_auto_kipas': modeAutoKipas,
      'batas_gelap_lampu': batasGelapLampu,
      'batas_panas_kamar': batasPanasKamar,
      'mode_keamanan_aktif': modeKeamananAktif,
    };
  }
}
