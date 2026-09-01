import 'package:flutter/material.dart';
import 'package:my_pantry/pantry.dart';
import 'package:my_pantry/shopping.dart';
import 'package:my_pantry/widgets/appdrawer.dart';
import 'package:my_pantry/widgets/swirl_bg.dart';

class HomePager extends StatefulWidget {
  const HomePager({super.key});

  @override
  State<HomePager> createState() => _HomePagerState();
}

class _HomePagerState extends State<HomePager> {
  final pantryKey = GlobalKey<PantryPageState>();
  final shoppingKey = GlobalKey<ShoppingListPageState>();

  int _currentPage = 0;
  bool _appliedRouteArguments = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedRouteArguments) {
      return;
    }
    _appliedRouteArguments = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    final routeMap = args is Map ? args : null;
    final routeIndex = routeMap?['initialPage'];
    final initialPage =
        routeIndex is int ? routeIndex.clamp(0, 1) : _currentPage;

    if (initialPage != _currentPage) {
      setState(() {
        _currentPage = initialPage;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pantryState = pantryKey.currentState;
    final shoppingState = shoppingKey.currentState;

    final titleText =
        _currentPage == 0
            ? (pantryState?.selectedListName ?? 'Pantry')
            : (shoppingState?.selectedListName ?? 'Shopping');

    return Scaffold(
      appBar: AppBar(title: Text(titleText), centerTitle: false),
      endDrawer: const AppDrawer(),
      body: Stack(
        children: [
          const SwirlBackground(),
          Positioned.fill(
            child: IndexedStack(
              index: _currentPage,
              children: [
                PantryPage(key: pantryKey),
                ShoppingListPage(key: shoppingKey),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _currentPage == 0
                ? pantryState?.openAddItemSheet
                : shoppingState?.openAddItemSheet,
        icon: const Icon(Icons.add),
        label: Text(
          _currentPage == 0 ? 'Add Pantry Item' : 'Add Shopping Item',
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentPage,
        onDestinationSelected: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Pantry',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Shopping',
          ),
        ],
      ),
    );
  }
}
