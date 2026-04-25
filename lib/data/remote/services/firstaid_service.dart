import 'dart:convert';
import 'package:flutter/services.dart';
import '../../local/models/firstaid_guide_model.dart';
import '../../../core/utils/logger.dart';

class FirstAidService {
  static List<FirstAidGuide>? _cachedGuides;

  static Future<List<FirstAidGuide>> getAllGuides() async {
    if (_cachedGuides != null && _cachedGuides!.isNotEmpty) {
      return _cachedGuides!;
    }

    try {
      AppLogger.info('Loading firstaid JSON...', tag: 'FA');
      final jsonStr = await rootBundle
          .loadString('assets/firstaid/firstaid_data.json');
      AppLogger.info('JSON loaded, length: ${jsonStr.length}', tag: 'FA');
      
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final list = map['guides'] as List<dynamic>;
      
      _cachedGuides = list
          .map((g) => FirstAidGuide.fromMap(g as Map<String, dynamic>))
          .toList();
      
      AppLogger.success('${_cachedGuides!.length} guides loaded ✅', tag: 'FA');
      return _cachedGuides!;
    } catch (e, stack) {
      AppLogger.error('FAILED: $e', tag: 'FA');
      AppLogger.error('Stack: $stack', tag: 'FA');
      rethrow;
    }
  }
}