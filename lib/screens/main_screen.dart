import 'package:flutter/material.dart';

// TODO: Crear estos archivos de pantalla por separado
// import 'package:fitracker_app/screens/tabs/home_tab.dart';
import 'package:fitracker_app/screens/tabs/training_tab.dart';
// import 'package:fitracker_app/screens/tabs/profile_tab.dart';

// --- Widgets de Pestaña de Ejemplo (puedes moverlos a sus propios archivos) ---
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Contenido de Inicio (Home)'));
  }
}


class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Contenido de Perfil'));
  }
}
// ---------------------------------------------------------------------------


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Controla la pestaña activa, 0: Inicio, 1: Entrenamiento, 2: Perfil

  // Lista de los widgets que se mostrarán en el cuerpo principal
  static const List<Widget> _widgetOptions = <Widget>[
    HomeTab(),
    TrainingTab(),
    ProfileTab(),
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
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
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