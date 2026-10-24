import 'package:cloud_firestore/cloud_firestore.dart';
class CashClosureModel {
  final String idClosure;
  final DateTime openingDate;
  final DateTime? closingDate;
  final double initialCash;
  final double cashSale;
  final double totalSale;
  final double expectedCash;
  final double recordedCash;
  final double difference;
  final String idBranch;
  final String idUsers;
  final bool statusClosing;
  final int saleCount;
  final double? configuredInitialCash;
  final String? initialCashComment;
  final String? closingComment;

  const CashClosureModel({
    this.idClosure = '',
    required this.openingDate,
    this.closingDate,
    required this.initialCash,
    this.cashSale = 0,
    this.totalSale = 0,
    required this.expectedCash,
    this.recordedCash = 0,
    this.difference = 0,
    required this.idBranch,
    required this.idUsers,
    this.statusClosing = false,
    this.saleCount = 0,
    this.configuredInitialCash,
    this.initialCashComment,
    this.closingComment,
  });

  factory CashClosureModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return CashClosureModel(
      idClosure: doc.id,
      openingDate: _date(data['opening_date']) ?? DateTime.now(),
      closingDate: _date(data['closing_date']),
      initialCash: _number(data['initial_cash']),
      cashSale: _number(data['cash_sale']),
      totalSale: _number(data['total_sale']),
      expectedCash: _number(data['expected_cash']),
      recordedCash: _number(data['recorded_cash']),
      difference: _number(data['difference']),
      idBranch: data['id_branch']?.toString() ?? '',
      idUsers:
          (data['id_users'] ?? data['id_user'])?.toString() ?? '',
      statusClosing: data['status_closing'] == true,
      saleCount: _integer(data['sale_count']),
      configuredInitialCash: data['configured_initial_cash'] == null
          ? null
          : _number(data['configured_initial_cash']),
      initialCashComment: data['initial_cash_comment']?.toString(),
      closingComment: data['closing_comment']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'opening_date': Timestamp.fromDate(openingDate),
      'closing_date': closingDate == null
          ? null
          : Timestamp.fromDate(closingDate!),
      'initial_cash': initialCash,
      'cash_sale': cashSale,
      'total_sale': totalSale,
      'expected_cash': expectedCash,
      'recorded_cash': recordedCash,
      'difference': difference,
      'id_branch': idBranch,
      'id_users': idUsers,
      'status_closing': statusClosing,
      'sale_count': saleCount,
      'configured_initial_cash': configuredInitialCash,
      'initial_cash_comment': initialCashComment,
      'closing_comment': closingComment,
    };
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
    }
    return 0;
  }

  static int _integer(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  CashClosureModel copyWith({
    String? idClosure,
    DateTime? openingDate,
    DateTime? closingDate,
    bool clearClosingDate = false,
    double? initialCash,
    double? cashSale,
    double? totalSale,
    double? expectedCash,
    double? recordedCash,
    double? difference,
    String? idBranch,
    String? idUsers,
    bool? statusClosing,
    int? saleCount,
    double? configuredInitialCash,
    String? initialCashComment,
    String? closingComment,
  }) {
    return CashClosureModel(
      idClosure: idClosure ?? this.idClosure,
      openingDate: openingDate ?? this.openingDate,
      closingDate: clearClosingDate
          ? null
          : closingDate ?? this.closingDate,
      initialCash: initialCash ?? this.initialCash,
      cashSale: cashSale ?? this.cashSale,
      totalSale: totalSale ?? this.totalSale,
      expectedCash: expectedCash ?? this.expectedCash,
      recordedCash: recordedCash ?? this.recordedCash,
      difference: difference ?? this.difference,
      idBranch: idBranch ?? this.idBranch,
      idUsers: idUsers ?? this.idUsers,
      statusClosing: statusClosing ?? this.statusClosing,
      saleCount: saleCount ?? this.saleCount,
      configuredInitialCash:
          configuredInitialCash ?? this.configuredInitialCash,
      initialCashComment: initialCashComment ?? this.initialCashComment,
      closingComment: closingComment ?? this.closingComment,
    );
  }
}
