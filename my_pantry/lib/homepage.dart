import 'dart:async';

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
  late final PageController _controller;
  final pantryKey = GlobalKey<PantryPageState>();
  final shoppingKey = GlobalKey<ShoppingListPageState>();

  int _currentPage = 0;
  bool _showListName = false;
  bool _appliedRouteArguments = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: 0);
  }

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

    if (initialPage == _currentPage) {
      return;
    }

    _currentPage = initialPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        _controller.jumpToPage(initialPage);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onPageChanged(int index) {
    _timer?.cancel();

    setState(() {
      _currentPage = index;
      _showListName = false;
    });

    _timer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) {
        return;
      }
      if (_currentPage == index) {
        setState(() {
          _showListName = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pantryState = pantryKey.currentState;
    final shoppingState = shoppingKey.currentState;

    final String titleText = _showListName
        ? (_currentPage == 0
            ? (pantryState?.selectedListName ?? 'Pantry')
            : (shoppingState?.selectedListName ?? 'Shopping List'))
        : (_currentPage == 0 ? 'Pantry' : 'Shopping List');

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration:
              _showListName ? const Duration(milliseconds: 300) : Duration.zero,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Text(
            titleText,
            key: ValueKey<String>(titleText),
          ),
        ),
      ),
      endDrawer: AppDrawer(pageController: _controller),
      body: Stack(
        children: [
          const SwirlBackground(),
          Positioned.fill(
            child: PageView(
              controller: _controller,
              onPageChanged: _onPageChanged,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: PantryPage(key: pantryKey),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: ShoppingListPage(key: shoppingKey),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 25,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) {
                return GestureDetector(
                  onTap: () {
                    if (_currentPage != index) {
                      _controller.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 12 : 8,
                    height: _currentPage == index ? 12 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.blue
                          : Colors.grey.shade400,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
