import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_lecturas_jmas/configs/controllers/lectura_enviar_controller.dart';
import 'package:app_lecturas_jmas/configs/controllers/problemas_lectura_controller.dart';
import 'package:app_lecturas_jmas/configs/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class DetailsLecturasScreen extends StatefulWidget {
  final LELista lectura;

  const DetailsLecturasScreen({super.key, required this.lectura});

  @override
  State<DetailsLecturasScreen> createState() => _DetailsLecturasScreenState();
}

class _DetailsLecturasScreenState extends State<DetailsLecturasScreen> {
  final LecturaEnviarController _lecturaController = LecturaEnviarController();
  final ProblemasLecturaController _problemasController =
      ProblemasLecturaController();
  final AuthService _authService = AuthService();

  List<ProblemasLectura> _problemas = [];
  ProblemasLectura? _problemaSeleccionado;
  final TextEditingController _lecturaActualController =
      TextEditingController();
  final TextEditingController _lecturaAnteriorController =
      TextEditingController();
  String? _fotoBase64;
  bool _isLoading = true;
  bool _isGuardando = false;
  bool _isObteniendoUbicacion = false;
  bool _botonGuardarBloqueado = false; // Nueva variable para bloquear el botón
  final PageController _pageController = PageController(viewportFraction: 0.9);

  // Variables para ubicación
  double? _latitud;
  double? _longitud;
  String? _ubicacionTexto;

  @override
  void initState() {
    super.initState();
    _cargarProblemasLectura();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _lecturaActualController.dispose();
    _lecturaAnteriorController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _cargarProblemasLectura() async {
    try {
      final problemas = await _problemasController.listProblmeasLectura();
      setState(() {
        _problemas = problemas;
        _problemaSeleccionado = problemas.firstWhere(
          (problema) => problema.idProblema == 1,
          orElse: () => problemas.first,
        );
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar problemas de lectura: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _solicitarPermisosUbicacion() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<void> _obtenerUbicacionActual() async {
    setState(() {
      _isObteniendoUbicacion = true;
    });

    try {
      // Solicitar permisos
      final permisosConcedidos = await _solicitarPermisosUbicacion();

      if (!permisosConcedidos) {
        _mostrarMensaje(
          'Se requieren permisos de ubicación para guardar la lectura',
        );
        setState(() {
          _isObteniendoUbicacion = false;
        });
        return;
      }

      // Verificar si los servicios de ubicación están habilitados
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        _mostrarMensaje('Por favor, activa los servicios de ubicación');
        setState(() {
          _isObteniendoUbicacion = false;
        });
        return;
      }

      // Obtener la ubicación actual
      Position posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _latitud = posicion.latitude;
        _longitud = posicion.longitude;
        _ubicacionTexto =
            '${_latitud!.toStringAsFixed(6)}, ${_longitud!.toStringAsFixed(6)}';
        _isObteniendoUbicacion = false;
      });

      print('Ubicación obtenida: $_ubicacionTexto');
    } catch (e) {
      print('Error al obtener ubicación: $e');
      setState(() {
        _isObteniendoUbicacion = false;
      });

      if (e is TimeoutException) {
        _mostrarMensaje('Tiempo de espera agotado al obtener la ubicación');
      } else {
        _mostrarMensaje('Error al obtener la ubicación: $e');
      }
    }
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50, // Calidad reducida para hacerla más ligera
      maxWidth: 800,
    );

    if (imagen != null) {
      final bytes = await imagen.readAsBytes();
      setState(() {
        _fotoBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _guardarLectura() async {
    // Bloquear el botón inmediatamente al presionarlo
    if (_botonGuardarBloqueado) {
      return; // Si ya está bloqueado, no hacer nada
    }

    setState(() {
      _botonGuardarBloqueado = true; // Bloquear el botón
    });

    if (_problemaSeleccionado == null) {
      _mostrarMensaje('Selecciona un problema de lectura');
      setState(() {
        _botonGuardarBloqueado = false; // Desbloquear en caso de error
      });
      return;
    }

    await _obtenerUbicacionActual();

    // Si no se pudo obtener la ubicación, no continuar
    if (_latitud == null || _longitud == null) {
      _mostrarMensaje('No se pudo obtener la ubicación. Intenta nuevamente.');
      setState(() {
        _botonGuardarBloqueado = false; // Desbloquear en caso de error
      });
      return;
    }

    // Validación para problemas diferentes a 1 (requieren foto)
    if (_problemaSeleccionado!.idProblema != 1 &&
        _problemaSeleccionado!.idProblema != 27 &&
        _fotoBase64 == null) {
      _mostrarMensaje('Toma una foto como evidencia del problema');
      setState(() {
        _botonGuardarBloqueado = false; // Desbloquear en caso de error
      });
      return;
    }

    // Validación para problema 1 (sin problema)
    if (_problemaSeleccionado!.idProblema == 1) {
      if (_lecturaActualController.text.isEmpty) {
        _mostrarMensaje('Ingresa la lectura actual');
        setState(() {
          _botonGuardarBloqueado = false; // Desbloquear en caso de error
        });
        return;
      }
      if (_fotoBase64 == null) {
        _mostrarMensaje('Toma una foto del medidor');
        setState(() {
          _botonGuardarBloqueado = false; // Desbloquear en caso de error
        });
        return;
      }

      int lecturaActual = int.parse(_lecturaActualController.text);
      int? lecturaAnterior = widget.lectura.leLecturaAnterior;

      if (lecturaAnterior != null && lecturaActual < lecturaAnterior) {
        _mostrarMensaje(
          'La lectura actual no puede ser menor a la lectura anterior',
        );
        setState(() {
          _botonGuardarBloqueado = false; // Desbloquear en caso de error
        });
        return;
      }
    }

    // Validación para problema 27 (lectura anterior manual)
    if (_problemaSeleccionado!.idProblema == 27) {
      if (_lecturaAnteriorController.text.isEmpty) {
        _mostrarMensaje('Ingresa la lectura anterior');
        setState(() {
          _botonGuardarBloqueado = false; // Desbloquear en caso de error
        });
        return;
      }
      if (_lecturaActualController.text.isEmpty) {
        _mostrarMensaje('Ingresa la lectura actual');
        setState(() {
          _botonGuardarBloqueado = false; // Desbloquear en caso de error
        });
        return;
      }
      if (_fotoBase64 == null) {
        _mostrarMensaje('Toma una foto del medidor');
        setState(() {
          _botonGuardarBloqueado = false; // Desbloquear en caso de error
        });
        return;
      }

      int lecturaAnterior = int.parse(_lecturaAnteriorController.text);
      int lecturaActual = int.parse(_lecturaActualController.text);

      if (lecturaActual < lecturaAnterior) {
        _mostrarMensaje(
          'La lectura actual no puede ser menor a la lectura anterior',
        );
        setState(() {
          _botonGuardarBloqueado = false; // Desbloquear en caso de error
        });
        return;
      }
    }

    setState(() {
      _isGuardando = true;
    });

    try {
      final user = await _authService.getUserData();

      // Determinar lectura anterior según el problema
      int? lecturaAnteriorFinal;
      if (_problemaSeleccionado!.idProblema == 1 ||
          _problemaSeleccionado!.idProblema != 27) {
        lecturaAnteriorFinal = widget.lectura.leLecturaAnterior;
      } else if (_problemaSeleccionado!.idProblema == 27) {
        lecturaAnteriorFinal = int.parse(_lecturaAnteriorController.text);
      }

      // Crear objeto LecturaEnviar actualizado
      final lecturaActualizada = LecturaEnviar(
        idLectEnviar: widget.lectura.idLectEnviar,
        leCuenta: widget.lectura.leCuenta,
        leNombre: widget.lectura.leNombre,
        leDireccion: widget.lectura.leDireccion,
        leId: widget.lectura.leId,
        lePeriodo: widget.lectura.lePeriodo,
        leFecha: DateTime.now(),
        leNumeroMedidor: widget.lectura.leNumeroMedidor,
        leLecturaAnterior: lecturaAnteriorFinal,
        leLecturaActual:
            (_problemaSeleccionado!.idProblema == 1 ||
                _problemaSeleccionado!.idProblema == 27)
            ? int.parse(_lecturaActualController.text)
            : null,
        idProblemaLectura: _problemaSeleccionado!.idProblema,
        leRuta: widget.lectura.leRuta,
        leFotoBase64: _fotoBase64,
        idUser: user?.id_User,
        leEstado: true,
        leCampo17: widget.lectura.leCampo17,
        leUbicacion: _ubicacionTexto,
      );

      final resultado = await _lecturaController.editLectEnviar(
        lecturaActualizada,
      );

      if (resultado) {
        _mostrarMensaje('Lectura guardada exitosamente', esError: false);
        Navigator.pop(context, true); // Regresar con éxito
      } else {
        _mostrarMensaje('Error al guardar la lectura');
        setState(() {
          _botonGuardarBloqueado = false; // Desbloquear en caso de error
        });
      }
    } catch (e) {
      print('Error al guardar lectura: $e');
      _mostrarMensaje('Error: $e');
      setState(() {
        _botonGuardarBloqueado = false; // Desbloquear en caso de error
      });
    } finally {
      setState(() {
        _isGuardando = false;
        // No desbloqueamos _botonGuardarBloqueado aquí porque:
        // - Si fue exitoso, se navega a otra pantalla
        // - Si hubo error, ya se desbloqueó en los catch
      });
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildInfoItem(String titulo, String? valor) {
    if (valor == null || valor.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(fontSize: 20, color: Colors.black87),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildPrimeraPantalla() {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Información de la lectura centrada
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Icono principal
                  Icon(Icons.water_drop, size: 60, color: Colors.blue.shade900),
                  const SizedBox(height: 10),

                  _buildInfoItem(
                    'Número de Medidor',
                    widget.lectura.leNumeroMedidor,
                  ),
                  _buildInfoItem('Cuenta', widget.lectura.leCuenta),
                  _buildInfoItem('Dirección', widget.lectura.leDireccion),
                  _buildInfoItem(
                    'ID - Nombre',
                    '${widget.lectura.leId?.toString()} - ${widget.lectura.leNombre}',
                  ),
                  _buildInfoItem('Periodo', widget.lectura.lePeriodo),
                  _buildInfoItem('Ruta', widget.lectura.leRuta),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegundaPantalla() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Selector de problemas de lectura
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Problema de Lectura',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ProblemasLectura>(
                            value: _problemaSeleccionado,
                            isExpanded: true,
                            items: _problemas.map((problema) {
                              return DropdownMenuItem(
                                value: problema,
                                child: Text(
                                  '${problema.idProblema} - ${problema.plDescripcion}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(fontSize: 20),
                                ),
                              );
                            }).toList(),
                            onChanged: (ProblemasLectura? nuevoProblema) {
                              setState(() {
                                _problemaSeleccionado = nuevoProblema;
                              });
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Sección para tomar foto
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _tomarFoto,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.camera_alt),
                                  label: Text(
                                    _problemaSeleccionado?.idProblema == 1
                                        ? 'Foto Medidor'
                                        : 'Foto Evidencia',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          if (_fotoBase64 != null)
                            Container(
                              width: double.infinity,
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.memory(
                                base64Decode(_fotoBase64!),
                                fit: BoxFit.cover,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Sección para lectura actual
                  if (_problemaSeleccionado?.idProblema == 1 ||
                      _problemaSeleccionado?.idProblema == 27) ...[
                    const SizedBox(height: 10),
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Información de Lectura',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Layout en fila para lectura anterior y actual
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_problemaSeleccionado?.idProblema ==
                                              1 &&
                                          widget.lectura.leLecturaAnterior !=
                                              null)
                                        _buildLecturaAnteriorItem(),

                                      if (_problemaSeleccionado?.idProblema ==
                                          27)
                                        _buildLecturaAnteriorInput(),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // Columna derecha - Lectura Actual
                                Expanded(child: _buildLecturaActualInput()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Botón guardar - Actualizado para usar _botonGuardarBloqueado
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isGuardando || _botonGuardarBloqueado)
                          ? null
                          : _guardarLectura,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (_isGuardando || _botonGuardarBloqueado)
                            ? Colors.grey.shade400
                            : Colors.green.shade700,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isGuardando
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(width: 10),
                                Text('Guardando...'),
                              ],
                            )
                          : const Text(
                              'Guardar Lectura',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para mostrar la lectura anterior (problema 1)
  Widget _buildLecturaAnteriorItem() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Lectura Anterior',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.lectura.leLecturaAnterior?.toString() ?? 'N/A',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }

  // Método para el input de lectura anterior (problema 27)
  Widget _buildLecturaAnteriorInput() {
    return TextFormField(
      controller: _lecturaAnteriorController,
      style: TextStyle(fontSize: 30),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        label: const Center(child: Text('Lectura Anterior')),
        labelStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Método para el input de lectura actual
  Widget _buildLecturaActualInput() {
    return TextFormField(
      controller: _lecturaActualController,
      style: TextStyle(fontSize: 30),
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        label: const Center(child: Text('Lectura actual')),
        labelStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de Lectura'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : PageView(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              children: [_buildPrimeraPantalla(), _buildSegundaPantalla()],
            ),
    );
  }
}
