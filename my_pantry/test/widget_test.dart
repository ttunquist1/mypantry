import 'package:flutter_test/flutter_test.dart';
import 'package:my_pantry/utils/recipe_parser.dart';

void main() {
  test('Recipe parser maps valid JSON into recipe models', () {
    final json = <String, dynamic>{
      'recipes': [
        <String, dynamic>{
          'day': 'Monday',
          'name': 'Veggie Pasta',
          'prepTime': '10 min',
          'cookTime': '20 min',
          'ingredients': ['Pasta', 'Tomato', 'Spinach'],
          'instructions': 'Boil pasta and combine with vegetables.',
        },
      ],
    };

    final recipes = RecipeParser.parseRecipesFromJson(json);

    expect(recipes.length, 1);
    expect(recipes.first.day, 'Monday');
    expect(recipes.first.ingredients, ['Pasta', 'Tomato', 'Spinach']);
  });

  test('Recipe parser returns empty list for invalid payloads', () {
    final recipes = RecipeParser.parseRecipesFromJson(<String, dynamic>{});
    expect(recipes, isEmpty);
  });
}
