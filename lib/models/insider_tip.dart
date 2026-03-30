// ─────────────────────────────────────────────────────────────────────────────
// insider_tip.dart
//
// PURPOSE: Model for a "shady insider tip" — a DM the player receives from
//          a mysterious contact predicting a stock's direction. Tips are
//          purely flavor; the simulation does not bend to them. ~40% are wrong.
// ─────────────────────────────────────────────────────────────────────────────

class InsiderTip {
  final String id;           // unique: ticker + timestamp millis
  final String ticker;
  final String companyName;
  final String contactName;  // e.g. "Your uncle Gary"
  final String body;         // full message text
  final bool bullish;        // true = tip says buy, false = tip says sell/short
  final DateTime receivedAt;
  final bool isDismissed;

  const InsiderTip({
    required this.id,
    required this.ticker,
    required this.companyName,
    required this.contactName,
    required this.body,
    required this.bullish,
    required this.receivedAt,
    this.isDismissed = false,
  });

  InsiderTip copyWith({bool? isDismissed}) {
    return InsiderTip(
      id: id,
      ticker: ticker,
      companyName: companyName,
      contactName: contactName,
      body: body,
      bullish: bullish,
      receivedAt: receivedAt,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticker': ticker,
        'companyName': companyName,
        'contactName': contactName,
        'body': body,
        'bullish': bullish,
        'receivedAt': receivedAt.toIso8601String(),
        'isDismissed': isDismissed,
      };

  factory InsiderTip.fromJson(Map<String, dynamic> json) {
    return InsiderTip(
      id: json['id'] as String,
      ticker: json['ticker'] as String,
      companyName: json['companyName'] as String,
      contactName: json['contactName'] as String,
      body: json['body'] as String,
      bullish: json['bullish'] as bool,
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      isDismissed: json['isDismissed'] as bool? ?? false,
    );
  }
}
