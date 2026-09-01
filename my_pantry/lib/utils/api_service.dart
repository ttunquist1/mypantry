import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService({String? baseUrl}) : _baseUrl = _resolveBaseUrl(baseUrl);

  final String _baseUrl;
  static const String _envBaseUrl = String.fromEnvironment('OLLAMA_BASE_URL');

  static String _resolveBaseUrl(String? explicitBaseUrl) {
    final explicit = explicitBaseUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final env = _envBaseUrl.trim();
    if (env.isNotEmpty) {
      return env;
    }

    return _defaultBaseUrl();
  }

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:11434/api/generate';
    }

    // Android emulator cannot reach host machine through localhost.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:11434/api/generate';
    }

    // iOS simulator can use localhost/127.0.0.1.
    return 'http://127.0.0.1:11434/api/generate';
  }

  String _ingredientsCacheKey(List<String> ingredients) {
    final sorted = List<String>.from(ingredients)..sort();
    return 'recipes_cache_${sorted.join(',')}';
  }

  String _ingredientsTimeKey(List<String> ingredients) {
    final sorted = List<String>.from(ingredients)..sort();
    return 'recipes_cache_time_${sorted.join(',')}';
  }

  Future<Map<String, dynamic>> fetchRecipesFromOllamaPersistent(
    List<String> ingredients,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _ingredientsCacheKey(ingredients);
    final timeKey = _ingredientsTimeKey(ingredients);

    final cachedData = prefs.getString(cacheKey);
    final cacheTime = prefs.getInt(timeKey);

    final now = DateTime.now().millisecondsSinceEpoch;
    const oneWeekMs = 7 * 24 * 60 * 60 * 1000;

    if (cachedData != null &&
        cacheTime != null &&
        (now - cacheTime) < oneWeekMs) {
      final cachedJson = json.decode(cachedData);
      if (cachedJson is Map<String, dynamic>) {
        return cachedJson;
      }
    }

    final jsonResponse = await _fetchRecipesFromApi(ingredients);
    await prefs.setString(cacheKey, json.encode(jsonResponse));
    await prefs.setInt(timeKey, now);
    return jsonResponse;
  }

  Future<Map<String, dynamic>> _fetchRecipesFromApi(
    List<String> ingredients,
  ) async {
    final requestBody = <String, dynamic>{
      'model': 'llama3.2',
      'prompt':
          'Suppose that you are a terrific chef. Create a menu for one week and be cooked or prepared below 30 min with the following ingredients. Include prep time and cooking time in minutes and ingredient amounts for every recipe: ${ingredients.join(', ')}. Return JSON only with this structure: {"recipes": [{"day": "Monday", "name": "Recipe Name", "prepTime": "15 min", "cookTime": "20 min", "ingredients": ["ingredient1", "ingredient2"], "instructions": "Cooking instructions here."}]}',
      'stream': false,
      'format': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'recipes': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{
                'day': <String, String>{'type': 'string'},
                'name': <String, String>{'type': 'string'},
                'prepTime': <String, String>{'type': 'string'},
                'cookTime': <String, String>{'type': 'string'},
                'ingredients': <String, dynamic>{
                  'type': 'array',
                  'items': <String, String>{'type': 'string'},
                },
                'instructions': <String, String>{'type': 'string'},
              },
              'required': <String>[
                'day',
                'name',
                'prepTime',
                'cookTime',
                'ingredients',
                'instructions',
              ],
            },
          },
        },
        'required': <String>['recipes'],
      },
    };

    final uri = Uri.parse(_baseUrl);
    final response = await http
        .post(
          uri,
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        )
        .timeout(const Duration(seconds: 35));

    if (response.statusCode != 200) {
      throw Exception(
        'Recipe API request failed (${response.statusCode}) at $_baseUrl: ${response.body}',
      );
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('API response was not a JSON object.');
    }

    final responseString = decoded['response'];
    if (responseString is! String || responseString.trim().isEmpty) {
      throw const FormatException('API response did not contain recipe JSON.');
    }

    final parsedRecipeJson = json.decode(responseString);
    if (parsedRecipeJson is! Map<String, dynamic>) {
      throw const FormatException('Recipe payload was not a JSON object.');
    }

    return parsedRecipeJson;
  }
}
