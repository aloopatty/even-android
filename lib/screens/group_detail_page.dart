import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/even_repository.dart';
import '../domain/models.dart';
import '../theme/even_theme.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({super.key, required this.group, required this.repository});
  final EvenGroup group;
  final EvenRepository repository;
  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  late Future<List<String>> _members;
  late Future<List<EvenExpense>> _expenses;
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() {
    _members = widget.repository.groupMembers(widget.group.id);
    _expenses = widget.repository.groupExpenses(widget.group.id);
  }
  String _format(int minor) => _money.format(minor / 100);

  Future<void> _addMember() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Add a person'),
      content: TextField(controller: controller, autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (value) => Navigator.pop(context, value.trim())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Add')),
      ],
    ));
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      await widget.repository.addGroupMember(widget.group.id, name);
      if (mounted) setState(_reload);
    } on ArgumentError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message?.toString() ?? 'Could not add person.')));
    }
  }

  Future<void> _removeMember(String name) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Remove person?'),
      content: Text('Remove $name from ${widget.group.name}? People with existing expense history cannot be removed.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
      ],
    ));
    if (confirmed != true) return;
    try {
      await widget.repository.removeGroupMember(widget.group.id, name);
      if (mounted) setState(_reload);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F6FB),
    appBar: AppBar(title: Text(widget.group.name, style: const TextStyle(fontWeight: FontWeight.w700))),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _addMember, backgroundColor: EvenPalette.primary, foregroundColor: Colors.white,
      icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add person')),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 100), children: [
      const Text('PEOPLE', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Color(0xFF777C91))),
      const SizedBox(height: 10),
      FutureBuilder<List<String>>(future: _members, builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
        if (snapshot.hasError) return Text('Could not load members: ${snapshot.error}');
        final members = snapshot.data ?? const <String>[];
        return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: EvenPalette.border)),
          child: Column(children: [
            for (var i = 0; i < members.length; i++) ...[
              ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xFFE9E8FF),
                  child: Text(members[i].isEmpty ? '?' : members[i][0].toUpperCase(),
                    style: const TextStyle(color: Color(0xFF29265F), fontWeight: FontWeight.w700))),
                title: Text(members[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(members[i].toLowerCase() == 'you' ? 'Group owner · Local profile' : 'Local member · Not yet invited'),
                trailing: members[i].toLowerCase() == 'you' ? const Icon(Icons.verified_user_outlined, color: Color(0xFF777C91))
                  : IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _removeMember(members[i])),
              ),
              if (i != members.length - 1) const Divider(height: 1, indent: 68),
            ],
          ]));
      }),
      const SizedBox(height: 26),
      const Text('GROUP EXPENSES', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Color(0xFF777C91))),
      const SizedBox(height: 10),
      FutureBuilder<List<EvenExpense>>(future: _expenses, builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(22), child: CircularProgressIndicator(strokeWidth: 2)));
        if (snapshot.hasError) return Text('Could not load expenses: ${snapshot.error}');
        final expenses = snapshot.data ?? const <EvenExpense>[];
        if (expenses.isEmpty) return Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: const Text('No expenses in this group yet.', style: TextStyle(color: Color(0xFF777C91))));
        return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            for (var i = 0; i < expenses.length; i++) ...[
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFF0F1F8), child: Icon(Icons.receipt_outlined, color: Color(0xFF777C91))),
                title: Text(expenses[i].title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Paid by ${expenses[i].paidBy}'),
                trailing: Text(_format(expenses[i].amountMinor), style: const TextStyle(fontWeight: FontWeight.w700))),
              if (i != expenses.length - 1) const Divider(height: 1, indent: 68),
            ],
          ]));
      }),
    ]),
  );
}
