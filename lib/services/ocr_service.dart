import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';

class OcrService {
  static final ImagePicker _picker = ImagePicker();

  static Future<Map<String, String>?> lerAnotacaoDaCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image == null) return null;

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      String textoBruto = recognizedText.text.trim();
      
      // Lógica para separar Código e Quantidade
      // Aqui tentamos quebrar o texto por espaços ou linhas
      List<String> partes = textoBruto.split(RegExp(r'\s+'));
      
      String itemCode = "";
      String quantidade = "";

      if (partes.isNotEmpty) {
        itemCode = partes[0]; // Assume que a primeira palavra é o código
        if (partes.length > 1) {
          // Se houver mais palavras, tenta ver se a última é um número (quantidade)
          String ultimaParte = partes.last.replaceAll(',', '.');
          if (RegExp(r'^\d+(\.\d+)?$').hasMatch(ultimaParte)) {
            quantidade = ultimaParte;
          partes.removeLast();
          itemCode = partes.join(" "); // O resto vira o código
          } else {
            itemCode = partes.join(" ");
          }
        }
      }

      // Retorna o Mapa que a sua ContadorOfflinePage espera
      return {
        'itemCode': itemCode,
        'quantidade': quantidade,
      };
    } catch (e) {
      debugPrint("Erro no OCR: $e");
      return null;
    }
  }

  static Future<String?> extractText({required ImageSource source}) async {
    final image = await _picker.pickImage(source: source);
    if (image == null) return null;
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(InputImage.fromFilePath(image.path));
    await textRecognizer.close();
    return recognizedText.text;
  }
}