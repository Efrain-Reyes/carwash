class Supplier {
  final int id;
  final String name;
  final String? contact;
  final bool isActive;

  const Supplier({
    required this.id,
    required this.name,
    this.contact,
    required this.isActive,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id:       json['id'] as int,
      name:     json['name'] as String,
      contact:  json['contact'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
