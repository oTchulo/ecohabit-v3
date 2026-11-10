import '../../models/domain.dart';

/// IDs 1, 2 e 3 são preservados pela migração. Os demais são atribuídos pelo SQLite.
class CatalogEntry {
  final String code, name, category, unit;
  final ScoringType type;
  final int limit, ods;
  final List<Band> bands;
  const CatalogEntry(this.code, this.name, this.category, this.unit, this.type,
      this.limit, this.bands,
      {this.ods = 11});
  String get actionGroup => category == 'MOBILIDADE' ? 'TRAJETO' : code;
}

const sustainableCatalog = <CatalogEntry>[
  CatalogEntry(
      'bicicleta', 'Bicicleta', 'MOBILIDADE', 'km', ScoringType.daily, 150, [
    Band(1, 5, 25),
    Band(6, 10, 50),
    Band(11, 20, 100),
    Band(21, null, 150)
  ]),
  CatalogEntry(
      'caminhada',
      'Caminhada',
      'MOBILIDADE',
      'km',
      ScoringType.daily,
      130,
      [Band(1, 2, 20), Band(3, 5, 50), Band(6, 10, 90), Band(11, null, 130)]),
  CatalogEntry(
      'carro_eletrico',
      'Carro elétrico',
      'MOBILIDADE',
      'km',
      ScoringType.daily,
      60,
      [Band(1, 10, 20), Band(11, 30, 40), Band(31, null, 60)]),
  CatalogEntry(
      'transporte_publico',
      'Transporte público',
      'MOBILIDADE',
      'viagens',
      ScoringType.daily,
      45,
      [Band(1, 1, 15), Band(2, 2, 30), Band(3, null, 45)]),
  CatalogEntry(
      'carona',
      'Carona compartilhada',
      'MOBILIDADE',
      'viagens',
      ScoringType.daily,
      45,
      [Band(1, 1, 15), Band(2, 2, 30), Band(3, null, 45)]),
  CatalogEntry(
      'luzes_apagadas',
      'Economia de energia',
      'ENERGIA',
      'minutos',
      ScoringType.daily,
      80,
      [Band(1, 15, 10), Band(16, 30, 25), Band(31, 60, 50), Band(61, null, 80)],
      ods: 7),
  CatalogEntry(
      'aparelhos_desligados',
      'Aparelhos desligados',
      'ENERGIA',
      'horas',
      ScoringType.daily,
      90,
      [Band(1, 2, 15), Band(3, 4, 30), Band(5, 8, 60), Band(9, null, 90)],
      ods: 7),
  CatalogEntry(
      'energia_solar',
      'Energia solar gerada',
      'ENERGIA',
      'kWh',
      ScoringType.daily,
      70,
      [Band(1, 5, 20), Band(6, 15, 45), Band(16, null, 70)],
      ods: 7),
  CatalogEntry('instalar_solar', 'Instalar energia solar', 'ENERGIA',
      'instalação', ScoringType.unique, 200, [Band(1, 1, 200)],
      ods: 7),
  CatalogEntry('garrafas_pet', 'Reciclagem de garrafas', 'RECICLAGEM',
      'garrafas', ScoringType.daily, 150, [
    Band(1, 5, 30),
    Band(6, 10, 60),
    Band(11, 20, 100),
    Band(21, null, 150)
  ]),
  CatalogEntry(
      'latinhas',
      'Reciclagem de latinhas',
      'RECICLAGEM',
      'unidades',
      ScoringType.daily,
      140,
      [Band(1, 5, 20), Band(6, 15, 50), Band(16, 30, 90), Band(31, null, 140)]),
  CatalogEntry(
      'papel_papelao',
      'Papel e papelão',
      'RECICLAGEM',
      'kg',
      ScoringType.daily,
      120,
      [Band(1, 2, 20), Band(3, 5, 45), Band(6, 10, 80), Band(11, null, 120)]),
  CatalogEntry(
      'eletronicos',
      'Descarte de eletrônicos',
      'RECICLAGEM',
      'itens',
      ScoringType.monthly,
      80,
      [Band(1, 1, 30), Band(2, 2, 55), Band(3, null, 80)]),
  CatalogEntry(
      'banho_reduzido',
      'Banho mais curto',
      'AGUA',
      'minutos',
      ScoringType.daily,
      100,
      [Band(1, 3, 20), Band(4, 6, 40), Band(7, 10, 70), Band(11, null, 100)]),
  CatalogEntry(
      'agua_reutilizada',
      'Água reutilizada',
      'AGUA',
      'litros',
      ScoringType.daily,
      120,
      [Band(1, 5, 20), Band(6, 15, 45), Band(16, 30, 80), Band(31, null, 120)]),
  CatalogEntry('vazamento_corrigido', 'Vazamento corrigido', 'AGUA', 'reparos',
      ScoringType.monthly, 100, [Band(1, 1, 60), Band(2, null, 100)]),
  CatalogEntry(
      'copos_evitados',
      'Copos descartáveis evitados',
      'CONSUMO',
      'unidades',
      ScoringType.daily,
      90,
      [Band(1, 2, 15), Band(3, 5, 35), Band(6, 10, 60), Band(11, null, 90)]),
  CatalogEntry(
      'sacola_reutilizavel',
      'Sacola reutilizável',
      'CONSUMO',
      'compras',
      ScoringType.daily,
      75,
      [Band(1, 1, 20), Band(2, 2, 35), Band(3, 4, 55), Band(5, null, 75)]),
  CatalogEntry(
      'arvores_plantadas',
      'Árvores plantadas',
      'NATUREZA',
      'mudas',
      ScoringType.monthly,
      120,
      [Band(1, 1, 50), Band(2, 2, 90), Band(3, null, 120)]),
  CatalogEntry('criar_composteira', 'Criar uma composteira', 'NATUREZA',
      'instalação', ScoringType.unique, 150, [Band(1, 1, 150)]),
];
