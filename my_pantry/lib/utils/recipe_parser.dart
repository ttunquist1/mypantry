import 'package:logging/logging.dart';

import '../models/recipe_model.dart';

class RecipeParser {
  static final _logger = Logger('RecipeParser');

  static List<Recipe> parseRecipesFromJson(Map<String, dynamic> jsonResponse) {
    final recipesData = jsonResponse['recipes'];
    if (recipesData is! List) {
      _logger.warning('Missing or invalid "recipes" payload.');
      return <Recipe>[];
    }

    final recipes = <Recipe>[];
    for (final recipeData in recipesData) {
      if (recipeData is! Map<String, dynamic>) {
        continue;
      }

      final ingredientData = recipeData['ingredients'];
      final ingredients =
          ingredientData is List
              ? ingredientData
                  .map((ingredient) => ingredient.toString())
                  .toList()
              : <String>[];

      recipes.add(
        Recipe(
          day: recipeData['day']?.toString() ?? '',
          name: recipeData['name']?.toString() ?? '',
          prepTime: recipeData['prepTime']?.toString() ?? 'N/A',
          cookTime: recipeData['cookTime']?.toString() ?? 'N/A',
          ingredients: ingredients,
          instructions: recipeData['instructions']?.toString() ?? 'N/A',
        ),
      );
    }

    return recipes;
  }
}
