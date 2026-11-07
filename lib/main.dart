import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'data/even_database.dart';
import 'data/even_repository.dart';
import 'domain/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFF7F7F4),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const EvenApp());
}

class EvenApp extends StatelessWidget {
  const EvenApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EVEN', debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true, brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F7F4),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF253D35), brightness: Brightness.light, surface: const Color(0xFFF7F7F4)),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F7F4), surfaceTintColor: Colors.transparent, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: const Color(0xFFF0F0EB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
    home: const EvenHome(),
  );
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
        onPressed: _showAddExpense, backgroundColor: const Color(0xFF253D35), foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded), label: const Text('Add expense', style: TextStyle(fontWeight: FontWeight.w600)),
      ) : null,
      bottomNavigationBar: NavigationBar(
        height: 72, selectedIndex: _tab, backgroundColor: const Color(0xFFF7F7F4), indicatorColor: const Color(0xFFE2E9E2),
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
          const Text('EVEN', style: TextStyle(fontSize: 14, letterSpacing: 3.5, fontWeight: FontWeight.w800, color: Color(0xFF253D35))),
          const SizedBox(height: 5), Text(_greeting(), style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
        ]),
        Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFE8EAE3), shape: BoxShape.circle), child: const Icon(Icons.person_outline_rounded, color: Color(0xFF253D35))),
      ]),
      const SizedBox(height: 26),
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFF253D35), borderRadius: BorderRadius.circular(26)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TOTAL EXPENSES', style: TextStyle(color: Color(0xFFB9C8BE), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(_format(_spent), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.2)),
        const SizedBox(height: 17),
        const Divider(color: Color(0xFF53675D), height: 1),
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.shield_outlined, color: Color(0xFFB9C8BE), size: 16), const SizedBox(width: 8),
          const Expanded(child: Text('Your shared spending, in one place', style: TextStyle(color: Color(0xFFDAE1DB), fontSize: 12))),
          Text('${_expenses.length} entries', style: const TextStyle(color: Color(0xFFDAE1DB), fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ])),
      const SizedBox(height: 28),
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

  String _greeting() { final hour = DateTime.now().hour; return hour < 12 ? 'Good morning.' : hour < 17 ? 'Good afternoon.' : 'Good evening.'; }
  Widget _sectionHeader(String title, {String? action, VoidCallback? onTap}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.4)), if (action != null) TextButton(onPressed: onTap, child: Text(action, style: const TextStyle(color: Color(0xFF456B58), fontWeight: FontWeight.w600)))]);
  Widget _emptyCard({required IconData icon, required String title, required String subtitle, required String action, required VoidCallback onTap}) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECECE6))), child: Column(children: [Icon(icon, size: 28, color: const Color(0xFF6F8275)), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF85877F), fontSize: 12, height: 1.4)), const SizedBox(height: 10), TextButton(onPressed: onTap, child: Text(action, style: const TextStyle(color: Color(0xFF456B58), fontWeight: FontWeight.w700)))]));
  Widget _groupTile(EvenGroup group) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19)), child: Row(children: [Container(width: 43, height: 43, decoration: BoxDecoration(color: _groupColor(group.name), borderRadius: BorderRadius.circular(14)), child: Icon(_groupIcon(group.name), color: const Color(0xFF34483C))), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), const SizedBox(height: 3), Text('${group.members.length} members', style: const TextStyle(color: Color(0xFF85877F), fontSize: 11))])), const Icon(Icons.chevron_right_rounded, color: Color(0xFF9A9D95))]));
  Color _groupColor(String name) { final n = name.toLowerCase(); if (n.contains('trip') || n.contains('travel')) return const Color(0xFFECE8DB); if (n.contains('home') || n.contains('flat')) return const Color(0xFFE5EBE4); return const Color(0xFFEAE7EF); }
  IconData _groupIcon(String name) { final n = name.toLowerCase(); if (n.contains('trip') || n.contains('travel')) return Icons.flight_rounded; if (n.contains('home') || n.contains('flat')) return Icons.home_rounded; return Icons.group_rounded; }
  Widget _expenseTile(EvenExpense expense) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF0F0EB), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.receipt_outlined, color: Color(0xFF53675D), size: 19)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(height: 3), Text(DateFormat('d MMM · h:mm a').format(expense.createdAt), style: const TextStyle(color: Color(0xFF8A8C84), fontSize: 10))])), Text(_format(expense.amountMinor), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]));

  Widget _activityPage() => ListView(padding: const EdgeInsets.all(22), children: [const SizedBox(height: 8), const Text('Activity', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)), const SizedBox(height: 6), const Text('Every shared expense, in order.', style: TextStyle(color: Color(0xFF85877F))), const SizedBox(height: 24), if (_expenses.isEmpty) _emptyCard(icon: Icons.receipt_long_outlined, title: 'Your activity starts here', subtitle: 'Expenses you add will appear here.', action: 'Add expense', onTap: _showAddExpense) else ..._expenses.map(_expenseTile)]);
  Widget _insightsPage() => ListView(padding: const EdgeInsets.all(22), children: [const SizedBox(height: 8), const Text('Insights', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)), const SizedBox(height: 6), const Text('A clearer picture of shared spending.', style: TextStyle(color: Color(0xFF85877F))), const SizedBox(height: 24), Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('All-time spending', style: TextStyle(color: Color(0xFF85877F), fontSize: 12)), const SizedBox(height: 8), Text(_format(_spent), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text('${_expenses.length} expenses recorded', style: const TextStyle(color: Color(0xFF85877F), fontSize: 12))])), const SizedBox(height: 14), _emptyCard(icon: Icons.auto_graph_rounded, title: 'More insight, less guesswork', subtitle: 'Category breakdowns and spending trends are part of the next analytics milestone.', action: 'Back to home', onTap: () => setState(() => _tab = 0))]);
  Widget _settingsPage() => ListView(padding: const EdgeInsets.all(22), children: [const SizedBox(height: 8), const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)), const SizedBox(height: 6), const Text('Make EVEN feel like yours.', style: TextStyle(color: Color(0xFF85877F))), const SizedBox(height: 24), _settingTile(Icons.currency_rupee_rounded, 'Currency', 'Indian Rupee (INR)'), _settingTile(Icons.palette_outlined, 'Appearance', 'System default'), _settingTile(Icons.lock_outline_rounded, 'Privacy & security', 'Coming in a future update'), _settingTile(Icons.cloud_outlined, 'Cloud sync', 'Not connected yet'), _settingTile(Icons.info_outline_rounded, 'About EVEN', 'Version 1.0.0 · Built for clarity')]);
  Widget _settingTile(IconData icon, String title, String subtitle) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)), child: Row(children: [Icon(icon, color: const Color(0xFF53675D)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF85877F), fontSize: 11))])), const Icon(Icons.chevron_right_rounded, color: Color(0xFF9A9D95))]));

  Future<void> _showAddGroup() async {
    final name = TextEditingController(); final members = TextEditingController();
    final result = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, backgroundColor: const Color(0xFFF7F7F4), builder: (ctx) => Padding(padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.of(ctx).viewInsets.bottom + 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD5D6CF), borderRadius: BorderRadius.circular(4))),), const SizedBox(height: 22), const Text('New group', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)), const SizedBox(height: 18), TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Group name', hintText: 'e.g. Goa trip')), const SizedBox(height: 12), TextField(controller: members, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'People', hintText: 'Aditi, Rohan (comma separated)')), const SizedBox(height: 8), const Text('You are automatically included.', style: TextStyle(color: Color(0xFF85877F), fontSize: 11)), const SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton(onPressed: () { if (name.text.trim().isNotEmpty) Navigator.pop(ctx, true); }, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF253D35), padding: const EdgeInsets.all(16)), child: const Text('Create group')))])));
    if (result == true) { final people = members.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(); await _repo.addGroup(name.text, people); await _refresh(); }
    name.dispose(); members.dispose();
  }

  Future<void> _showAddExpense() async {
    final title = TextEditingController(); final amount = TextEditingController(); final people = TextEditingController(text: 'You');
    String? groupId; String paidBy = 'You';
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F7F4),
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
                DropdownButtonFormField<String?>(
                  value: groupId,
                  decoration: const InputDecoration(labelText: 'Group (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Personal expense'),
                    ),
                    ..._groups.map(
                      (group) => DropdownMenuItem<String?>(
                        value: group.id,
                        child: Text(group.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => localSet(() => groupId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: people,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Split between',
                    hintText: 'You, Aditi, Rohan',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paidBy,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  items: const [
                    DropdownMenuItem(value: 'You', child: Text('You')),
                  ],
                  onChanged: (value) => localSet(() => paidBy = value ?? 'You'),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final validAmount = double.tryParse(amount.text) ?? 0;
                      if (title.text.trim().isNotEmpty &&
                          validAmount > 0 &&
                          people.text.trim().isNotEmpty) {
                        Navigator.pop(ctx, true);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF253D35),
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
      final parsed = double.parse(amount.text);
      final participants = people.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
      if (!participants.contains('You')) participants.insert(0, 'You');
      await _repo.addExpense(title: title.text, amountMinor: (parsed * 100).round(), paidBy: paidBy, participants: participants, groupId: groupId);
      await _refresh();
    }
    title.dispose(); amount.dispose(); people.dispose();
  }
}
