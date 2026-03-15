import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

class ExportService {
  // Delimitador padrão brasileiro — compatível com Excel PT-BR
  static const _delimitador = ';';

  /// Escapa um campo CSV: envolve em aspas duplas se contiver
  /// o delimitador, quebra de linha ou aspas duplas.
  static String _escapar(String valor) {
    if (valor.contains(_delimitador) ||
        valor.contains('"') ||
        valor.contains('\n') ||
        valor.contains('\r')) {
      // Dobra aspas duplas internas (padrão RFC 4180)
      return '"${valor.replaceAll('"', '""')}"';
    }
    return valor;
  }

  /// Converte uma lista de listas em string CSV sem dependência externa.
  static String _converterCSV(List<List<String>> linhas) {
    return linhas
        .map((linha) => linha.map(_escapar).join(_delimitador))
        .join('\r\n'); // CRLF — padrão RFC 4180 / Excel
  }

  static Future<void> exportarContagensParaCSV(
    List<Map<String, dynamic>> contagens,
  ) async {
    try {
      final List<List<String>> linhas = [];

      // Cabeçalho
      linhas.add([
        'Código do Item',
        'Quantidade',
        'Depósito',
        'Data e Hora',
        'Status de Sincronização',
      ]);

      for (var c in contagens) {
        // Data/hora — ISO 8601 → DD/MM/YYYY HH:MM:SS
        String dataHoraRaw = c['dataHora'] ?? '';
        String dataFormatada = dataHoraRaw;
        if (dataHoraRaw.length >= 19) {
          try {
            final dt = DateTime.parse(dataHoraRaw);
            dataFormatada =
                '${dt.day.toString().padLeft(2, '0')}/'
                '${dt.month.toString().padLeft(2, '0')}/'
                '${dt.year} '
                '${dt.hour.toString().padLeft(2, '0')}:'
                '${dt.minute.toString().padLeft(2, '0')}:'
                '${dt.second.toString().padLeft(2, '0')}';
          } catch (_) {}
        }

        // Quantidade — troca ponto por vírgula (padrão PT-BR no Excel)
        final quantidadeFormatada =
            (c['quantidade']?.toString() ?? '0').replaceAll('.', ',');

        // Status de sincronização
        final syncStatus = c['syncStatus'] ?? 0;
        final statusText = switch (syncStatus) {
          1 => 'Sincronizado',
          2 => 'Erro no Envio',
          _ => 'Pendente',
        };

        // Depósito — fallback para '01' em dados antigos
        String deposito = c['warehouseCode']?.toString().trim() ?? '01';
        if (deposito.isEmpty) deposito = '01';

        linhas.add([
          c['itemCode']?.toString() ?? '',
          quantidadeFormatada,
          deposito,
          dataFormatada,
          statusText,
        ]);
      }

      final csvData = _converterCSV(linhas);

      // BOM UTF-8 — garante que o Excel reconheça acentos automaticamente
      const utf8BOM = '\uFEFF';
      final csvComBOM = utf8BOM + csvData;

      final directory = await getTemporaryDirectory();
      final agora = DateTime.now();
      final dataStr =
          '${agora.year}'
          '${agora.month.toString().padLeft(2, '0')}'
          '${agora.day.toString().padLeft(2, '0')}'
          '_${agora.hour.toString().padLeft(2, '0')}'
          '${agora.minute.toString().padLeft(2, '0')}';

      final path = '${directory.path}/Relatorio_STOX_$dataStr.csv';
      final file = File(path);
      await file.writeAsString(csvComBOM, encoding: utf8);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv')],
        text: 'Relatório de Contagem Offline - STOX',
        subject: 'Relatório STOX - $dataStr',
      );
    } catch (e) {
      debugPrint('Erro na exportação do CSV: $e');
      rethrow;
    }
  }
}