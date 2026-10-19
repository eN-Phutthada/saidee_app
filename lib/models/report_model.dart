import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reporterEmail;
  final String targetType;
  final String targetId;
  final String targetTitle;
  final String reportedUserId;
  final String category;
  final String detail;
  final List<String> evidenceUrls;
  final String status;
  final String actionTaken;
  final String adminNote;
  final String? resolvedBy;
  final Timestamp? resolvedAt;
  final Timestamp? createdAt;

  ReportModel({
    required this.id,
    required this.reporterId,
    this.reporterName = '',
    this.reporterEmail = '',
    required this.targetType,
    required this.targetId,
    this.targetTitle = '',
    required this.reportedUserId,
    required this.category,
    this.detail = '',
    this.evidenceUrls = const [],
    this.status = 'pending',
    this.actionTaken = 'none',
    this.adminNote = '',
    this.resolvedBy,
    this.resolvedAt,
    this.createdAt,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map, String documentId) {
    List<String> evidences = [];
    if (map['evidenceUrls'] is List) {
      evidences = List<String>.from(map['evidenceUrls']);
    } else if (map['image_proof'] != null &&
        map['image_proof'].toString().isNotEmpty) {
      evidences = [map['image_proof'].toString()];
    }

    String orderId = (map['order_id'] ?? '').toString();
    String detectedType = map['targetType'] ?? (orderId.isNotEmpty ? 'order' : 'store');

    return ReportModel(
      id: documentId,
      reporterId: map['reporter_id'] ?? map['reporterId'] ?? '',
      reporterName: map['reporterName'] ?? map['reporter_name'] ?? '',
      reporterEmail: map['reporterEmail'] ?? map['reporter_email'] ?? '',
      targetType: detectedType,
      targetId: map['targetId'] ?? (orderId.isNotEmpty ? orderId : (map['reported_id'] ?? '')),
      targetTitle: map['targetTitle'] ?? map['topic'] ?? '',
      reportedUserId: map['reported_id'] ?? map['reportedUserId'] ?? '',
      category: map['category'] ?? map['topic'] ?? 'ทั่วไป',
      detail: map['detail'] ?? '',
      evidenceUrls: evidences,
      status: map['status'] ?? 'pending',
      actionTaken: map['actionTaken'] ?? 'none',
      adminNote: map['adminNote'] ?? map['note'] ?? '',
      resolvedBy: map['resolvedBy'] ?? map['moderated_by'],
      resolvedAt: map['resolvedAt'] is Timestamp ? map['resolvedAt'] : null,
      createdAt: map['createdAt'] is Timestamp ? map['createdAt'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reporter_id': reporterId,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reporterEmail': reporterEmail,
      'targetType': targetType,
      'targetId': targetId,
      'targetTitle': targetTitle,
      'reported_id': reportedUserId,
      'reportedUserId': reportedUserId,
      'category': category,
      'topic': category,
      'detail': detail,
      'evidenceUrls': evidenceUrls,
      'image_proof': evidenceUrls.isNotEmpty ? evidenceUrls.first : '',
      'status': status,
      'actionTaken': actionTaken,
      'adminNote': adminNote,
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
      if (resolvedAt != null) 'resolvedAt': resolvedAt,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
