import 'bars_control.dart';

class BarsSubject {
  const BarsSubject({
    required this.name,
    required this.semester,
    required this.attestation,
    required this.credits,
    required this.currentScore,
    required this.finalGrade,
    required this.controls,
  });

  final String name;
  final String semester;
  final String attestation;
  final String credits;

  final String currentScore;
  final String finalGrade;

  final List<BarsControl> controls;

  factory BarsSubject.fromMap(Map<String, dynamic> map) {
    final rawControls = map['controls'];

    final controls = <BarsControl>[];

    if (rawControls is List) {
      for (final item in rawControls) {
        if (item is Map) {
          controls.add(BarsControl.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return BarsSubject(
      name: map['name']?.toString() ?? '',
      semester: map['semester']?.toString() ?? '',
      attestation: map['attestation']?.toString() ?? '',
      credits: map['credits']?.toString() ?? '',
      currentScore: map['currentScore']?.toString() ?? '',
      finalGrade: map['finalGrade']?.toString() ?? '',
      controls: controls,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'semester': semester,
      'attestation': attestation,
      'credits': credits,
      'currentScore': currentScore,
      'finalGrade': finalGrade,
      'controls': controls.map((control) => control.toMap()).toList(),
    };
  }
}
