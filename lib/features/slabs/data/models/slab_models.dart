

class SlabEntry {
  int slabNo;
  double length;
  double width;
  int quantity;

  SlabEntry({
    required this.slabNo,
    this.length = 0.0,
    this.width = 0.0,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
    'slabNo': slabNo,
    'length': length,
    'width': width,
    'quantity': quantity,
  };

  factory SlabEntry.fromJson(Map<String, dynamic> json) => SlabEntry(
    slabNo: json['slabNo'] ?? 1,
    length: (json['length'] ?? 0.0).toDouble(),
    width: (json['width'] ?? 0.0).toDouble(),
    quantity: json['quantity'] ?? 1,
  );

  double getArea(String unit) {
    double baseArea = length * width * quantity;
    if (unit == 'Inches') {
      return baseArea / 144.0; // Square Feet
    } else if (unit == 'Cm') {
      return baseArea / 10000.0; // Square Meters
    }
    return baseArea; // Feet -> Sq Ft, Meter -> Sq Meter
  }
}

class SlabBook {
  String id;
  String name;
  String? graniteName;
  String? partyName;
  String? numberPlate;
  String? linkedStockId;
  String? linkedBlockDisplay;
  DateTime date;
  String unit;
  List<SlabEntry> slabs;
  bool isSynced;

  SlabBook({
    required this.id,
    required this.name,
    this.graniteName,
    this.partyName,
    this.numberPlate,
    this.linkedStockId,
    this.linkedBlockDisplay,
    required this.date,
    required this.unit,
    required this.slabs,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'graniteName': graniteName,
    'partyName': partyName,
    'numberPlate': numberPlate,
    'linkedStockId': linkedStockId,
    'linkedBlockDisplay': linkedBlockDisplay,
    'date': date.toIso8601String(),
    'unit': unit,
    'slabs': slabs.map((e) => e.toJson()).toList(),
    'isSynced': isSynced,
  };

  factory SlabBook.fromJson(Map<String, dynamic> json) => SlabBook(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    name: json['name'] ?? 'Untitled Book',
    graniteName: json['graniteName'],
    partyName: json['partyName'],
    numberPlate: json['numberPlate'],
    linkedStockId: json['linkedStockId'],
    linkedBlockDisplay: json['linkedBlockDisplay'],
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    unit: json['unit'] ?? 'Feet',
    slabs: (json['slabs'] as List?)?.map((e) => SlabEntry.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    isSynced: json['isSynced'] ?? false,
  );
}
