import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfigPage extends StatefulWidget {
  const ApiConfigPage({super.key});

  @override
  State<ApiConfigPage> createState() => _ApiConfigPageState();
}

class _ApiConfigPageState extends State<ApiConfigPage> {
  final _urlController = TextEditingController();
  final _companyController = TextEditingController();
  bool _permitirSslInseguro = true; // Estado do switch (deslizar)
  final Color primaryColor = const Color(0xFF0A6ED1);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text = prefs.getString('sap_url') ?? '';
      _companyController.text = prefs.getString('sap_company') ?? '';
      // Se não houver nada salvo, o padrão será true (permitir certificados pré-assinados)
      _permitirSslInseguro = prefs.getBool('sap_allow_untrusted') ?? true;
    });
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sap_url', _urlController.text);
    await prefs.setString('sap_company', _companyController.text);
    await prefs.setBool('sap_allow_untrusted', _permitirSslInseguro);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Configurações salvas!"),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuração SAP"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Conexão Service Layer",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            const Text("Ajuste os endereços para sincronização com o SAP.",
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 30),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: "Service Layer URL",
                hintText: "https://servidor:50000/b1s/v1",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _companyController,
              decoration: InputDecoration(
                labelText: "CompanyDB",
                hintText: "SBODemoBR",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 25),
            
            // --- NOVO BOTÃO DE DESLIZAR (SWITCH) ---
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile.adaptive(
                title: const Text("Permitir SSL pré-assinado",
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                subtitle: const Text("Ative se o seu SAP não possuir um certificado SSL oficial."),
                value: _permitirSslInseguro,
                activeColor: primaryColor,
                onChanged: (bool value) {
                  setState(() {
                    _permitirSslInseguro = value;
                  });
                },
              ),
            ),
            // ---------------------------------------

            const SizedBox(height: 40),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saveConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text("SALVAR CONFIGURAÇÕES",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}