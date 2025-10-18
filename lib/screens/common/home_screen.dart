import 'package:app_lecturas_jmas/screens/lectEnviar/details_lecturas.dart';
import 'package:flutter/material.dart';
import 'package:app_lecturas_jmas/configs/controllers/lectura_enviar_controller.dart';
import 'package:app_lecturas_jmas/configs/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LecturaEnviarController _lecturaController = LecturaEnviarController();
  final AuthService _authService = AuthService();
  List<LELista> _lecturas = [];
  bool _isLoading = true;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _cargarLecturas();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    try {
      final user = await _authService.getUserData();
      setState(() {
        _userName = user?.user_Name ?? 'Usuario';
      });
    } catch (e) {
      print('Error al cargar datos del usuario: $e');
      setState(() {
        _userName = 'Usuario';
      });
    }
  }

  Future<void> _cargarLecturas() async {
    try {
      final lecturas = await _lecturaController.listLectEnviar();
      // Filtrar solo las lecturas con estado false
      final lecturasFiltradas = lecturas
          .where((lectura) => lectura.leEstado == false)
          .toList();

      setState(() {
        _lecturas = lecturasFiltradas;
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar lecturas: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cerrarSesion() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _authService.clearAuthData();
                await _authService.deleteToken();

                // Navegar a la pantalla de login y limpiar el stack
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login', // Asegúrate de que esta ruta esté definida en tu app
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text('Salir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Header del Drawer con información del usuario
          UserAccountsDrawerHeader(
            accountName: Text(
              _userName ?? 'Usuario',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: const Text(
              'Aplicación de Lecturas',
              style: TextStyle(fontSize: 14),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _userName != null && _userName!.isNotEmpty
                    ? _userName![0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            decoration: BoxDecoration(color: Colors.blue.shade900),
          ),

          // Opciones del menú
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Inicio'),
                  onTap: () {
                    Navigator.pop(context); // Cerrar el drawer
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Actualizar'),
                  onTap: () {
                    Navigator.pop(context);
                    _cargarLecturas();
                  },
                ),
                const Divider(),

                // Opción para cerrar sesión
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _cerrarSesion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaLectura(LELista lectura) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dirección
            if (lectura.leDireccion != null && lectura.leDireccion!.isNotEmpty)
              _buildInfoRow('📍 Dirección:', lectura.leDireccion!),

            // Nombre
            if (lectura.leNombre != null && lectura.leNombre!.isNotEmpty)
              _buildInfoRow('👤 Nombre:', lectura.leNombre!),

            // Número de medidor
            if (lectura.leNumeroMedidor != null &&
                lectura.leNumeroMedidor!.isNotEmpty)
              _buildInfoRow('🔢 Medidor:', lectura.leNumeroMedidor!),

            // Periodo
            if (lectura.lePeriodo != null && lectura.lePeriodo!.isNotEmpty)
              _buildInfoRow('📅 Periodo:', lectura.lePeriodo!),

            // Información adicional
            const SizedBox(height: 8),
            Row(
              children: [
                // Lectura anterior
                if (lectura.leLecturaAnterior != null)
                  Expanded(
                    child: _buildInfoChip(
                      'Anterior: ${lectura.leLecturaAnterior}',
                      Colors.blue.shade100,
                    ),
                  ),

                const SizedBox(width: 8),

                // Lectura actual
                Expanded(
                  child: _buildInfoChip(
                    'Actual: ${lectura.leLecturaActual ?? 'Sin tomar'}',
                    Colors.green.shade100,
                  ),
                ),
              ],
            ),

            // Estado (siempre será false según el filtro)
            const SizedBox(height: 8),
            _buildInfoChip('Pendiente', Colors.orange.shade100),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildListaLecturas() {
    if (_lecturas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay lecturas pendientes',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarLecturas,
      child: ListView.builder(
        itemCount: _lecturas.length,
        itemBuilder: (context, index) {
          final lectura = _lecturas[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsLecturasScreen(lectura: lectura),
                ),
              ).then((actualizado) {
                if (actualizado == true) {
                  _cargarLecturas();
                }
              });
            },
            child: _buildTarjetaLectura(lectura),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturas Pendientes'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _cargarLecturas,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildListaLecturas(),
      floatingActionButton: FloatingActionButton(
        onPressed: _cargarLecturas,
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        tooltip: 'Actualizar lecturas',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
