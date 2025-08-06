import 'package:btk_demo/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppView extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppView({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBarView(),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        indicatorColor: Colors.transparent,
        onDestinationSelected: navigationShell.goBranch,
        destinations: [
          _menuItem(
            index: 0,
            currentIndex: navigationShell.currentIndex,
            label: "Ana Sayfa",
            icon: Icons.home,
          ),
          _menuItem(
            index: 1,
            currentIndex: navigationShell.currentIndex,
            label: "Bakılan Hastalar",
            icon: Icons.accessibility_new,
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
  }) {
    return NavigationDestination(
      icon: Icon(
        icon,
        color: currentIndex == index
            ? AppTheme.lightTheme.primaryColor
            : Colors.black54,
      ),
      label: label,
    );
  }

  AppBar _appBarView() {
    return AppBar(
      title: const Text(
        "PATSIM",
        style: TextStyle(color: Color.fromARGB(255, 80, 125, 140)),
      ),
      backgroundColor: const Color.fromARGB(255, 225, 226, 226),
      actions: [IconButton(onPressed: () {}, icon: Icon(Icons.settings))],
    );
  }
}
