import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../../db/database_helper.dart';
import '../../services/sap_service.dart';
import '../auth/login_page.dart';
import '../contador/contador_offline_page.dart';
import '../config/api_config_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _contagensOffline = [];
  bool _carregando = false;
  final Color primaryColor = const Color(0xFF0A6ED1);
  final AudioPlayer _audioPlayer = AudioPlayer(); // Adicionado Player de Áudio

  @override
  void initState() {
    super.initState();
    _carregarDadosLocais();
  }

  Future<void> _carregarDadosLocais() async {
    final dados = await DatabaseHelper.instance.buscarContagens();
    setState(() => _contagensOffline = dados);
  }

  // Função auxiliar para tocar som e vibrar
  Future<void> _tocarFeedback(String assetPath, {bool isError = false}) async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 400]); // Vibração de Erro
        } else {
          Vibration.vibrate(duration: 300); // Vibração de Sucesso
        }
      }
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Erro ao reproduzir feedback: $e");
    }
  }

  Future<void> _sincronizarComSAP() async {
    if (_contagensOffline.isEmpty) return;
    setState(() => _carregando = true);
    
    try {
      final erro = await SapService.postInventoryCounting(_contagensOffline);

      if (erro == null) {
        // SUCESSO: Toca check.mp3
        await _tocarFeedback('sounds/check.mp3');
        
        await DatabaseHelper.instance.limparContagens();
        await _carregarDadosLocais();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronização concluída com sucesso!'), 
            backgroundColor: Colors.green
          ),
        );
      } else {
        // ERRO DO SAP: Toca fail.mp3
        await _tocarFeedback('sounds/fail.mp3', isError: true);
        
        if (!mounted) return;
        _exibirErroSap(erro);
      }
    } catch (e) {
      // ERRO DE CONEXÃO: Toca fail.mp3
      await _tocarFeedback('sounds/fail.mp3', isError: true);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro inesperado: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _exibirErroSap(String mensagem) {
    bool isItemDuplicado = mensagem.contains("1470000497") || 
                           mensagem.contains("already been added to another open document");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isItemDuplicado ? Icons.inventory_outlined : Icons.warning, 
              color: isItemDuplicado ? Colors.orange : Colors.red
            ),
            const SizedBox(width: 10),
            Text(isItemDuplicado ? "Item Bloqueado" : "Erro no SAP"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isItemDuplicado 
                ? "Não foi possível sincronizar um ou mais itens:"
                : "Ocorreu um problema na comunicação:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(mensagem),
            if (isItemDuplicado) ...[
              const SizedBox(height: 15),
              const Divider(),
              const Text(
                "Ação necessária:",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const Text("Peça ao administrativo para encerrar a contagem em aberto deste item no SAP antes de tentar novamente."),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ENTENDI"),
          ),
        ],
      ),
    );
  }

  void _mostrarAlertaConsulta(String funcionalidade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(funcionalidade),
        content: const Text("Esta função de consulta direta ao SAP será implementada para garantir segurança de leitura, sem alterar dados."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ENTENDI")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel STOX"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDadosLocais,
            tooltip: "Atualizar lista",
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: primaryColor),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Color(0xFF0A6ED1), size: 40),
              ),
              accountName: const Text("Operador STOX", style: TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: const Text("Conectado ao SAP Business One"),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text("OPERACIONAL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  ListTile(
                    leading: Icon(Icons.add_box_outlined, color: primaryColor),
                    title: const Text("Nova Contagem Offline"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ContadorOfflinePage())).then((_) => _carregarDadosLocais());
                    },
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text("CONSULTAS (SOMENTE LEITURA)", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.search, color: Colors.orange),
                    title: const Text("Pesquisar Item (Online)"),
                    subtitle: const Text("Consulta preço e estoque real"),
                    onTap: () {
                      Navigator.pop(context);
                      _mostrarAlertaConsulta("Pesquisa de Itens");
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.print, color: Colors.blueGrey),
                    title: const Text("Etiquetas Zebra"),
                    subtitle: const Text("Ver código e imprimir"),
                    onTap: () {
                      Navigator.pop(context);
                      _mostrarAlertaConsulta("Impressão de Etiquetas");
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text("Configurações API", style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ApiConfigPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Sair do App", style: TextStyle(color: Colors.red)),
              onTap: () async {
                await SapService.logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const Text("Itens aguardando envio", style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  "${_contagensOffline.length}",
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 220,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: _carregando || _contagensOffline.isEmpty ? null : _sincronizarComSAP,
                    icon: _carregando 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.cloud_upload),
                    label: const Text("SINCRONIZAR AGORA", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _contagensOffline.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _contagensOffline.length,
                    itemBuilder: (context, index) {
                      final item = _contagensOffline[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.inventory_2, color: primaryColor),
                          ),
                          title: Text("Item: ${item['itemCode']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Quantidade: ${item['quantidade']}"),
                          trailing: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Tudo em dia!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const Text("Nenhuma contagem aguardando envio.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}