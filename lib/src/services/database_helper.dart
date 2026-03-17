import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Singleton de acesso ao banco SQLite local do STOX.
///
/// Gerencia o ciclo de vida do banco, migrations e operações CRUD
/// da tabela [contagens].
///
/// syncStatus: 0 = Pendente, 1 = Sincronizado, 2 = Erro no envio.
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
    final path = join(await getDatabasesPath(), filePath);
    return openDatabase(
      path,
      version: 2,
      onCreate:  _criarTabelas,
      onUpgrade: _migrar,
    );
  }

  /// Cria o schema completo na primeira instalação.
  Future<void> _criarTabelas(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contagens (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        itemCode      TEXT    NOT NULL,
        quantidade    REAL    NOT NULL,
        dataHora      TEXT    NOT NULL,
        syncStatus    INTEGER NOT NULL DEFAULT 0,
        warehouseCode TEXT    NOT NULL DEFAULT '01'
      )
    ''');
    await db.execute('CREATE INDEX idx_itemCode   ON contagens (itemCode)');
    await db.execute('CREATE INDEX idx_syncStatus ON contagens (syncStatus)');
  }

  /// Aplica migrations incrementais para usuários que já tinham o banco instalado.
  Future<void> _migrar(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 → v2: adição da coluna warehouseCode
      await db.execute(
          "ALTER TABLE contagens ADD COLUMN warehouseCode TEXT NOT NULL DEFAULT '01'");
    }
    // Para futuras versões: if (oldVersion < 3) { ... }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<int> inserirContagem(
    String itemCode,
    double quantidade, {
    String warehouseCode = '01',
  }) async {
    final db = await instance.database;
    return db.insert('contagens', {
      'itemCode':      itemCode.toUpperCase(),
      'quantidade':    quantidade,
      'dataHora':      DateTime.now().toIso8601String(),
      'syncStatus':    0,
      'warehouseCode': warehouseCode.toUpperCase(),
    });
  }

  /// Atualiza a quantidade e redefine o status para Pendente (0).
  Future<int> atualizarContagem(int id, double novaQuantidade) async {
    final db = await instance.database;
    return db.update(
      'contagens',
      {
        'quantidade': novaQuantidade,
        'dataHora':   DateTime.now().toIso8601String(),
        'syncStatus': 0,
      },
      where:     'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> atualizarStatusSincronizacao(int id, int novoStatus) async {
    final db = await instance.database;
    return db.update(
      'contagens',
      {'syncStatus': novoStatus},
      where:     'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> excluirContagem(int id) async {
    final db = await instance.database;
    return db.delete('contagens', where: 'id = ?', whereArgs: [id]);
  }

  /// Retorna todas as contagens, ordenadas da mais recente para a mais antiga.
  Future<List<Map<String, dynamic>>> buscarContagens() async {
    final db = await instance.database;
    return db.query('contagens', orderBy: 'dataHora DESC');
  }

  /// Retorna apenas contagens Pendentes (0) ou com Erro (2), no formato FIFO.
  Future<List<Map<String, dynamic>>> buscarContagensPendentes() async {
    final db = await instance.database;
    return db.query(
      'contagens',
      where:     'syncStatus IN (?, ?)',
      whereArgs: [0, 2],
      orderBy:   'dataHora ASC',
    );
  }

  Future<double> calcularTotalPorItem(String itemCode) async {
    final db     = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(quantidade) AS total FROM contagens WHERE itemCode = ?',
      [itemCode.toUpperCase()],
    );
    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  /// Remove todas as contagens (usado após sincronização bem-sucedida).
  Future<void> limparContagens() async {
    final db = await instance.database;
    await db.delete('contagens');
  }

  /// Remove apenas as contagens com status Sincronizado (1).
  Future<void> limparContagensSincronizadas() async {
    final db = await instance.database;
    await db.delete('contagens', where: 'syncStatus = ?', whereArgs: [1]);
  }

  Future<void> close() async {
    final db = await instance.database;
    _database = null;
    await db.close();
  }
}