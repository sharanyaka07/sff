import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class FirstAidScreen extends StatefulWidget {
  const FirstAidScreen({super.key});

  @override
  State<FirstAidScreen> createState() => _FirstAidScreenState();
}

class _FirstAidScreenState extends State<FirstAidScreen> {
  List<dynamic> _guides = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _selectedLang = 'en';


  final Map<String, String> _languages = {
    'en': 'English',
    'hi': 'हिन्दी',
    'kn': 'ಕನ್ನಡ',
    'te': 'తెలుగు',
    'ta': 'தமிழ்',
    'ml': 'മലയാളം',
  };

  @override
  void initState() {
    super.initState();
    _loadGuides();
  }

  Future<void> _loadGuides() async {
    try {
      final jsonStr = await rootBundle
          .loadString('assets/firstaid/firstaid_data.json');
      final data = jsonDecode(jsonStr);
      setState(() {
        _guides = data['guides'] as List<dynamic>;
        _filtered = _guides;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _guides;
      } else {
        _filtered = _guides.where((g) {
          final t = g['translations'][_selectedLang];
          final title =
              (t['title'] as String).toLowerCase();
          final desc =
              (t['description'] as String).toLowerCase();
          return title.contains(query.toLowerCase()) ||
              desc.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  String _getText(dynamic guide, String field) {
    try {
      return guide['translations'][_selectedLang][field] as String;
    } catch (_) {
      return guide['translations']['en'][field] as String;
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AppColors.success,
        title: const Text('First Aid Guide'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Language selector
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  children: _languages.entries.map((entry) {
                    final selected = _selectedLang == entry.key;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedLang = entry.key),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            color: selected
                                ? AppColors.success
                                : Colors.white,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search first aid guides...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? const Center(child: Text('No guides found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final guide = _filtered[index];
                    final severity =
                        guide['severity'] as String? ?? 'low';
                    final color = _severityColor(severity);

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _FirstAidDetailScreen(
                            guide: guide,
                            lang: _selectedLang,
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: color.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _iconForGuide(
                                    guide['icon'] as String? ?? ''),
                                color: color,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getText(guide, 'title'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _getText(guide, 'description'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                severity.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  IconData _iconForGuide(String icon) {
    switch (icon) {
      case 'favorite':
        return Icons.favorite;
      case 'air':
        return Icons.air;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'water_drop':
        return Icons.water_drop;
      case 'broken_image':
        return Icons.healing;
      case 'bug_report':
        return Icons.bug_report;
      case 'thermostat':
        return Icons.thermostat;
      case 'electric_bolt':
        return Icons.electric_bolt;
      default:
        return Icons.medical_services;
    }
  }
}

// ── Detail Screen ──────────────────────────────────────────────────
class _FirstAidDetailScreen extends StatelessWidget {
  final dynamic guide;
  final String lang;

  const _FirstAidDetailScreen({
    required this.guide,
    required this.lang,
  });

  String _getText(String field) {
    try {
      return guide['translations'][lang][field] as String;
    } catch (_) {
      return guide['translations']['en'][field] as String;
    }
  }

  List<dynamic> _getList(String field) {
    try {
      return guide['translations'][lang][field] as List<dynamic>;
    } catch (_) {
      return guide['translations']['en'][field] as List<dynamic>? ?? [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _getList('steps');
    final warnings = _getList('warnings');
    final tips = _getList('tips');
    final severity = guide['severity'] as String? ?? 'low';

    Color color;
    switch (severity) {
      case 'critical':
        color = AppColors.danger;
        break;
      case 'high':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.success;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        title: Text(_getText('title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Description
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getText('description'),
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Steps
          if (steps.isNotEmpty) ...[
            const Text(
              'STEPS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            ...steps.asMap().entries.map((entry) {
              final step = entry.value;
              final num = (step['number'] ?? entry.key + 1).toString();
              final title = step['title'] as String? ?? '';
              final desc = step['description'] as String? ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: color,
                      radius: 14,
                      child: Text(
                        num,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Warnings
          if (warnings.isNotEmpty) ...[
            const Text(
              'WARNINGS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ...warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber,
                          color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          w as String,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ],

          // Tips
          if (tips.isNotEmpty) ...[
            const Text(
              'TIPS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ...tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t as String,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}