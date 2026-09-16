import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String profileImage;
  final String status;
  final String bio;
  final String? fcmToken;
  final String? banReason;
  final Timestamp? bannedUntil;
  final Timestamp? bannedAt;
  final String? bannedBy;
  final int strikeCount;
  final Timestamp? createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImage = '',
    this.status = 'active',
    this.bio = '',
    this.fcmToken,
    this.banReason,
    this.bannedUntil,
    this.bannedAt,
    this.bannedBy,
    this.strikeCount = 0,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId.isNotEmpty ? documentId : (map['uid'] ?? ''),
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      profileImage: map['profileImage'] ?? '',
      status: map['status'] ?? 'active',
      bio: map['bio'] ?? '',
      fcmToken: map['fcmToken'],
      banReason: map['banReason'] ?? map['ban_reason'],
      bannedUntil: map['bannedUntil'] is Timestamp ? map['bannedUntil'] : null,
      bannedAt: map['bannedAt'] is Timestamp
          ? map['bannedAt']
          : (map['moderated_at'] is Timestamp ? map['moderated_at'] : null),
      bannedBy: map['bannedBy'] ?? map['moderated_by'],
      strikeCount: (map['strikeCount'] ?? map['strike_count'] ?? 0) is int
          ? (map['strikeCount'] ?? map['strike_count'] ?? 0)
          : int.tryParse((map['strikeCount'] ?? map['strike_count'] ?? 0).toString()) ?? 0,
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
      'status': status,
      'bio': bio,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (banReason != null) 'banReason': banReason,
      if (bannedUntil != null) 'bannedUntil': bannedUntil,
      if (bannedAt != null) 'bannedAt': bannedAt,
      if (bannedBy != null) 'bannedBy': bannedBy,
      'strikeCount': strikeCount,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}
