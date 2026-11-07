/// Exact conversion between rupees and integer paise.
/// No floating-point arithmetic is used for money.
int? parseRupeesToPaise(String input) {
  final value = input.trim();
  if (!RegExp(r'^(?:\\d+(?:\\.\\d{0,2})?|\\.\\d{1,2})$').hasMatch(value)) {
    return null;
  }
  try {
    final parts = value.split('.');
    final rupees = parts[0].isEmpty ? 0 : int.parse(parts[0]);
    final paise = parts.length == 1
        ? 0
        : int.parse((parts[1] + '00').substring(0, 2));
    return rupees * 100 + paise;
  } on FormatException {
    return null;
  } on RangeError {
    return null;
  }
}
