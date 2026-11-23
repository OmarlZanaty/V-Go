/// Formats an EGP amount without ever rounding up: floors to the nearest 0.5.
/// Whole numbers show no decimals ("41"), otherwise one decimal ("40.5").
String formatEgp(num v) {
  final f = (v * 2).floor() / 2;
  return f == f.truncateToDouble() ? f.toInt().toString() : f.toStringAsFixed(1);
}
