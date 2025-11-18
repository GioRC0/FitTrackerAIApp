import 'package:flutter/material.dart';
import 'package:fitracker_app/screens/tabs/home_tab.dart';
import 'package:fitracker_app/screens/tabs/training_tab.dart';
import 'package:fitracker_app/screens/tabs/profile_tab.dart';

// ---------------------------------------------------------------------------


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0; // Comienza en Home Tab (índice 0)
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: _selectedIndex);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Método para obtener los widgets dinámicamente
  List<Widget> get _widgetOptions => <Widget>[
    HomeTab(onNavigateToTraining: () => _onItemTapped(1)),
    const TrainingTab(),
    const ProfileTab(),
  ];

  // Lista de los títulos para el AppBar
  static const List<String> _appBarTitles = <String>[
    'Inicio',
    'Entrenamiento',
    'Tu Perfil',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _tabController.animateTo(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Oculta el botón de retroceso
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Deshabilitar swipe entre tabs
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Entrenar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Tú',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Asegura que el fondo sea siempre visible
      ),
    );
  }
}