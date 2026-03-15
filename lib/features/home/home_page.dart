import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../../db/database_helper.dart';
import '../../services/sap_service.dart';
import '../auth/login_page.dart';
import '../contador/contador_offline_page.dart';
import '../config/api_config_page.dart';
import '../consultas/item_search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _contagensOffline = [];
  bool _carregando = false;
  String _nomeOperador = 'Operador...';
  final AudioPlayer _audio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  // ─── FEEDBACK ──────────────────────────────────────────────────────────────

  Future<void> _play(String asset, {bool isError = false, bool isFail = false}) async {
    try {
      if (await Vibration.hasVibrator()) {
        if (isFail) {
          Vibration.vibrate(pattern: [0, 400, 100, 400]);
        } else if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 300]);
        } else {
          Vibration.vibrate(duration: 300);
        }
      } else {
        if (isFail || isError) { HapticFeedback.vibrate(); }
        else { HapticFeedback.heavyImpact(); }
      }
      await _audio.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Feedback error: $e');
    }
  }

  // ─── DADOS ─────────────────────────────────────────────────────────────────

  Future<void> _carregarDadosIniciais() async {
    await Future.wait([_carregarDadosLocais(), _carregarUsuario()]);
  }

  Future<void> _carregarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nomeOperador = prefs.getString('UserName') ?? 'Operador STOX';
      });
    }
  }

  Future<void> _carregarDadosLocais() async {
    final dados = await DatabaseHelper.instance.buscarContagens();
    if (mounted) setState(() => _contagensOffline = dados);
  }

  // ─── SINCRONIZAÇÃO ──────────────────────────────────────────────────────────

  Future<void> _sincronizarComSAP() async {
    if (_contagensOffline.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() => _carregando = true);

    try {
      final erro = await SapService.postInventoryCounting(_contagensOffline);

      if (erro == null) {
        // ✅ Sucesso
        await _play('sounds/check.mp3');
        await DatabaseHelper.instance.limparContagens();
        await _carregarDadosLocais();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Sincronização concluída com sucesso!',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      } else {
        // ❌ Erro SAP
        await _play('sounds/fail.mp3', isFail: true);
        if (!mounted) return;
        _exibirErroSap(erro);
      }
    } catch (e) {
      // ❌ Sem conexão
      await _play('sounds/fail.mp3', isFail: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text('Sem conexão com o servidor SAP. Tente novamente.',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ─── ERROS SAP ──────────────────────────────────────────────────────────────

  _ErroSap _interpretarErroSap(String mensagemBruta) {
    final msg = mensagemBruta.toUpperCase();

    // Sempre trunca para exibir no detalhe técnico
    final tecnico = mensagemBruta.length > 300
        ? '${mensagemBruta.substring(0, 300)}...'
        : mensagemBruta;

    // Tenta identificar qual item da lista causou o erro
    String itemEncontrado     = '';
    String depositoEncontrado = '';
    for (var c in _contagensOffline) {
      final codigo   = c['itemCode'].toString().trim().toUpperCase();
      final deposito = c['warehouseCode']?.toString().trim() ?? '';
      if (msg.contains(codigo)) {
        itemEncontrado     = c['itemCode'].toString().trim();
        depositoEncontrado = deposito;
        break;
      }
    }

    // ── Contagem já aberta ──────────────────────────────────────────────────
    if (mensagemBruta.contains('-1310') ||
        mensagemBruta.contains('1470000497') ||
        msg.contains('ALREADY')) {
      return _ErroSap(
        icone: Icons.lock_clock_rounded,
        cor: Colors.orange.shade700,
        titulo: 'Contagem já aberta no SAP',
        mensagem: itemEncontrado.isNotEmpty
            ? 'O item "$itemEncontrado" já possui uma contagem de inventário aberta e não finalizada no SAP Business One.'
            : 'Um dos itens já possui uma contagem de inventário aberta e não finalizada no SAP.',
        orientacao:
            'Acesse o SAP Business One → Estoque → Contagem de Estoque, finalize ou cancele a contagem existente e sincronize novamente.',
        codigoTecnico: tecnico,
      );
    }

    // ── Sessão expirada ──────────────────────────────────────────────────────
    if (msg.contains('SESSION') ||
        msg.contains('401') ||
        msg.contains('UNAUTHORIZED')) {
      return _ErroSap(
        icone: Icons.lock_rounded,
        cor: Colors.red.shade700,
        titulo: 'Sessão expirada',
        mensagem: 'Sua sessão no SAP Business One expirou.',
        orientacao:
            'Faça login novamente para continuar. Seus dados de contagem estão salvos.',
        codigoTecnico: tecnico,
      );
    }

    // ── Falha de conexão ─────────────────────────────────────────────────────
    if (msg.contains('TIMEOUT') ||
        msg.contains('CONNECTION') ||
        msg.contains('SOCKET')) {
      return _ErroSap(
        icone: Icons.wifi_off_rounded,
        cor: Colors.red.shade700,
        titulo: 'Falha de comunicação',
        mensagem: 'Não foi possível conectar ao servidor SAP Business One.',
        orientacao:
            'Verifique se você está conectado à rede corporativa e se o servidor SAP está acessível.',
      );
    }

    // ── Classificação por conteúdo ───────────────────────────────────────────
    // Estratégia: pontuar qual erro é mais provável pelo conteúdo da mensagem.
    // Isso evita que "WAREHOUSE" dentro de uma mensagem de item cause
    // classificação errada — o erro com mais pontos vence.

    int pontoItem      = 0;
    int pontoDeposito  = 0;

    // Sinais fortes de item inexistente
    if (msg.contains('-4002'))                             pontoItem += 10;
    if (msg.contains('ITEM NOT FOUND'))                    pontoItem += 8;
    if (msg.contains('INVALID ITEM'))                      pontoItem += 8;
    if (msg.contains('ITEM') && msg.contains('NOT EXIST')) pontoItem += 7;
    if (msg.contains('ITEM') && msg.contains('NOT FOUND')) pontoItem += 6;
    if (msg.contains('ITEM') && msg.contains('INVALID'))   pontoItem += 5;
    if (msg.contains('ITEM CODE'))                         pontoItem += 4;
    if (msg.contains('ITEM') && msg.contains('UNKNOWN'))   pontoItem += 4;
    // Se o código do item da contagem aparece na mensagem de erro, é item
    if (itemEncontrado.isNotEmpty)                         pontoItem += 3;

    // Sinais fortes de depósito inválido
    if (msg.contains('-5002'))                                         pontoDeposito += 10;
    if (msg.contains('WAREHOUSE NOT FOUND'))                           pontoDeposito += 8;
    if (msg.contains('INVALID WAREHOUSE'))                             pontoDeposito += 8;
    if (msg.contains('WAREHOUSE') && msg.contains('NOT FOUND'))        pontoDeposito += 6;
    if (msg.contains('WAREHOUSE') && msg.contains('INVALID'))          pontoDeposito += 5;
    if (msg.contains('WAREHOUSECODE') && msg.contains('NOT FOUND'))    pontoDeposito += 6;
    // WAREHOUSE sozinho, sem NOT FOUND/INVALID, é sinal fraco
    if (msg.contains('WAREHOUSE') && pontoDeposito == 0)               pontoDeposito += 1;

    if (pontoItem > pontoDeposito && pontoItem > 0) {
      return _ErroSap(
        icone: Icons.inventory_2_rounded,
        cor: Colors.orange.shade700,
        titulo: 'Item não encontrado no SAP',
        mensagem: itemEncontrado.isNotEmpty
            ? 'O item "$itemEncontrado" não existe no cadastro do SAP Business One. O código digitado pode estar incorreto.'
            : 'Um dos itens da contagem não existe no cadastro do SAP Business One.',
        orientacao:
            'Corrija o código do item na tela de contagem e sincronize novamente. Para confirmar, busque o item em SAP Business One → Estoque → Dados do Item.',
        codigoTecnico: tecnico,
      );
    }

    if (pontoDeposito > pontoItem && pontoDeposito > 1) {
      return _ErroSap(
        icone: Icons.warning_amber_rounded,
        cor: Colors.orange.shade700,
        titulo: 'Erro ao enviar contagem',
        mensagem: depositoEncontrado.isNotEmpty
            ? 'O SAP recusou o item "$depositoEncontrado". Confirme se o código do item foi digitado corretamente e se o depósito está configurado certo.'
            : 'O SAP recusou um ou mais itens da contagem. Confirme se os códigos dos itens foram digitados corretamente e se o depósito está configurado certo.',
        orientacao:
            'Verifique o retorno do SAP abaixo para identificar a causa exata. Corrija o problema e sincronize novamente.',
        codigoTecnico: tecnico,
      );
    }

    // ── Fallback genérico ────────────────────────────────────────────────────
    return _ErroSap(
      icone: Icons.error_outline_rounded,
      cor: Colors.red.shade700,
      titulo: 'Erro na sincronização',
      mensagem: itemEncontrado.isNotEmpty
          ? 'Ocorreu um erro ao processar o item "$itemEncontrado". Veja o detalhe técnico abaixo.'
          : 'Ocorreu um erro ao enviar os dados para o SAP Business One. Veja o detalhe técnico abaixo.',
      orientacao:
          'Anote a mensagem de erro abaixo e entre em contato com o administrador do SAP caso o problema persista.',
      codigoTecnico: tecnico,
    );
  }

  void _exibirErroSap(String mensagemBruta) {
    final erro = _interpretarErroSap(mensagemBruta);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: erro.cor.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(erro.icone, color: erro.cor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(erro.titulo,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900)),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(erro.mensagem,
                    style: const TextStyle(fontSize: 14, height: 1.5)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(erro.orientacao,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade800,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
                if (erro.codigoTecnico != null) ...[
                  const SizedBox(height: 12),
                  // Detalhe técnico sempre visível — ajuda a diagnosticar
                  // erros que a classificação automática pode errar
                  Text('Retorno do SAP:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      erro.codigoTecnico!,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.blueGrey.shade700,
                          height: 1.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            if (erro.titulo.contains('Depósito'))
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ApiConfigPage()));
                },
                child: Text('IR PARA CONFIGURAÇÕES',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600)),
              ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                if (erro.titulo.contains('expirada')) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (r) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: erro.cor,
                foregroundColor: Colors.white,
                minimumSize: const Size(100, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                  erro.titulo.contains('expirada') ? 'FAZER LOGIN' : 'ENTENDIDO',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel STOX',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              _carregarDadosLocais();
            },
            tooltip: 'Recarregar Dados',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(children: [
          _buildSummaryHeader(),
          Expanded(
            child: _contagensOffline.isEmpty
                ? _buildEmptyState()
                : _buildContagensList(),
          ),
        ]),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: theme.primaryColor.withAlpha(77),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Itens aguardando envio',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('${_contagensOffline.length}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _carregando || _contagensOffline.isEmpty
                  ? null
                  : _sincronizarComSAP,
              icon: _carregando
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.cloud_upload_rounded),
              label: const Text('SINCRONIZAR AGORA',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContagensList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
      itemCount: _contagensOffline.length,
      itemBuilder: (context, index) {
        final item    = _contagensOffline[index];
        final deposito = item['warehouseCode'] ?? '01';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).primaryColor.withAlpha(26),
              radius: 22,
              child: Icon(Icons.inventory_2_rounded,
                  color: Theme.of(context).primaryColor, size: 22),
            ),
            title: Text('${item['itemCode']}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Qtd: ${item['quantidade']}  •  Dep: $deposito',
                  style: TextStyle(color: Colors.grey.shade700)),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade400),
              onPressed: () async {
                HapticFeedback.vibrate();
                await DatabaseHelper.instance.excluirContagem(item['id']);
                _carregarDadosLocais();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(Icons.cloud_done_rounded,
                size: 64, color: Colors.green.shade400),
          ),
          const SizedBox(height: 24),
          Text('Tudo sincronizado!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          Text('Não há contagens pendentes para envio.',
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final theme = Theme.of(context);
    return Drawer(
      child: Column(children: [
        UserAccountsDrawerHeader(
          decoration: BoxDecoration(color: theme.primaryColor),
          currentAccountPicture: const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.person_rounded, size: 40, color: Colors.grey),
          ),
          accountName: Text(_nomeOperador,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          accountEmail: const Row(children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
            SizedBox(width: 6),
            Text('SAP Business One Conectado'),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ListTile(
                leading: Icon(Icons.add_box_rounded,
                    color: theme.primaryColor),
                title: const Text('Nova Contagem Offline',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ContadorOfflinePage()),
                  ).then((_) => _carregarDadosLocais());
                },
              ),
              ListTile(
                leading: Icon(Icons.search_rounded,
                    color: theme.primaryColor),
                title: const Text('Pesquisar Item SAP',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ItemSearchPage()),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(),
              ),
              ListTile(
                leading: Icon(Icons.settings_rounded,
                    color: Colors.grey.shade600),
                title: Text('Configurações da API',
                    style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500)),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ApiConfigPage()),
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: Colors.red),
          title: const Text('Sair da Conta',
              style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold)),
          onTap: () async {
            HapticFeedback.heavyImpact();
            await SapService.logout();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (r) => false,
            );
          },
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ─── MODELO DE ERRO AMIGÁVEL ──────────────────────────────────────────────────

class _ErroSap {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String mensagem;
  final String orientacao;
  final String? codigoTecnico;

  const _ErroSap({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.mensagem,
    required this.orientacao,
    this.codigoTecnico,
  });
}