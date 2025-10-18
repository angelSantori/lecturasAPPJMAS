import 'dart:convert';
import 'dart:io';
import 'package:app_lecturas_jmas/configs/services/auth_service.dart';
import 'package:http/io_client.dart';

class ProblemasLecturaController {
  final AuthService _authService = AuthService();

  IOClient _createHttpClient() {
    final ioClient = HttpClient();
    ioClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return IOClient(ioClient);
  }

  Future<List<ProblemasLectura>> listProblmeasLectura() async {
    try {
      final IOClient client = _createHttpClient();
      final response = await client.get(
        Uri.parse('${_authService.apiURL}/ProblemasLecturas'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData
            .map((listPL) => ProblemasLectura.fromMap(listPL))
            .toList();
      } else {
        print(
          'Error listProblmeasLectura | Ife | PLController: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('Error listProblmeasLectura | Try | PLController: $e');
      return [];
    }
  }
}

class ProblemasLectura {
  final int idProblema;
  final String plDescripcion;
  ProblemasLectura({required this.idProblema, required this.plDescripcion});

  ProblemasLectura copyWith({int? idProblema, String? plDescripcion}) {
    return ProblemasLectura(
      idProblema: idProblema ?? this.idProblema,
      plDescripcion: plDescripcion ?? this.plDescripcion,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'idProblema': idProblema,
      'plDescripcion': plDescripcion,
    };
  }

  factory ProblemasLectura.fromMap(Map<String, dynamic> map) {
    return ProblemasLectura(
      idProblema: map['idProblema'] as int,
      plDescripcion: map['plDescripcion'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ProblemasLectura.fromJson(String source) =>
      ProblemasLectura.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'ProblemasLectura(idProblema: $idProblema, plDescripcion: $plDescripcion)';

  @override
  bool operator ==(covariant ProblemasLectura other) {
    if (identical(this, other)) return true;

    return other.idProblema == idProblema &&
        other.plDescripcion == plDescripcion;
  }

  @override
  int get hashCode => idProblema.hashCode ^ plDescripcion.hashCode;
}
