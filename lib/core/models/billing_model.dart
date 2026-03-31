class BillingSummaryModel {
  final double creditBalance;
  final int callsThisMonth;
  final int callsLimit;
  final String planName;
  final String stripeCheckoutUrl;

  BillingSummaryModel({
    required this.creditBalance,
    required this.callsThisMonth,
    required this.callsLimit,
    required this.planName,
    required this.stripeCheckoutUrl,
  });

  factory BillingSummaryModel.fromJson(Map<String, dynamic> json) =>
      BillingSummaryModel(
        creditBalance: (json['credit_balance'] as num).toDouble(),
        callsThisMonth: json['calls_this_month'] as int,
        callsLimit: json['calls_limit'] as int,
        planName: json['plan_name'] as String,
        stripeCheckoutUrl: json['stripe_checkout_url'] as String,
      );
}

class CallUsagePoint {
  final String date;
  final int count;

  CallUsagePoint({required this.date, required this.count});

  factory CallUsagePoint.fromJson(Map<String, dynamic> json) =>
      CallUsagePoint(
        date: json['date'] as String,
        count: json['count'] as int,
      );
}

