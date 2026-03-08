import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('stox_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE contagens (
        id $idType,
        itemCode $textType,
        quantidade $realType,
        dataHora $textType
      )
    ''');
  }

  Future<int> inserirContagem(String itemCode, double quantidade) async {
    final db = await instance.database;
    final data = {
      'itemCode': itemCode,
      'quantidade': quantidade,
      'dataHora': DateTime.now().toIso8601String(),
    };
    return await db.insert('contagens', data);
  }

  // --- NOVOS MÉTODOS ADICIONADOS ABAIXO ---

  // 1. Método para ATUALIZAR (Editar)
  Future<int> atualizarContagem(int id, double novaQuantidade) async {
    final db = await instance.database;
    return await db.update(
      'contagens',
      {'quantidade': novaQuantidade},
      where: 'id = ?', // Filtro por ID para não atualizar a tabela toda
      whereArgs: [id],
    );
  }

  // 2. Método para EXCLUIR um item específico
  Future<int> excluirContagem(int id) async {
    final db = await instance.database;
    return await db.delete(
      'contagens',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 3. Método para somar tudo (Útil para o resumo do SAP depois)
  Future<double> calcularTotalPorItem(String itemCode) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(quantidade) as total FROM contagens WHERE itemCode = ?',
      [itemCode]
    );
    return result.first['total'] as double? ?? 0.0;
  }

  // --- MÉTODOS QUE VOCÊ JÁ TINHA ---

  Future<List<Map<String, dynamic>>> buscarContagens() async {
    final db = await instance.database;
    return await db.query('contagens', orderBy: 'dataHora DESC');
  }

  Future<void> limparContagens() async {
    final db = await instance.database;
    await db.delete('contagens');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}