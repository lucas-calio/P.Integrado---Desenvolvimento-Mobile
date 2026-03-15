import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

import '../../services/sap_service.dart';
import '../../services/ocr_service.dart';
import 'etiqueta_page.dart';

class ItemSearchPage extends StatefulWidget {
  const ItemSearchPage({super.key});

  @override
  State<ItemSearchPage> createState() => _ItemSearchPageState();
}

class _ItemSearchPageState extends State<ItemSearchPage> {
  final _searchController = TextEditingController();
  final AudioPlayer _audio = AudioPlayer();

  Timer? _debounceTimer;
  Map<String, dynamic>? _itemData;
  List<dynamic> _searchResults = [];

  bool _loading          = false;
  bool _scannerProcessando = false;

  bool _modoSelecao = false;
  final Set<String>                      _selecionados     = {};
  final Map<String, Map<String, dynamic>> _itensSelecionados = {};

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _audio.dispose();
    super.dispose();
  }

  // ─── FEEDBACK ────────────────────────────────────────────────────────────

  Future<void> _play(String asset, {bool isError = false, bool isFail = false}) async {
    try {
      if (await Vibration.hasVibrator()) {
        if (isFail) {
          Vibration.vibrate(pattern: [0, 400, 100, 400]);
        } else if (isError) {
          Vibration.vibrate(pattern: [0, 200, 100, 300]);
        } else {
          Vibration.vibrate(duration: 100);
        }
      } else {
        if (isFail || isError) { HapticFeedback.vibrate(); }
        else {
          HapticFeedback.lightImpact();
        }
      }
      await _audio.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Feedback error: $e');
    }
  }

  // ─── SELEÇÃO MÚLTIPLA ─────────────────────────────────────────────────────

  void _entrarModoSelecao(Map<String, dynamic> item) {
    HapticFeedback.mediumImpact();
    final code = item['ItemCode'] as String;
    setState(() {
      _modoSelecao = true;
      _selecionados.add(code);
      _itensSelecionados[code] = Map<String, dynamic>.from(item);
    });
  }

  void _sairModoSelecao() {
    HapticFeedback.selectionClick();
    setState(() {
      _modoSelecao = false;
      _selecionados.clear();
      _itensSelecionados.clear();
    });
  }

  void _toggleSelecao(Map<String, dynamic> item) {
    HapticFeedback.selectionClick();
    final code = item['ItemCode'] as String;
    setState(() {
      if (_selecionados.contains(code)) {
        _selecionados.remove(code);
        _itensSelecionados.remove(code);
        if (_selecionados.isEmpty) _modoSelecao = false;
      } else {
        _selecionados.add(code);
        _itensSelecionados[code] = Map<String, dynamic>.from(item);
      }
    });
  }

  void _selecionarTodos() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selecionados.length == _searchResults.length) {
        _selecionados.clear();
        _itensSelecionados.clear();
        _modoSelecao = false;
      } else {
        for (final item in _searchResults) {
          final m    = item as Map<String, dynamic>;
          final code = m['ItemCode'] as String;
          _selecionados.add(code);
          _itensSelecionados[code] = Map<String, dynamic>.from(m);
        }
      }
    });
  }

  void _imprimirLote() {
    if (_selecionados.isEmpty) return;
    HapticFeedback.lightImpact();
    final itens = _itensSelecionados.values.toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EtiquetaPage(
          itemData:  itens.first,
          deposito:  itens.first['_deposito']?.toString() ?? '01',
          itenslote: itens,
        ),
      ),
    );
  }

  // ─── BUSCA ────────────────────────────────────────────────────────────────

  Future<void> _buscar({bool autoSearch = false}) async {
    final termo = _searchController.text.trim();
    if (termo.isEmpty) {
      if (!autoSearch) HapticFeedback.selectionClick();
      return;
    }
    if (!autoSearch) {
      FocusScope.of(context).unfocus();
      HapticFeedback.lightImpact();
    }
    if (_modoSelecao) _sairModoSelecao();
    setState(() {
      _loading      = true;
      _itemData     = null;
      _searchResults = [];
    });
    try {
      final results = await SapService.searchItems(termo);
      if (mounted) {
        setState(() {
          _loading = false;
          if (results.length == 1) {
            FocusScope.of(context).unfocus();
            _carregarDetalhes(results.first['ItemCode']);
          } else {
            _searchResults = results;
            if (results.isNotEmpty && !autoSearch) {
              HapticFeedback.selectionClick();
            }
          }
        });
      }
      if (results.isEmpty && !autoSearch) {
        await _play('sounds/error_beep.mp3', isError: true);
        _mostrarAviso("Nenhum item encontrado para '$termo'.");
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (!autoSearch) {
        await _play('sounds/fail.mp3', isFail: true);
        _mostrarErro('Erro na busca: $e');
      }
    }
  }

  Future<void> _carregarDetalhes(String itemCode) async {
    setState(() => _loading = true);
    try {
      final data = await SapService.getDetailedItem(itemCode);
      if (mounted) {
        setState(() {
          _itemData      = data;
          _searchResults = [];
          _loading       = false;
        });
        // Detalhe carregado → beep suave
        await _play('sounds/beep.mp3');
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      await _play('sounds/fail.mp3', isFail: true);
      _mostrarErro('Erro ao carregar detalhes do item.');
    }
  }

  Future<void> _escanearTextoIA() async {
    HapticFeedback.mediumImpact();
    final resultado = await OcrService.lerAnotacaoDaCamera();
    if (resultado != null &&
        resultado['itemCode'] != null &&
        resultado['itemCode']!.isNotEmpty) {
      setState(() => _searchController.text = resultado['itemCode']!);
      // OCR bem sucedido → beep
      await _play('sounds/beep.mp3');
      _buscar();
    } else {
      await _play('sounds/error_beep.mp3', isError: true);
      _mostrarAviso('Nenhum código reconhecido pela câmera.');
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  void _mostrarAviso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
      backgroundColor: Colors.orange.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  void _abrirScanner() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    _scannerProcessando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LayoutBuilder(builder: (context, constraints) {
        final scanWindow = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, 200),
          width: 280, height: 180,
        );
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(children: [
              const SizedBox(height: 12),
              Container(
                width: 48, height: 6,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10)),
              ),
              AppBar(
                title: const Text('Escanear Código',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.black87,
                elevation: 0,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MobileScanner(
                      scanWindow: scanWindow,
                      onDetect: (capture) async {
                        if (_scannerProcessando) return;
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final code = barcodes.first.rawValue ?? '';
                          if (code.isEmpty) return;
                          _scannerProcessando = true;
                          // Leitura de código → beep.mp3
                          await _play('sounds/beep.mp3');
                          if (!mounted) return;
                          _searchController.text = code;
                          // ignore: use_build_context_synchronously
                          Navigator.of(context).pop();
                          _buscar();
                        }
                      },
                    ),
                  ),
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                        Colors.black.withAlpha(179), BlendMode.srcOut),
                    child: Stack(children: [
                      Container(
                          decoration: const BoxDecoration(
                              color: Colors.black,
                              backgroundBlendMode: BlendMode.dstOut)),
                      Center(
                        child: Container(
                          width: scanWindow.width,
                          height: scanWindow.height,
                          decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ]),
                  ),
                  Center(
                    child: Container(
                      width: scanWindow.width,
                      height: scanWindow.height,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context).primaryColor, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ]),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Alinhe o código de barras dentro do quadro'),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_modoSelecao,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _modoSelecao) _sairModoSelecao();
      },
      child: Scaffold(
        appBar: _modoSelecao
            ? _buildAppBarSelecao(theme)
            : AppBar(title: const Text('Consultar Item')),
        body: SafeArea(
          child: Column(children: [
            if (!_modoSelecao) _buildSearchBar(),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (!_loading && _searchResults.isNotEmpty) _buildSearchSuggestions(),
            if (!_loading && _itemData != null) _buildResultList(),
            if (!_loading && _itemData == null && _searchResults.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Busque por código, nome ou use a IA.',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
          ]),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _modoSelecao && _selecionados.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _imprimirLote,
                    icon: const Icon(Icons.print_rounded),
                    label: Text(
                      'Imprimir ${_selecionados.length} ${_selecionados.length == 1 ? "etiqueta" : "etiquetas"}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  AppBar _buildAppBarSelecao(ThemeData theme) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _sairModoSelecao,
        tooltip: 'Cancelar seleção',
      ),
      title: Text(
          '${_selecionados.length} selecionado${_selecionados.length != 1 ? "s" : ""}'),
      actions: [
        TextButton(
          onPressed: _selecionarTodos,
          child: Text(
            _selecionados.length == _searchResults.length
                ? 'Desmarcar todos'
                : 'Selecionar todos',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _buscar(),
            onTap: () => HapticFeedback.selectionClick(),
            onChanged: (value) {
              if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 600), () {
                if (value.trim().isNotEmpty) _buscar(autoSearch: true);
              });
            },
            decoration: InputDecoration(
              hintText: 'Código ou Nome',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.auto_awesome,
                        color: Colors.blueAccent),
                    tooltip: 'Ler texto com IA',
                    onPressed: _escanearTextoIA,
                  ),
                  IconButton(
                    icon: Icon(Icons.qr_code_scanner_rounded,
                        color: theme.primaryColor),
                    tooltip: 'Escanear código de barras',
                    onPressed: _abrirScanner,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 56, width: 56,
          child: ElevatedButton(
            onPressed: () => _buscar(),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Icon(Icons.arrow_forward_rounded),
          ),
        ),
      ]),
    );
  }

  Widget _buildSearchSuggestions() {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(children: [
        if (!_modoSelecao)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              Icon(Icons.touch_app_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text('Segure um item para selecionar e imprimir em lote',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
          ),
        if (_modoSelecao)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.primaryColor.withAlpha(40)),
            ),
            child: Row(children: [
              Icon(Icons.print_rounded, color: theme.primaryColor, size: 16),
              const SizedBox(width: 8),
              Text('Selecione os itens para imprimir etiquetas em lote.',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: _searchResults.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item       = _searchResults[index] as Map<String, dynamic>;
              final code       = item['ItemCode'] as String;
              final selecionado = _selecionados.contains(code);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selecionado
                        ? theme.primaryColor
                        : Colors.grey.shade300,
                    width: selecionado ? 2 : 1,
                  ),
                  color: selecionado
                      ? theme.primaryColor.withAlpha(12)
                      : Colors.white,
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: _modoSelecao
                      ? Checkbox(
                          value: selecionado,
                          onChanged: (_) => _toggleSelecao(item),
                          activeColor: theme.primaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        )
                      : CircleAvatar(
                          backgroundColor: theme.primaryColor.withAlpha(20),
                          child: Icon(Icons.inventory_2_outlined,
                              color: theme.primaryColor, size: 18),
                        ),
                  title: Text(item['ItemName'] ?? '',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selecionado
                              ? theme.primaryColor
                              : Colors.black87)),
                  subtitle: Text(code,
                      style: TextStyle(color: Colors.grey.shade600)),
                  trailing: _modoSelecao
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.print_rounded,
                                  color: theme.primaryColor),
                              tooltip: 'Imprimir etiqueta',
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EtiquetaPage(
                                      itemData: Map<String, dynamic>.from(item),
                                      deposito: '01',
                                    ),
                                  ),
                                );
                              },
                            ),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: Colors.grey.shade400),
                          ],
                        ),
                  onTap: _modoSelecao
                      ? () => _toggleSelecao(item)
                      : () => _carregarDetalhes(code),
                  onLongPress: _modoSelecao
                      ? null
                      : () => _entrarModoSelecao(item),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildResultList() {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          _buildStatusFlags(),
          _buildSectionTitle('Estoque por Depósito'),
          _buildWarehouseInfo(),
          _buildSectionTitle('Informações Adicionais'),
          _buildDetailRow('Unidade de Medida', _itemData!['InventoryUOM'] ?? 'UN'),
          _buildDetailRow('Item Bloqueado',
              _itemData!['Frozen'] == 'tYES' ? 'SIM' : 'NÃO',
              isAlert: _itemData!['Frozen'] == 'tYES'),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: theme.primaryColor,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_itemData!['ItemCode'] ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_itemData!['ItemName'] ?? '',
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildStatusFlags() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Wrap(
        spacing: 12,
        children: [
          _statusChip('Estoque', _itemData!['InventoryItem'] == 'tYES'),
          _statusChip('Venda',   _itemData!['SalesItem']     == 'tYES'),
          _statusChip('Compra',  _itemData!['PurchaseItem']  == 'tYES'),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool active) {
    return Chip(
      label: Text(label),
      backgroundColor: active ? Colors.green.shade50 : Colors.grey.shade100,
      avatar: Icon(active ? Icons.check_circle : Icons.cancel,
          size: 16, color: active ? Colors.green : Colors.grey),
    );
  }

  Widget _buildWarehouseInfo() {
    final list       = (_itemData!['ItemWarehouseInfoCollection'] as List? ?? []);
    final warehouses = list.where((wh) => (wh['InStock'] ?? 0) > 0).toList();
    if (warehouses.isEmpty) {
      return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Sem estoque disponível.'));
    }
    return Column(
      children: warehouses.map((wh) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.warehouse),
            title:    Text("Depósito ${wh['WarehouseCode']}"),
            subtitle: Text("Disponível: ${wh['InStock']}"),
            trailing: IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Imprimir etiqueta para este depósito',
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EtiquetaPage(
                      itemData: _itemData!,
                      deposito: wh['WarehouseCode'].toString(),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAlert = false}) {
    return ListTile(
      title: Text(label),
      trailing: Text(value,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isAlert ? Colors.red : Colors.black)),
    );
  }
}