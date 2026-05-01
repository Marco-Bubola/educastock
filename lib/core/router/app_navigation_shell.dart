import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

class AppNavigationShell extends StatelessWidget {
  final Widget child;
  final String location;

  const AppNavigationShell({
    super.key,
    required this.child,
    required this.location,
  });

  static const _tabRoutes = [
    AppRoutes.dashboard,
    AppRoutes.productList,
    AppRoutes.alerts,
    AppRoutes.reports,
  ];

  int _selectedIndex(String currentLocation) {
    if (currentLocation.startsWith(AppRoutes.alerts)) return 2;
    if (currentLocation.startsWith(AppRoutes.reports)) return 3;
    if (currentLocation.startsWith(AppRoutes.productList)) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Estoque',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Alertas',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Relatorios',
          ),
        ],
        selectedIndex: _selectedIndex(location),
        onDestinationSelected: (index) {
          context.go(_tabRoutes[index]);
        },
      ),
    );
  }
}