class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'STUDENT' | 'FACULTY' | 'VENDOR' | 'ADMIN'
  final DateTime? createdAt;

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
  });

  bool get isVendor => role.toUpperCase() == 'VENDOR';
  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  bool get isStudentOrFaculty =>
      role.toUpperCase() == 'STUDENT' || role.toUpperCase() == 'FACULTY';

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: (json['id'] ?? json['user_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      role: (json['role'] ?? 'STUDENT') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
