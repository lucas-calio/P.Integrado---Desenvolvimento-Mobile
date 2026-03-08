import 'package:flutter/material.dart';
import '../../services/sap_service.dart';

class ItemSearchPage extends StatefulWidget {
  const ItemSearchPage({super.key});

  @override
  State<ItemSearchPage> createState() => _ItemSearchPageState();
}

class _ItemSearchPageState extends State<ItemSearchPage> {
  final _searchController = TextEditingController();
  Map<String, dynamic>? _itemData;
  bool _loading = false;
  final Color primaryColor = const Color(0xFF0A6ED1);

  Future<void> _buscar() async {
    if (_searchController.text.isEmpty) return;
    setState(() { _loading = true; _itemData = null; });

    final data = await SapService.getDetailedItem(_searchController.text.trim().toUpperCase());
    
    setState(() { _itemData = data; _loading = false; });

    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item não encontrado ou erro de conexão."), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Consultar Item SAP")),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())),
          if (_itemData != null) _buildResultList(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Código do Item (ex: P001)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => _buscar(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: _buscar,
            icon: const Icon(Icons.arrow_forward),
            style: IconButton.styleFrom(backgroundColor: primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildHeaderCard(),
          _buildStatusFlags(),
          _buildSectionTitle("Estoque por Depósito"),
          _buildWarehouseInfo(),
          _buildSectionTitle("Dados Comerciais"),
          _buildDetailRow("Fornecedor Padrão", _itemData!['CardCode'] ?? "N/A"),
          _buildDetailRow("Unidade de Compra", _itemData!['PurchaseUnit'] ?? "N/A"),
          _buildDetailRow("Unidade de Venda", _itemData!['SalesUnit'] ?? "N/A"),
          _buildDetailRow("Embalagem Venda", _itemData!['SalesPackUnit'] ?? "N/A"),
          _buildDetailRow("Item Bloqueado", _itemData!['Frozen'] == "tYES" ? "SIM" : "NÃO", isAlert: _itemData!['Frozen'] == "tYES"),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      color: primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_itemData!['ItemCode'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_itemData!['ItemName'], style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFlags() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statusChip(Icons.inventory_2, "Estoque", _itemData!['InventoryItem'] == 'tYES'),
          _statusChip(Icons.sell, "Venda", _itemData!['SalesItem'] == 'tYES'),
          _statusChip(Icons.local_shipping, "Compra", _itemData!['PurchaseItem'] == 'tYES'),
        ],
      ),
    );
  }

  Widget _statusChip(IconData icon, String label, bool active) {
    return Column(
      children: [
        Icon(icon, color: active ? Colors.green : Colors.grey.shade300),
        Text(label, style: TextStyle(color: active ? Colors.black87 : Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildWarehouseInfo() {
    final list = (_itemData!['ItemWarehouseInfoCollection'] as List? ?? []);
    // Filtra apenas depósitos com estoque para facilitar a vida do operador
    final warehousesWithStock = list.where((wh) => (wh['InStock'] ?? 0) > 0).toList();

    if (warehousesWithStock.isEmpty) {
      return const Text("Sem estoque disponível em nenhum depósito.", style: TextStyle(color: Colors.grey));
    }

    return Column(
      children: warehousesWithStock.map((wh) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: const Icon(Icons.warehouse, color: Colors.blueGrey),
            title: Text("Depósito ${wh['WarehouseCode']}"),
            trailing: Text("${wh['InStock']} ${_itemData!['InventoryUOM'] ?? ''}", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isAlert ? Colors.red : Colors.black87)),
        ],
      ),
    );
  }
}