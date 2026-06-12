class Payslip {
  const Payslip({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.grossCents,
    required this.netCents,
    this.documentUrl,
  });

  final int id;
  final String periodStart;
  final String periodEnd;
  final int grossCents;
  final int netCents;
  final String? documentUrl;

  factory Payslip.fromJson(Map<String, dynamic> json) => Payslip(
        id: json['id'] as int,
        periodStart: json['period_start'] as String,
        periodEnd: json['period_end'] as String,
        grossCents: json['gross_cents'] as int,
        netCents: json['net_cents'] as int,
        documentUrl: json['document_url'] as String?,
      );

  Map<String, dynamic> toSqliteRow() => {
        'payslip_id': id,
        'period_start': periodStart,
        'period_end': periodEnd,
        'gross_cents': grossCents,
        'net_cents': netCents,
        'document_url': documentUrl,
      };

  factory Payslip.fromSqlite(Map<String, dynamic> row) => Payslip(
        id: row['payslip_id'] as int,
        periodStart: row['period_start'] as String,
        periodEnd: row['period_end'] as String,
        grossCents: row['gross_cents'] as int,
        netCents: row['net_cents'] as int,
        documentUrl: row['document_url'] as String?,
      );

  String get formattedNet {
    final dollars = netCents ~/ 100;
    final cents = (netCents % 100).toString().padLeft(2, '0');
    final dollarsStr = dollars.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '\$$dollarsStr.$cents';
  }

  String get formattedGross {
    final dollars = grossCents ~/ 100;
    final cents = (grossCents % 100).toString().padLeft(2, '0');
    final dollarsStr = dollars.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '\$$dollarsStr.$cents';
  }
}
