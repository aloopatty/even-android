/// Exact conversion between rupees and integer paise.
/// Money is stored as integer paise; no floating-point arithmetic is used.
int? parseRupeesToPaise(String input) {
  final value = input.trim();
  if (!RegExp(r'^(?:[0-9]+(?:\.[0-9]{0,2})?|\.[0-9]{1,2})$').hasMatch(value)) {
    return null;
  }

  final parts = value.split('.');
  final rupeesText = parts[0].isEmpty ? '0' : parts[0];
  final paiseText = parts.length == 1
      ? '00'
      : (parts[1] + '00').substring(0, 2);

  try {
    final total = BigInt.parse(rupeesText) * BigInt.from(100) +
        BigInt.parse(paiseText);
    if (total > BigInt.from(0x7fffffffffffffff)) return null;
    return total.toInt();
  } on FormatException {
    return null;
  }
}
