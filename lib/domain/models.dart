class EvenGroup {
  const EvenGroup({required this.id, required this.name, required this.members, required this.createdAt});
  final String id;
  final String name;
  final List<String> members;
  final DateTime createdAt;

  factory EvenGroup.fromMap(Map<String, Object?> map) => EvenGroup(
    id: map['id']! as String,
    name: map['name']! as String,
    members: (map['members'] as String? ?? 'You').split('|'),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
  );
}

class EvenExpense {
  const EvenExpense({required this.id, required this.title, required this.amountMinor, required this.currency, required this.paidBy, required this.groupId, required this.createdAt});
  final String id;
  final String title;
  final int amountMinor;
  final String currency;
  final String paidBy;
  final String? groupId;
  final DateTime createdAt;

  factory EvenExpense.fromMap(Map<String, Object?> map) => EvenExpense(
    id: map['id']! as String,
    title: map['title']! as String,
    amountMinor: map['amount_minor']! as int,
    currency: map['currency'] as String? ?? 'INR',
    paidBy: map['paid_by'] as String? ?? 'You',
    groupId: map['group_id'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
  );
}
