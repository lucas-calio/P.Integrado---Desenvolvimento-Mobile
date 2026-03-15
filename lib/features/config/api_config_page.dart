import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class ApiConfigPage extends StatefulWidget {
  const ApiConfigPage({super.key});

  @override
  State<ApiConfigPage> createState() => _ApiConfigPageState();
}

class _ApiConfigPageState extends State<ApiConfigPage> {
  final _urlController      = TextEditingController();
  final _companyController  = TextEditingController();
  final _depositoController = TextEditingController();
  final AudioPlayer _audio  = AudioPlayer();

  bool _permitirSslInseguro = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _companyController.dispose();
    _depositoController.dispose();
    _audio.dispose();
    super.dispose();
  }

  // ─── FEEDBACK ──────────────────────────────────────────────────────────────

  Future<void> _play(String asset, {bool isError = false}) async {
    try {
      if (await Vibration.hasVibrator()) {
        if (isError) { Vibration.vibrate(pattern: [0, 200, 100, 300]); }
        else { Vibration.vibrate(duration: 120); }
      } else {
        isError ? HapticFeedback.vibrate() : HapticFeedback.heavyImpact();
      }
      await _audio.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Feedback error: $e');
    }
  }

  // ─── DADOS ─────────────────────────────────────────────────────────────────

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _urlController.text      = prefs.getString('sap_url') ?? '';
      _companyController.text  = prefs.getString('sap_company') ?? '';
      _depositoController.text = prefs.getString('sap_deposito_padrao') ?? '01';
      _permitirSslInseguro     = prefs.getBool('sap_allow_untrusted') ?? true;
    });
  }

  Future<void> _saveConfig() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    final deposito = _depositoController.text.trim();
    if (deposito.isEmpty) {
      await _play('sounds/error_beep.mp3', isError: true);
      _mostrarSnack('Informe o código do depósito padrão.',
          Colors.orange.shade700);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sap_url', _urlController.text.trim());
    await prefs.setString('sap_company', _companyController.text.trim());
    await prefs.setString('sap_deposito_padrao', deposito.toUpperCase());
    await prefs.setBool('sap_allow_untrusted', _permitirSslInseguro);

    await _play('sounds/check.mp3');
    if (!mounted) return;
    _mostrarSnack('Configurações salvas com sucesso!', Colors.green.shade700,
        isSuccess: true);
    Navigator.pop(context);
  }

  void _mostrarSnack(String msg, Color cor, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
              color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(msg,
              style: const TextStyle(fontWeight: FontWeight.bold))),
        ]),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuração SAP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Conexão Service Layer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Text('Ajuste os endereços para sincronização com o SAP Business One.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 30),

              // ── URL ──
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                onTap: () => HapticFeedback.selectionClick(),
                decoration: const InputDecoration(
                  labelText: 'Service Layer URL',
                  hintText: 'https://servidor:50000/b1s/v1',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 20),

              // ── Company ──
              TextField(
                controller: _companyController,
                textInputAction: TextInputAction.next,
                onTap: () => HapticFeedback.selectionClick(),
                decoration: const InputDecoration(
                  labelText: 'CompanyDB',
                  hintText: 'SBODemoBR',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 20),

              // ── Depósito ──
              TextField(
                controller: _depositoController,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                onTap: () => HapticFeedback.selectionClick(),
                onSubmitted: (_) => _saveConfig(),
                decoration: const InputDecoration(
                  labelText: 'Depósito Padrão',
                  hintText: '01',
                  prefixIcon: Icon(Icons.warehouse_rounded),
                  helperText:
                      'Código do depósito usado nas contagens de inventário.',
                ),
              ),
              const SizedBox(height: 25),

              // ── SSL ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SwitchListTile.adaptive(
                  title: const Text('Permitir SSL pré-assinado',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                  subtitle: Text(
                    'Ative se o servidor SAP usar certificado auto-assinado (comum em dev/test).',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  value: _permitirSslInseguro,
                  // ignore: deprecated_member_use
                  activeColor: primaryColor,
                  onChanged: (bool value) {
                    HapticFeedback.selectionClick();
                    setState(() => _permitirSslInseguro = value);
                  },
                ),
              ),

              const SizedBox(height: 40),

              ElevatedButton.icon(
                onPressed: _saveConfig,
                icon: const Icon(Icons.save_rounded),
                label: const Text('SALVAR CONFIGURAÇÕES'),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}