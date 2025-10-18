import 'package:flutter/material.dart';
import 'package:app_lecturas_jmas/configs/controllers/lectura_enviar_controller.dart';
import 'package:app_lecturas_jmas/configs/controllers/problemas_lectura_controller.dart';
import 'package:app_lecturas_jmas/configs/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/services.dart'; // Añadir este import

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

  @override
  void initState() {
    super.initState();
    _cargarProblemasLectura();
    // Ocultar botones de navegación
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _lecturaActualController.dispose();
    _lecturaAnteriorController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _cargarProblemasLectura() async {
    try {
      final problemas = await _problemasController.listProblmeasLectura();
      setState(() {
        _problemas = problemas;
        // Seleccionar por defecto el problema con id 1
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
    if (_problemaSeleccionado == null) {
      _mostrarMensaje('Selecciona un problema de lectura');
      return;
    }

    // Validación para problemas diferentes a 1 (requieren foto)
    if (_problemaSeleccionado!.idProblema != 1 &&
        _problemaSeleccionado!.idProblema != 27 &&
        _fotoBase64 == null) {
      _mostrarMensaje('Toma una foto como evidencia del problema');
      return;
    }

    // Validación para problema 1 (sin problema)
    if (_problemaSeleccionado!.idProblema == 1) {
      if (_lecturaActualController.text.isEmpty) {
        _mostrarMensaje('Ingresa la lectura actual');
        return;
      }
      if (_fotoBase64 == null) {
        _mostrarMensaje('Toma una foto del medidor');
        return;
      }

      int lecturaActual = int.parse(_lecturaActualController.text);
      int? lecturaAnterior = widget.lectura.leLecturaAnterior;

      if (lecturaAnterior != null && lecturaActual <= lecturaAnterior) {
        _mostrarMensaje(
          'La lectura actual no puede ser menor o igual a la lectura anterior',
        );
        return;
      }
    }

    // Validación para problema 27 (lectura anterior manual)
    if (_problemaSeleccionado!.idProblema == 27) {
      if (_lecturaAnteriorController.text.isEmpty) {
        _mostrarMensaje('Ingresa la lectura anterior');
        return;
      }
      if (_lecturaActualController.text.isEmpty) {
        _mostrarMensaje('Ingresa la lectura actual');
        return;
      }
      if (_fotoBase64 == null) {
        _mostrarMensaje('Toma una foto del medidor');
        return;
      }

      int lecturaAnterior = int.parse(_lecturaAnteriorController.text);
      int lecturaActual = int.parse(_lecturaActualController.text);

      if (lecturaActual <= lecturaAnterior) {
        _mostrarMensaje(
          'La lectura actual no puede ser menor o igual a la lectura anterior',
        );
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
      if (_problemaSeleccionado!.idProblema == 1) {
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
      );

      final resultado = await _lecturaController.editLectEnviar(
        lecturaActualizada,
      );

      if (resultado) {
        _mostrarMensaje('Lectura guardada exitosamente', esError: false);
        Navigator.pop(context, true); // Regresar con éxito
      } else {
        _mostrarMensaje('Error al guardar la lectura');
      }
    } catch (e) {
      print('Error al guardar lectura: $e');
      _mostrarMensaje('Error: $e');
    } finally {
      setState(() {
        _isGuardando = false;
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
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const Divider(),
        ],
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
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información de la lectura
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoItem(
                              'Número de Medidor',
                              widget.lectura.leNumeroMedidor,
                            ),
                            _buildInfoItem('Cuenta', widget.lectura.leCuenta),
                            _buildInfoItem(
                              'Dirección',
                              widget.lectura.leDireccion,
                            ),
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

                    const SizedBox(height: 20),

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
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<ProblemasLectura>(
                              value: _problemaSeleccionado,
                              isExpanded:
                                  true, // Esta línea resuelve el problema
                              items: _problemas.map((problema) {
                                return DropdownMenuItem(
                                  value: problema,
                                  child: Text(
                                    '${problema.idProblema} - ${problema.plDescripcion}',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
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

                    const SizedBox(height: 20),

                    // Sección para tomar foto (para todos los problemas)
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _problemaSeleccionado?.idProblema == 1
                                  ? 'Foto del Medidor'
                                  : 'Foto de Evidencia',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Botón para tomar foto
                            ElevatedButton.icon(
                              onPressed: _tomarFoto,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade800,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              icon: const Icon(Icons.camera_alt),
                              label: Text(
                                _problemaSeleccionado?.idProblema == 1
                                    ? 'Tomar Foto del Medidor'
                                    : 'Tomar Foto de Evidencia',
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Vista previa de la foto
                            if (_fotoBase64 != null)
                              Container(
                                width: double.infinity,
                                height: 200,
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

                    // Sección para lectura actual (solo para problema 1)
                    if (_problemaSeleccionado?.idProblema == 1 ||
                        _problemaSeleccionado?.idProblema == 27) ...[
                      const SizedBox(height: 20),
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Información de Lectura',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Lectura anterior
                              if (_problemaSeleccionado?.idProblema == 1 &&
                                  widget.lectura.leLecturaAnterior != null) ...[
                                _buildInfoItem(
                                  'Lectura Anterior',
                                  widget.lectura.leLecturaAnterior.toString(),
                                ),
                              ],

                              if (_problemaSeleccionado?.idProblema == 27) ...[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: _lecturaAnteriorController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Lectura Anterior',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.numbers),
                                        hintText: 'Ingrese la lectura anterior',
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ],

                              // Campo para lectura actual
                              TextFormField(
                                controller: _lecturaActualController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Lectura Actual',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.numbers),
                                  hintText:
                                      _problemaSeleccionado?.idProblema == 1
                                      ? 'Ingrese lectura mayor a ${widget.lectura.leLecturaAnterior ?? 0}'
                                      : 'Ingrese lectura mayor a la anterior',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),

                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isGuardando ? null : _guardarLectura,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: _isGuardando
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
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
                  ],
                ),
              ),
            ),
    );
  }
}
