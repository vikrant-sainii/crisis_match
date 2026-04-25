import 'package:equatable/equatable.dart';

class EmergencyContact extends Equatable {
  final String name;
  final String phone;
  final String relation;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relation: json['relation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'relation': relation,
    };
  }

  @override
  List<Object?> get props => [name, phone, relation];
}

class ProfileModel extends Equatable {
  final String id;
  final String role;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final DateTime? createdAt;
  final bool isBlocked;
  final DateTime? blockedUntil;
  final String? fcmToken;
  final List<EmergencyContact> emergencyContacts;

  const ProfileModel({
    required this.id,
    required this.role,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.createdAt,
    this.isBlocked = false,
    this.blockedUntil,
    this.fcmToken,
    this.emergencyContacts = const [],
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'victim',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      isBlocked: json['is_blocked'] as bool? ?? false,
      blockedUntil: json['blocked_until'] != null
          ? DateTime.parse(json['blocked_until'] as String)
          : null,
      fcmToken: json['fcm_token'] as String?,
      emergencyContacts: (json['emergency_contacts'] as List? ?? [])
          .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'is_blocked': isBlocked,
      'blocked_until': blockedUntil?.toIso8601String(),
      'fcm_token': fcmToken,
      'emergency_contacts': emergencyContacts.map((e) => e.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        role,
        fullName,
        email,
        phone,
        avatarUrl,
        createdAt,
        isBlocked,
        blockedUntil,
        fcmToken,
        emergencyContacts,
      ];

  ProfileModel copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    bool? isBlocked,
    DateTime? blockedUntil,
    String? fcmToken,
    List<EmergencyContact>? emergencyContacts,
  }) {
    return ProfileModel(
      id: id,
      role: role,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedUntil: blockedUntil ?? this.blockedUntil,
      fcmToken: fcmToken ?? this.fcmToken,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }
}
