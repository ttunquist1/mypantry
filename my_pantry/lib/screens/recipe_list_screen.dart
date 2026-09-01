import 'package:flutter/material.dart';

import '../models/recipe_model.dart';
import '../utils/api_service.dart';
import '../utils/recipe_parser.dart';
import '../widgets/appdrawer.dart';
import '../widgets/recipe_card.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final ApiService _apiService = ApiService();

  List<Recipe> _recipes = <Recipe>[];
  List<String> _ingredients = <String>[];
  bool _isLoading = true;
  bool _hasLoaded = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoaded) {
      return;
    }
    _hasLoaded = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    _ingredients =
        args is List ? args.whereType<String>().toList() : <String>[];
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _recipes = <Recipe>[];
    });

    if (_ingredients.isEmpty) {
      setState(() {
        _errorMessage =
            'Select ingredients in Pantry first, then send them here.';
        _isLoading = false;
      });
      return;
    }

    try {
      final jsonResponse = await _apiService.fetchRecipesFromOllamaPersistent(
        _ingredients,
      );
      final parsedRecipes = RecipeParser.parseRecipesFromJson(jsonResponse);

      if (!mounted) {
        return;
      }

      setState(() {
        _recipes = parsedRecipes;
        _isLoading = false;
        if (parsedRecipes.isEmpty) {
          _errorMessage = 'No recipes found.';
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Error loading recipes: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Meal Plan'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRecipes),
        ],
      ),
      endDrawer: const AppDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRecipes,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recipes.isEmpty) {
      return const Center(child: Text('No recipes found.'));
    }

    return ListView.builder(
      itemCount: _recipes.length,
      itemBuilder: (context, index) => RecipeCard(recipe: _recipes[index]),
    );
  }
}
