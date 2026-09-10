class ServiceTypeModel {
  final String id;
  final String name;
  final String? code;
  final String? description;
  final double? price;
  final int? estimatedDurationMinutes;

  const ServiceTypeModel({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.price,
    this.estimatedDurationMinutes,
  });

  /// Check if this service belongs to Prenatal & Obstetrics category
  bool get isPrenatal {
    final lower = (name + (code ?? '') + (description ?? '')).toLowerCase();
    return lower.contains('thai') ||
        lower.contains('sản') ||
        lower.contains('prenatal') ||
        lower.contains('obstetric') ||
        lower.contains('mẹ & bé') ||
        lower.contains('ctg');
  }

  /// Check if this service belongs to Gynecology category
  bool get isGynecology {
    final lower = (name + (code ?? '') + (description ?? '')).toLowerCase();
    return lower.contains('phụ khoa') ||
        lower.contains('gynecology') ||
        lower.contains('gyn') ||
        lower.contains('soi cổ tử cung') ||
        lower.contains('pap') ||
        lower.contains('hpv') ||
        lower.contains('kinh');
  }

  /// Check if this service is Emergency
  bool get isEmergency {
    final lower = (name + (code ?? '')).toLowerCase();
    return lower.contains('cấp cứu') || lower.contains('emergency');
  }

  /// Category tag for grouping in UI
  String get category {
    if (isPrenatal) return 'prenatal';
    if (isGynecology) return 'gynecology';
    return 'other';
  }

  String get categoryLabel {
    if (isPrenatal) return 'Khám thai & Quản lý thai kỳ';
    if (isGynecology) return 'Khám phụ khoa & Tầm soát';
    return 'Sản - Phụ khoa khác & Cận lâm sàng';
  }

  factory ServiceTypeModel.fromJson(Map<String, dynamic> json) {
    return ServiceTypeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      description: json['description']?.toString(),
      price: json['price'] != null
          ? (json['price'] as num).toDouble()
          : (json['basePrice'] != null ? (json['basePrice'] as num).toDouble() : null),
      estimatedDurationMinutes: json['estimatedDurationMinutes'] is int
          ? json['estimatedDurationMinutes'] as int
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'price': price,
      'estimatedDurationMinutes': estimatedDurationMinutes,
    };
  }
}
