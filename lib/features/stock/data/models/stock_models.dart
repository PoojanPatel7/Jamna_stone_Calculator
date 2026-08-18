class BlockType {
  String id;
  String name;

  BlockType({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };

  factory BlockType.fromJson(Map<String, dynamic> json) => BlockType(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    name: json['name'] ?? 'Unknown Type',
  );
}

class StockEntry {
  String id;
  String blockNumber;
  String blockName;
  bool isPolished; // true for polished, false for unpolished
  int totalSlabCount;
  double estimatedArea;
  DateTime date;
  String blockTypeId;
  String blockTypeName; // Cache the name for easy display
  bool isSold;
  bool isSynced;

  StockEntry({
    required this.id,
    required this.blockNumber,
    required this.blockName,
    required this.isPolished,
    required this.totalSlabCount,
    required this.estimatedArea,
    required this.date,
    required this.blockTypeId,
    required this.blockTypeName,
    this.isSold = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'blockNumber': blockNumber,
    'blockName': blockName,
    'isPolished': isPolished,
    'totalSlabCount': totalSlabCount,
    'estimatedArea': estimatedArea,
    'date': date.toIso8601String(),
    'blockTypeId': blockTypeId,
    'blockTypeName': blockTypeName,
    'isSold': isSold,
    'isSynced': isSynced,
  };

  factory StockEntry.fromJson(Map<String, dynamic> json) => StockEntry(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    blockNumber: json['blockNumber'] ?? '',
    blockName: json['blockName'] ?? 'Unknown Block',
    isPolished: json['isPolished'] ?? false,
    totalSlabCount: json['totalSlabCount'] ?? 0,
    estimatedArea: (json['estimatedArea'] ?? 0.0).toDouble(),
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    blockTypeId: json['blockTypeId'] ?? '',
    blockTypeName: json['blockTypeName'] ?? 'Unknown Type',
    isSold: json['isSold'] ?? false,
    isSynced: json['isSynced'] ?? false,
  );
}
