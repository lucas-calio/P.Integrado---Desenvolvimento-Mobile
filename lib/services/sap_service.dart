import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SapService {
  // ==========================================
  // CONFIGURAÇÃO DE CLIENTE (SSL)
  // ==========================================

  /// Cria um cliente HTTP que respeita a configuração de SSL do usuário
  static Future<http.Client> _getClient() async {
    final prefs = await SharedPreferences.getInstance();
    final permitirInseguro = prefs.getBool('sap_allow_untrusted') ?? true;

    if (permitirInseguro) {
      // Ignora a validação de certificado SSL (necessário para certificados autoassinados)
      final ioClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return IOClient(ioClient);
    }
    // Retorna o cliente padrão com SSL estrito
    return http.Client();
  }

  // ==========================================
  // MÉTODOS DE AUTENTICAÇÃO
  // ==========================================

  static Future<bool> login({
    required String usuario,
    required String senha,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final company = prefs.getString('sap_company');

    if (baseUrl == null || company == null) return false;

    try {
      final client = await _getClient();
      final response = await client
          .post(
            Uri.parse('$baseUrl/Login'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "CompanyDB": company,
              "UserName": usuario,
              "Password": senha,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sessionId = data['SessionId'];

        if (sessionId != null) {
          await prefs.setString('B1SESSION', sessionId);
        }

        final rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          final routeIdMatch = RegExp(r'ROUTEID=([^;]+)').firstMatch(rawCookie);
          if (routeIdMatch != null) {
            await prefs.setString('ROUTEID', routeIdMatch.group(1)!);
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      print("Erro de conexão no login: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');

    if (baseUrl != null && session != null) {
      try {
        final client = await _getClient();
        await client.post(
          Uri.parse('$baseUrl/Logout'),
          headers: {"Cookie": "B1SESSION=$session"},
        );
      } catch (_) {}
    }
    await prefs.remove('B1SESSION');
    await prefs.remove('ROUTEID');
  }

  // ==========================================
  // MÉTODOS DE INVENTÁRIO (SINCRO)
  // ==========================================

  static Future<Map<String, dynamic>?> getItem(String itemCode) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) return null;

    try {
      final client = await _getClient();
      final response = await client.get(
        Uri.parse(
          "$baseUrl/Items('$itemCode')?\$select=ItemCode,ItemName,BarCode",
        ),
        headers: {"Cookie": "B1SESSION=$session; ROUTEID=$routeId"},
      );

      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Erro ao buscar item $itemCode: $e");
    }
    return null;
  }

  /// Envia as contagens e retorna uma String? (null se sucesso, mensagem se erro)
  static Future<String?> postInventoryCounting(
    List<Map<String, dynamic>> contagens,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('sap_url');
    final session = prefs.getString('B1SESSION');
    final routeId = prefs.getString('ROUTEID');

    if (baseUrl == null || session == null) {
      return "Configuração de API ausente.";
    }

    final payload = {
      "CountDate": DateTime.now().toIso8601String().split('T')[0],
      "InventoryCountingLines": contagens.map((c) {
        return {
          "ItemCode": c['itemCode'].toString().toUpperCase(),
          "WarehouseCode": "01",
          "CountedQuantity": double.tryParse(c['quantidade'].toString()) ?? 0.0,
          "Counted": "tYES",
        };
      }).toList(),
    };

    try {
      final client = await _getClient();
      final response = await client.post(
        Uri.parse("$baseUrl/InventoryCountings"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Cookie": "B1SESSION=$session; ROUTEID=$routeId",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return null; // Sucesso
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          
          String sapMessage = errorBody['error']['message']['value'] ??
                              errorBody['error']['message'].toString();

          String itemCod = "";
          if (contagens.isNotEmpty) {
            itemCod = contagens.first['itemCode'].toString().toUpperCase();
          }

          if (sapMessage.contains("already been added")) {
            return "O item $itemCod já possui uma contagem em aberto no SAP. "
                   "Peça ao administrativo para encerrar este item antes de tentar novamente.";
          }

          return "Erro no Item $itemCod: $sapMessage";
          
        } catch (_) {
          return "Erro SAP (${response.statusCode}): ${response.body}";
        }
      }
    } catch (e) {
      print("Exceção na sincronização: $e");
      return "Falha de conexão com o servidor.";
    }
  }
}