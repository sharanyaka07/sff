class FirstAidGuide {
  final String id;
  final String title;
  final String icon;
  final int color;
  final String severity; // critical, high, medium
  final String description;
  final List<FirstAidStep> steps;
  final List<String> warnings;
  final List<String> tips;

  const FirstAidGuide({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.severity,
    required this.description,
    required this.steps,
    required this.warnings,
    required this.tips,
  });

  factory FirstAidGuide.fromMap(Map<String, dynamic> map) => FirstAidGuide(
        id: map['id'] as String,
        title: map['title'] as String,
        icon: map['icon'] as String,
        color: map['color'] as int,
        severity: map['severity'] as String,
        description: map['description'] as String,
        steps: (map['steps'] as List<dynamic>)
            .map((s) => FirstAidStep.fromMap(s as Map<String, dynamic>))
            .toList(),
        warnings: List<String>.from(map['warnings'] as List<dynamic>),
        tips: List<String>.from(map['tips'] as List<dynamic>),
      );
}

class FirstAidStep {
  final int number;
  final String title;
  final String description;
  final String duration;

  const FirstAidStep({
    required this.number,
    required this.title,
    required this.description,
    required this.duration,
  });

  factory FirstAidStep.fromMap(Map<String, dynamic> map) => FirstAidStep(
        number: map['number'] as int,
        title: map['title'] as String,
        description: map['description'] as String,
        duration: map['duration'] as String,
      );
}