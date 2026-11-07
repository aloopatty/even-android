import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'data/even_database.dart';
import 'data/even_repository.dart';
import 'domain/models.dart';
import 'domain/balance_engine.dart';
import 'domain/money.dart';
import 'domain/split_engine.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const EvenApp());
}

class EvenApp extends StatelessWidget {
  const EvenApp({super.key});
  @override
  Widget build(BuildContext context) {
    ThemeData makeTheme(Brightness brightness) {
      final dark = brightness == Brightness.dark;
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6657D9), brightness: brightness,
        surface: dark ? const Color(0xFF171622) : const Color(0xFFFAF9FF));
      return ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme,
        scaffoldBackgroundColor: dark ? const Color(0xFF11101A) : const Color(0xFFFAF9FF),
        fontFamily: 'Roboto',
        appBarTheme: AppBarTheme(backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(filled: true,
          fillColor: dark ? const Color(0xFF262436) : const Color(0xFFF0EEFF),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)));
    }
    return MaterialApp(title: 'Even', debugShowCheckedModeBanner: false, themeMode: ThemeMode.system,
      theme: makeTheme(Brightness.light), darkTheme: makeTheme(Brightness.dark),
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: dark ? const Color(0xFF11101A) : const Color(0xFFFAF9FF),
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const EvenHome());
  }
}

class EvenHome extends StatefulWidget {
  const EvenHome({super.key});
  @override
  State<EvenHome> createState() => _EvenHomeState();
}

class _EvenHomeState extends State<EvenHome> {
  final _repo = EvenRepository(EvenDatabase.instance);
  int _tab = 0;
  bool _loading = true;
  List<EvenGroup> _groups = [];
  List<EvenExpense> _expenses = [];
  int _spent = 0;
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  @override
  void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async {
    try {
      final values = await Future.wait([_repo.groups(), _repo.expenses(), _repo.totalSpentMinor()]);
      if (!mounted) return;
      setState(() { _groups = values[0] as List<EvenGroup>; _expenses = values[1] as List<EvenExpense>; _spent = values[2] as int; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }
  String _format(int minor) => _money.format(minor / 100);

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboard(),
      _activityPage(),
      _insightsPage(),
      _settingsPage(),
    ];
    return Scaffold(
      body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]))),
      floatingActionButton: _tab == 0 ? FloatingActionButton.extended(
        onPressed: _showPlacePicker, backgroundColor: const Color(0xFF5146C8), foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded), label: const Text('Add expense', style: TextStyle(fontWeight: FontWeight.w600)),
      ) : null,
      bottomNavigationBar: NavigationBar(
        height: 72, selectedIndex: _tab, backgroundColor: const Color(0xFFFAF9FF), indicatorColor: const Color(0xFFE8E4FF),
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _dashboard() => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 110), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Even', style: TextStyle(fontSize: 22, letterSpacing: -0.6, fontWeight: FontWeight.w800, color: Color(0xFF29265F))),
          const SizedBox(height: 5), Text(_greeting(), style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
        ]),
        Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFEAE7FF), shape: BoxShape.circle), child: const Icon(Icons.person_outline_rounded, color: Color(0xFF5146C8))),
      ]),
      const SizedBox(height: 26),
      Material(color: const Color(0xFF5146C8), borderRadius: BorderRadius.circular(26), child: InkWell(borderRadius: BorderRadius.circular(26), onTap: _showTotalExpenses, child: Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(borderRadius: BorderRadius.circular(26)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TOTAL EXPENSES', style: TextStyle(color: Color(0xFFB9C8BE), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(_format(_spent), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.2)),
        const SizedBox(height: 17),
        const Divider(color: Color(0xFF625A9B), height: 1),
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.shield_outlined, color: Color(0xFFB9C8BE), size: 16), const SizedBox(width: 8),
          const Expanded(child: Text('Your shared spending, in one place', style: TextStyle(color: Color(0xFFDAE1DB), fontSize: 12))),
          Text('${_expenses.length} entries', style: const TextStyle(color: Color(0xFFDAE1DB), fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ])))),
      const SizedBox(height: 28),
      Material(color: Colors.white, borderRadius: BorderRadius.circular(19), child: InkWell(
        borderRadius: BorderRadius.circular(19), onTap: _openPersonal,
        child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
          Container(width: 43, height: 43, decoration: BoxDecoration(color: const Color(0xFFEAE7FF), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.person_outline_rounded, color: Color(0xFF5146C8))),
          const SizedBox(width: 13), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Personal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            SizedBox(height: 3), Text('Your own expenses', style: TextStyle(color: Color(0xFF85877F), fontSize: 11)),
          ])), const Icon(Icons.chevron_right_rounded, color: Color(0xFF9A9D95)),
        ])))),
      const SizedBox(height: 9),
      _sectionHeader('Your groups', action: 'New group', onTap: _showAddGroup),
      const SizedBox(height: 13),
      if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
      else if (_groups.isEmpty) _emptyCard(icon: Icons.group_outlined, title: 'Your people, together', subtitle: 'Create a group for a trip, home or dinner.', action: 'Create your first group', onTap: _showAddGroup)
      else ..._groups.map(_groupTile),
      const SizedBox(height: 27),
      _sectionHeader('Recent activity', action: 'See all', onTap: () => setState(() => _tab = 1)),
      const SizedBox(height: 12),
      if (_expenses.isEmpty) _emptyCard(icon: Icons.receipt_long_outlined, title: 'Nothing to split yet', subtitle: 'Add an expense and EVEN will take care of the maths.', action: 'Add an expense', onTap: _showAddExpense)
      else ..._expenses.take(5).map(_expenseTile),
    ]),
  );

  Future<void> _showPlacePicker() async {
    final choice = await showModalBottomSheet<String?>(context: context, showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Where is this expense?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFEAE7FF), child: Icon(Icons.person_outline, color: Color(0xFF5146C8))),
            title: const Text('Personal'), subtitle: const Text('Just your personal expenses'),
            onTap: () => Navigator.pop(ctx, '__personal__')),
          ..._groups.map((g) => ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFEAE7FF), child: Icon(Icons.group_outlined, color: Color(0xFF5146C8))),
            title: Text(g.name), subtitle: Text('${g.members.length} people'),
            onTap: () => Navigator.pop(ctx, g.id))),
          ListTile(leading: const CircleAvatar(child: Icon(Icons.add)), title: const Text('Create a new group'),
            onTap: () { Navigator.pop(ctx, '__new__'); }),
        ]))));
    if (!mounted || choice == null) return;
    if (choice == '__new__') { await _showAddGroup(); if (!mounted) return; await _showPlacePicker(); return; }
    if (choice == '__personal__') { await _openPersonal(); return; }
    final group = _groups.firstWhere((g) => g.id == choice);
    await _openGroup(group);
  }

  Future<void> _openPersonal() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _PlacePage(
      title: 'Personal', subtitle: 'Your own expenses', icon: Icons.person_outline_rounded,
      expenses: _expenses.where((e) => e.groupId == null).toList(), format: _format,
      onAdd: () async { await _showAddExpense(); },
      onExpense: _showExpenseDetails,
    )));
    await _refresh();
  }

  Future<void> _openGroup(EvenGroup group) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _PlacePage(
      title: group.name, subtitle: '${group.members.length} people · shared expenses',
      icon: Icons.group_outlined, expenses: _expenses.where((e) => e.groupId == group.id).toList(),
      format: _format, onAdd: () async { await _showAddExpense(initialGroupId: group.id); },
      onExpense: _showExpenseDetails,
    )));
    await _refresh();
  }

  Future<void> _showTotalExpenses() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _PlacePage(
      title: 'Total expenses', subtitle: 'Every personal and group transaction',
      icon: Icons.account_balance_wallet_outlined, expenses: _expenses,
      format: _format, onAdd: _showPlacePicker, onExpense: _showExpenseDetails,
    )));
    await _refresh();
  }

  Future<void> _showExpenseDetails(EvenExpense expense) async {
    final shares = await _repo.expenseShares(expense.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(expense.title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(_format(expense.amountMinor), style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800, color: Color(0xFF5146C8))),
              const SizedBox(height: 8),
              Text('Paid by ${expense.paidBy} · ${DateFormat('d MMM yyyy · h:mm a').format(expense.createdAt)}',
                style: const TextStyle(color: Color(0xFF77748F))),
              const SizedBox(height: 18),
              const Text('Who owes what', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              ...shares.where((row) => row['person_id'] != expense.paidBy).map((row) {
                final person = row['person_id'] as String;
                final amount = row['amount_minor'] as int;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(person, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('Owes ${expense.paidBy}', style: const TextStyle(color: Color(0xFF77748F), fontSize: 12)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_format(amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: 'Hi $person, please settle ${_format(amount)} with ${expense.paidBy} for ${expense.title}.'));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder text copied. You can send it in your messaging app.')));
                          },
                          child: const Text('Remind'),
                        ),
                        TextButton(onPressed: () => _showSettleDebt(person, expense.paidBy, amount), child: const Text('Settle')),
                      ]),
                    ]),
                  ]),
                );
              }),
              if (shares.length == 1) const Text('No one else owes on this expense.'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final lines = shares.map((r) => '${r['person_id']}: ${_format(r['amount_minor'] as int)}').join('\n');
                    Clipboard.setData(ClipboardData(text: 'Even expense: ${expense.title}\nPaid by: ${expense.paidBy}\nTotal: ${_format(expense.amountMinor)}\n$lines'));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense breakdown copied.')));
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy breakdown'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSettleDebt(String from, String to, int amount) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Record settlement'), content: Text('Record that $from paid $to ${_format(amount)}? This only records a payment made outside the app.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark settled'))]));
    if (ok == true) { await _repo.recordSettlement(fromPerson: from, toPerson: to, amountMinor: amount); await _refresh(); }
  }

  String _greeting() { final hour = DateTime.now().hour; return hour < 12 ? 'Good morning.' : hour < 17 ? 'Good afternoon.' : 'Good evening.'; }
  Widget _sectionHeader(String title, {String? action, VoidCallback? onTap}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.4)), if (action != null) TextButton(onPressed: onTap, child: Text(action, style: const TextStyle(color: Color(0xFF6657D9), fontWeight: FontWeight.w600)))]);
  Widget _emptyCard({required IconData icon, required String title, required String subtitle, required String action, required VoidCallback onTap}) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE9E6F5))), child: Column(children: [Icon(icon, size: 28, color: const Color(0xFF6657D9)), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF85877F), fontSize: 12, height: 1.4)), const SizedBox(height: 10), TextButton(onPressed: onTap, child: Text(action, style: const TextStyle(color: Color(0xFF6657D9), fontWeight: FontWeight.w700)))]));
  Widget _groupTile(EvenGroup group) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => _openGroup(group),
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Container(
              width: 43, height: 43,
              decoration: BoxDecoration(color: _groupColor(group.name), borderRadius: BorderRadius.circular(14)),
              child: Icon(_groupIcon(group.name), color: const Color(0xFF5146C8)),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Text('${group.members.length} members', style: const TextStyle(color: Color(0xFF85877F), fontSize: 11)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9A9D95)),
          ]),
        ),
      ),
    );
  }
  Color _groupColor(String name) { final n = name.toLowerCase(); if (n.contains('trip') || n.contains('travel')) return const Color(0xFFECE8DB); if (n.contains('home') || n.contains('flat')) return const Color(0xFFEAE7FF); return const Color(0xFFEAE7FF); }
  IconData _groupIcon(String name) { final n = name.toLowerCase(); if (n.contains('trip') || n.contains('travel')) return Icons.flight_rounded; if (n.contains('home') || n.contains('flat')) return Icons.home_rounded; return Icons.group_rounded; }
  Widget _expenseTile(EvenExpense expense) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => _showExpenseDetails(expense),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFF0EEFF), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.receipt_outlined, color: Color(0xFF625A9B), size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 3),
              Text('Paid by ${expense.paidBy} · ${DateFormat('d MMM · h:mm a').format(expense.createdAt)}',
                style: const TextStyle(color: Color(0xFF8A8C84), fontSize: 10)),
            ])),
            Text(_format(expense.amountMinor), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF9994B8)),
          ]),
        ),
      ),
    );
  }

  Widget _activityPage() => ListView(padding: const EdgeInsets.all(22), children: [const SizedBox(height: 8), const Text('Activity', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)), const SizedBox(height: 6), const Text('Tap any transaction to see the full breakdown.', style: TextStyle(color: Color(0xFF85877F))), const SizedBox(height: 24), if (_expenses.isEmpty) _emptyCard(icon: Icons.receipt_long_outlined, title: 'Your activity starts here', subtitle: 'Expenses you add will appear here.', action: 'Add expense', onTap: _showAddExpense) else ..._expenses.map(_expenseTile)]);
  Widget _insightsPage() => FutureBuilder<Map<String, int>>(
    future: _repo.netBalances(),
    builder: (context, snapshot) {
      final balances = snapshot.data ?? const <String, int>{};
      final sorted = balances.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final transfers = snapshot.hasData ? BalanceEngine.suggestedTransfers(balances) : <Transfer>[];
      return ListView(padding: const EdgeInsets.all(22), children: [
        const SizedBox(height: 8),
        const Text('Balances', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
        const SizedBox(height: 6),
        const Text('Who owes whom, without the mental arithmetic.', style: TextStyle(color: Color(0xFF85877F))),
        const SizedBox(height: 22),
        if (snapshot.connectionState == ConnectionState.waiting)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (snapshot.hasError)
          _emptyCard(icon: Icons.error_outline, title: 'Could not calculate balances', subtitle: snapshot.error.toString(), action: 'Retry', onTap: () => setState(() {}))
        else if (balances.isEmpty)
          _emptyCard(icon: Icons.check_circle_outline, title: 'All settled up', subtitle: 'There are no outstanding balances in your ledger.', action: 'Back to home', onTap: () => setState(() => _tab = 0))
        else
          ...sorted.map((entry) => Container(
            margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              CircleAvatar(backgroundColor: const Color(0xFFEAE7FF),
                child: Text(entry.key.isEmpty ? '?' : entry.key[0].toUpperCase(),
                  style: const TextStyle(color: Color(0xFF5146C8), fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600))),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_format(entry.value.abs()), style: TextStyle(fontWeight: FontWeight.w700,
                  color: entry.value > 0 ? const Color(0xFF2E6B4E) : const Color(0xFF9B4A3C))),
                Text(entry.value > 0 ? 'gets back' : 'owes',
                  style: const TextStyle(color: Color(0xFF85877F), fontSize: 11)),
              ]),
            ]),
          )),
        if (transfers.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Suggested settlements', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...transfers.map((transfer) => Container(
            margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${transfer.from} pays ${transfer.to}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text(_format(transfer.amountMinor), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Align(alignment: Alignment.centerRight, child: TextButton(
                onPressed: () => _confirmSettlement(transfer), child: const Text('Mark as paid'))),
            ]),
          )),
        ],
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFFEAE7FF), borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('All-time spending', style: TextStyle(color: Color(0xFF625A9B), fontSize: 12)),
            const SizedBox(height: 6),
            Text(_format(_spent), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: Color(0xFF5146C8))),
            Text('${_expenses.length} expenses recorded', style: const TextStyle(color: Color(0xFF625A9B), fontSize: 12)),
          ])),
      ]);
    },
  );

  Future<void> _confirmSettlement(Transfer transfer) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Record settlement?'),
      content: Text('Confirm that ${transfer.from} has paid ${transfer.to} ${_format(transfer.amountMinor)} outside EVEN. This records the payment; it does not move money.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm paid')),
      ],
    ));
    if (confirmed != true) return;
    await _repo.recordSettlement(fromPerson: transfer.from, toPerson: transfer.to, amountMinor: transfer.amountMinor);
    if (!mounted) return;
    await _refresh();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settlement recorded.')));
  }
  Widget _settingsPage() => ListView(padding: const EdgeInsets.all(22), children: [
    const SizedBox(height: 8),
    const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
    const SizedBox(height: 6),
    const Text('Make Even feel like yours.', style: TextStyle(color: Color(0xFF85877F))),
    const SizedBox(height: 24),
    _settingTile(Icons.currency_rupee_rounded, 'Currency', 'Indian Rupee (INR)', () => _showSettingInfo('Currency', 'Even currently records all expenses in Indian Rupees (₹). Currency conversion is not enabled, so changing this would risk misrepresenting existing balances.')),
    _settingTile(Icons.palette_outlined, 'Appearance', 'System default', () => _showSettingInfo('Appearance', 'Even follows your Android system appearance in this version.')),
    _settingTile(Icons.lock_outline_rounded, 'Privacy & security', 'Local data on this device', () => _showSettingInfo('Privacy & security', 'Your expenses are stored locally on this device. Cloud accounts and biometric app lock are not configured in this build.')),
    _settingTile(Icons.cloud_outlined, 'Cloud sync', 'Not connected', () => _showSettingInfo('Cloud sync', 'Cloud sync needs a configured backend, account sign-in and security rules. It is not active, and your data is not being uploaded.')),
    _settingTile(Icons.info_outline_rounded, 'About Even', 'Version 1.0.0 · Built for clarity', () => showAboutDialog(context: context, applicationName: 'Even', applicationVersion: '1.0.0', applicationLegalese: 'Split expenses. Settle simply.')),
  ]);
  Widget _settingTile(IconData icon, String title, String subtitle, VoidCallback onTap) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(18),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(
      margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF5148D9)), const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF85877F), fontSize: 11)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF9A9D95)),
      ]),
    )),
  );
  Future<void> _showSettingInfo(String title, String message) async {
    await showModalBottomSheet<void>(context: context, showDragHandle: true, backgroundColor: const Color(0xFFFAF9FF), builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10), Text(message, style: const TextStyle(height: 1.5, color: Color(0xFF666879))),
        const SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it'))),
      ]),
    ));
  }


  Future<List<String>?> _pickPeople(List<String> initial, {List<String> suggestions = const []}) async {
    final selected = initial.toSet();
    final name = TextEditingController();
    final result = await showModalBottomSheet<List<String>>(
      context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true,
      backgroundColor: const Color(0xFFF7F7FB),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final candidates = <String>{'You', ...suggestions, ...selected}.toList();
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose people', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF191B2E))),
            const SizedBox(height: 5), const Text('Tap to add or remove someone from this expense.', style: TextStyle(color: Color(0xFF777C91), fontSize: 13)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: candidates.map((person) => FilterChip(
              selected: selected.contains(person), label: Text(person == 'You' ? 'You' : person),
              avatar: CircleAvatar(radius: 12, child: Text(person.isEmpty ? '?' : person[0].toUpperCase(), style: const TextStyle(fontSize: 10))),
              onSelected: (value) => setSheet(() { if (value) { selected.add(person); } else if (person != 'You') { selected.remove(person); } }),
            )).toList()),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Add a person', prefixIcon: Icon(Icons.person_add_alt_1_rounded)))),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: () { final value = name.text.trim(); if (value.isNotEmpty && value.toLowerCase() != 'you') { setSheet(() { selected.add(value); name.clear(); }); } }, icon: const Icon(Icons.add_rounded)),
            ]),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => Navigator.pop(ctx, ['You', ...selected.where((e) => e != 'You')]),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5148D9), padding: const EdgeInsets.all(16)),
              child: Text('Done · ${selected.length} selected'),
            )),
          ]),
        );
      }),
    );
    name.dispose();
    return result;
  }

  Future<SplitMethod?> _chooseSplitMethod(SplitMethod current) => showModalBottomSheet<SplitMethod>(
    context: context, useSafeArea: true, showDragHandle: true, backgroundColor: const Color(0xFFF7F7FB),
    builder: (ctx) => Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Align(alignment: Alignment.centerLeft, child: Text('Split method', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF191B2E)))),
      const SizedBox(height: 14),
      ...[
        (SplitMethod.equal, Icons.people_alt_outlined, 'Equally', 'Everyone pays the same amount'),
        (SplitMethod.exact, Icons.currency_rupee_rounded, 'Exact amounts', 'Set each person’s amount'),
        (SplitMethod.percentage, Icons.percent_rounded, 'By percentage', 'Assign a percentage to each person'),
        (SplitMethod.shares, Icons.tune_rounded, 'By shares', 'Use weighted shares such as 2:1:1'),
      ].map((option) {
        final selected = current == option.$1;
        return Padding(padding: const EdgeInsets.only(bottom: 9), child: Material(
          color: selected ? const Color(0xFFEAE9FF) : Colors.white, borderRadius: BorderRadius.circular(18),
          child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () => Navigator.pop(ctx, option.$1), child: Container(
            padding: const EdgeInsets.all(15), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? const Color(0xFF5148D9) : const Color(0xFFE5E5EF), width: selected ? 1.5 : 1)),
            child: Row(children: [
              CircleAvatar(backgroundColor: const Color(0xFFE2E0FF), child: Icon(option.$2, color: const Color(0xFF5148D9))),
              const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(option.$3, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF191B2E))),
                const SizedBox(height: 3), Text(option.$4, style: const TextStyle(fontSize: 12, color: Color(0xFF777C91))),
              ])),
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? const Color(0xFF5148D9) : const Color(0xFF777C91)),
            ]),
          )),
        ));
      }),
    ])),
  );

  Future<void> _showAddGroup() async {
    final name = TextEditingController();
    final result = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, backgroundColor: const Color(0xFFFAF9FF), builder: (ctx) => Padding(padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.of(ctx).viewInsets.bottom + 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD5D6CF), borderRadius: BorderRadius.circular(4))),), const SizedBox(height: 22), const Text('New group', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)), const SizedBox(height: 18), TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Group name', hintText: 'e.g. Goa trip')), const SizedBox(height: 12), const Text('Add members after creating the group from the people picker.', style: TextStyle(color: Color(0xFF777C91), fontSize: 12)), const SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton(onPressed: () { if (name.text.trim().isNotEmpty) Navigator.pop(ctx, true); }, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5146C8), padding: const EdgeInsets.all(16)), child: const Text('Create group')))])));
    if (result == true) { await _repo.addGroup(name.text, const []); await _refresh(); }
    name.dispose();
  }

  Future<void> _showAddExpense({String? initialGroupId}) async {
    final title = TextEditingController();
    final amount = TextEditingController();
    List<String> selectedPeople = ['You'];
    final splitValues = TextEditingController();
    final splitEntryControllers = <String, TextEditingController>{};
    String paidBy = 'You';
    String? groupId = initialGroupId;
    if (initialGroupId != null) { final group = _groups.firstWhere((g) => g.id == initialGroupId); selectedPeople = [...group.members]; if (!selectedPeople.contains('You')) selectedPeople.insert(0, 'You'); }
    SplitMethod splitMethod = SplitMethod.equal;
    List<SplitInput>? preparedInputs;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9FF),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, localSet) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            20,
            22,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5D6CF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Add expense',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'What was it for?',
                    hintText: 'Dinner, groceries, taxi…',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Total amount',
                    prefixText: '₹  ',
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE9E6F5))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Expanded(child: Text('People in this expense', style: TextStyle(fontWeight: FontWeight.w700))), Text('${selectedPeople.length} selected', style: const TextStyle(color: Color(0xFF777C91), fontSize: 12))]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 7, runSpacing: 7, children: selectedPeople.map((person) => InputChip(
                      label: Text(person), onDeleted: person == 'You' ? null : () => localSet(() { selectedPeople.remove(person); if (paidBy == person) paidBy = selectedPeople.first; }),
                      backgroundColor: const Color(0xFFEAE9FF), deleteIconColor: const Color(0xFF5148D9),
                    )).toList()),
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                      onPressed: () async {
                        final suggestions = _groups.expand((g) => g.members).toSet().toList();
                        final chosen = await _pickPeople(selectedPeople, suggestions: suggestions);
                        if (chosen != null && chosen.isNotEmpty) localSet(() => selectedPeople = chosen);
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add or remove people'),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPeople.contains(paidBy) ? paidBy : selectedPeople.first,
                  decoration: const InputDecoration(labelText: 'Who paid?'),
                  items: selectedPeople.map((person) => DropdownMenuItem(value: person, child: Text(person))).toList(),
                  onChanged: (value) => localSet(() => paidBy = value ?? 'You'),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.white, borderRadius: BorderRadius.circular(18),
                  child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () async {
                    final chosen = await _chooseSplitMethod(splitMethod);
                    if (chosen != null) localSet(() { splitMethod = chosen; splitValues.clear(); for (final person in selectedPeople) { splitEntryControllers.putIfAbsent(person, () => TextEditingController()); } });
                  }, child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
                    const Icon(Icons.tune_rounded, color: Color(0xFF5148D9)), const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Split method', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(switch (splitMethod) { SplitMethod.equal => 'Equally', SplitMethod.exact => 'Exact amounts', SplitMethod.percentage => 'By percentage', SplitMethod.shares => 'By shares' }, style: const TextStyle(fontSize: 12, color: Color(0xFF777C91))),
                    ])),
                    const Icon(Icons.chevron_right_rounded),
                  ]))),
                ),
                if (splitMethod != SplitMethod.equal) ...[
                  const SizedBox(height: 12),
                  const Text('Set each person’s share', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...selectedPeople.map((person) {
                    final controller = splitEntryControllers.putIfAbsent(person, () => TextEditingController());
                    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                      Expanded(child: Text(person, style: const TextStyle(fontWeight: FontWeight.w600))),
                      SizedBox(width: 132, child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                        decoration: InputDecoration(
                          isDense: true,
                          prefixText: splitMethod == SplitMethod.exact ? '₹ ' : null,
                          suffixText: splitMethod == SplitMethod.percentage ? '%' : null,
                          hintText: splitMethod == SplitMethod.shares ? 'Shares' : '0.00',
                        ),
                      )),
                    ]));
                  }),
                  const Text('The total must equal the expense amount (or 100% for percentages).', style: TextStyle(color: Color(0xFF777C91), fontSize: 11)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final amountMinor = parseRupeesToPaise(amount.text);
                      final participantIds = [...selectedPeople];
                      if (!participantIds.contains('You')) {
                        participantIds.insert(0, 'You');
                      }
                      if (title.text.trim().isEmpty ||
                          amountMinor == null ||
                          amountMinor <= 0 ||
                          participantIds.isEmpty ||
                          paidBy.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a description, valid amount, participants and payer.')),
                        );
                        return;
                      }
                      try {
                        if (splitMethod == SplitMethod.equal) {
                          preparedInputs = participantIds.map((id) => SplitInput(personId: id)).toList();
                        } else {
                          preparedInputs = participantIds.map((person) {
                            final value = splitEntryControllers[person]?.text.trim() ?? '';
                            if (value.isEmpty) throw ArgumentError('Enter a split value for $person.');
                            if (splitMethod == SplitMethod.exact) {
                              final parsed = parseRupeesToPaise(value);
                              if (parsed == null) throw ArgumentError('Enter a valid amount for $person.');
                              return SplitInput(personId: person, amountMinor: parsed);
                            }
                            if (splitMethod == SplitMethod.percentage) {
                              final parsed = parseRupeesToPaise(value);
                              if (parsed == null || parsed > 10000) throw ArgumentError('Enter a percentage from 0 to 100 for $person.');
                              return SplitInput(personId: person, percentageBasisPoints: parsed);
                            }
                            final weight = int.tryParse(value);
                            if (weight == null || weight <= 0) throw ArgumentError('Share weights must be positive whole numbers.');
                            return SplitInput(personId: person, weight: weight);
                          }).toList();
                        }
                        SplitEngine.split(
                          totalMinor: amountMinor,
                          participants: preparedInputs!,
                          method: splitMethod,
                        );
                        Navigator.pop(ctx, true);
                      } on ArgumentError catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.message?.toString() ?? 'Check the split values.')),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5146C8),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('Save expense'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
   if (result == true) {
  final amountMinor = parseRupeesToPaise(amount.text);

  if (amountMinor != null && amountMinor > 0) {
    final participants = [...selectedPeople];

    if (!participants.contains('You')) {
      participants.insert(0, 'You');
    }

    if (groupId != null) {
      await _repo.updateGroupMembers(groupId!, participants);
    }
    await _repo.addExpense(
      title: title.text.trim(),
      amountMinor: amountMinor,
      paidBy: paidBy,
      participants: participants,
      groupId: groupId,
      splitMethod: splitMethod,
      splitInputs: preparedInputs,
    );

    await _refresh();
  }
}
    title.dispose(); amount.dispose(); splitValues.dispose(); for (final controller in splitEntryControllers.values) { controller.dispose(); }
  }

}

class _PlacePage extends StatelessWidget {
  const _PlacePage({required this.title, required this.subtitle, required this.icon,
    required this.expenses, required this.format, required this.onAdd, required this.onExpense});
  final String title, subtitle;
  final IconData icon;
  final List<EvenExpense> expenses;
  final String Function(int) format;
  final Future<void> Function() onAdd;
  final Future<void> Function(EvenExpense) onExpense;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    floatingActionButton: FloatingActionButton.extended(onPressed: onAdd,
      backgroundColor: const Color(0xFF5146C8), foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded), label: const Text('Add expense')),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 100), children: [
      Row(children: [CircleAvatar(radius: 25, backgroundColor: const Color(0xFFEAE7FF),
        child: Icon(icon, color: const Color(0xFF5146C8))), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(subtitle, style: const TextStyle(color: Color(0xFF77748F))),
          Text('${expenses.length} transactions', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]))]),
      const SizedBox(height: 22),
      if (expenses.isEmpty) Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22)), child: const Column(children: [
          Icon(Icons.receipt_long_outlined, size: 34), SizedBox(height: 10),
          Text('No expenses here yet', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('Add your first expense using the button below.', textAlign: TextAlign.center),
        ]))
      else ...expenses.map((e) => Card(child: ListTile(
        onTap: () => onExpense(e), leading: const CircleAvatar(backgroundColor: Color(0xFFEAE7FF),
          child: Icon(Icons.receipt_long_rounded, color: Color(0xFF5146C8))),
        title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('Paid by ${e.paidBy} · ${DateFormat('d MMM').format(e.createdAt)}'),
        trailing: Text(format(e.amountMinor), style: const TextStyle(fontWeight: FontWeight.w800)),
      ))),
    ]),
  );
}

