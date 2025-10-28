class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? photoUrl;
  final DateTime createdAt;
  final bool isActive;
  final String accountType;
  final double? averageRating;
  final String? paypalEmail;
  final String? state;
  final String? city;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.photoUrl,
    required this.createdAt,
    this.isActive = true,
    required this.accountType,
    this.averageRating,
    this.paypalEmail,
    this.state,
    this.city,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      phone: json['phone'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] ?? true,
      accountType: json['accountType'] as String? ?? 'individual',
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      paypalEmail: json['paypalEmail'] as String?,
      state: json['state'] as String?,
      city: json['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'accountType': accountType,
      'averageRating': averageRating,
      'paypalEmail': paypalEmail,
      'state': state,
      'city': city,
    };
  }

  // Create a copy of UserModel with modified fields
  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? photoUrl,
    DateTime? createdAt,
    bool? isActive,
    String? accountType,
    double? averageRating,
    String? paypalEmail,
    String? state,
    String? city,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      accountType: accountType ?? this.accountType,
      averageRating: averageRating ?? this.averageRating,
      paypalEmail: paypalEmail ?? this.paypalEmail,
      state: state ?? this.state,
      city: city ?? this.city,
    );
  }

  // Get full name
  String get fullName => '$firstName $lastName';
}
