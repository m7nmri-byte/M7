import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final store = AppStore();
  await store.init();
  runApp(ChangeNotifierProvider.value(value: store, child: const QiyadaApp()));
}

// ── THEME ──────────────────────────────────────────────
const _bg = Color(0xFF0D1117);
const _surface = Color(0xFF161B22);
const _surface2 = Color(0xFF21262D);
const _border = Color(0xFF30363D);
const _text = Color(0xFFE6EDF3);
const _muted = Color(0xFF8B949E);
const _accent = Color(0xFF7C5CBF);
const _accentL = Color(0xFFA78BFA);
const _critical = Color(0xFFF85149);
const _high = Color(0xFFF0883E);
const _normal = Color(0xFF58A6FF);
const _low = Color(0xFF3FB950);
const _followup = Color(0xFFBC8CFF);

Color hexColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

Color priorityColor(String p) {
  switch (p) {
    case 'critical': return _critical;
    case 'high':     return _high;
    case 'normal':   return _normal;
    case 'low':      return _low;
    default:         return _muted;
  }
}

String priorityLabel(String p) {
  switch (p) {
    case 'critical': return 'حرج';
    case 'high':     return 'عالي';
    case 'normal':   return 'عادي';
    case 'low':      return 'منخفض';
    default:         return p;
  }
}

String timingLabel(String t) {
  switch (t) {
    case 'today':     return 'اليوم';
    case 'scheduled': return 'مجدول';
    case 'someday':   return 'لاحقاً';
    case 'followup':  return 'متابعة';
    default:          return t;
  }
}

Color timingColor(String t) {
  switch (t) {
    case 'today':     return _high;
    case 'scheduled': return _normal;
    case 'someday':   return _muted;
    case 'followup':  return _followup;
    default:          return _muted;
  }
}

String fmtDate(String d) {
  if (d.isEmpty) return '';
  final today = DateTime.now();
  final todayStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
  if (d == todayStr) return 'اليوم';
  final dt = DateTime.tryParse(d);
  if (dt == null) return d;
  final diff = dt.difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff == -1) return 'أمس';
  if (diff == 1)  return 'غداً';
  if (diff < 0)   return 'منذ ${diff.abs()} أيام';
  if (diff <= 7)  return 'بعد $diff أيام';
  return '${dt.day}/${dt.month}/${dt.year}';
}

const _srcColors = [
  '#58a6ff','#3fb950','#f0883e','#f85149',
  '#bc8cff','#e3b341','#79c0ff','#56d364',
  '#ffa657','#ff7b72',
];

// ── APP ────────────────────────────────────────────────
class QiyadaApp extends StatelessWidget {
  const QiyadaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'مركز القيادة',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(surface: _bg),
          scaffoldBackgroundColor: _bg,
          fontFamily: 'Arial',
        ),
        home: const HomeShell(),
      );
}

// ── NAV SECTION ────────────────────────────────────────
enum NavSection { dashboard, tasks, followup, sources, policies, dump }

// ── HOME SHELL ─────────────────────────────────────────
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  NavSection _nav = NavSection.dashboard;
  String? _filtSourceId;
  String? _filtPerson;

  void _goSection(NavSection s, {String? sourceId, String? person}) {
    setState(() {
      _nav = s;
      _filtSourceId = sourceId;
      _filtPerson = person;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: Row(
          children: [
            _Sidebar(current: _nav, filtSourceId: _filtSourceId, filtPerson: _filtPerson, onNav: _goSection, store: store),
            Expanded(child: _buildMain(store)),
          ],
        ),
      ),
    );
  }

  Widget _buildMain(AppStore store) {
    switch (_nav) {
      case NavSection.dashboard:  return DashboardView(onNav: _goSection);
      case NavSection.tasks:      return TasksView(filtSourceId: _filtSourceId, filtPerson: _filtPerson, onNav: _goSection);
      case NavSection.followup:   return FollowupView(filtPerson: _filtPerson);
      case NavSection.sources:    return SourcesView(onNav: _goSection);
      case NavSection.policies:   return PoliciesView();
      case NavSection.dump:       return DumpView();
    }
  }
}

// ── SIDEBAR ────────────────────────────────────────────
class _Sidebar extends StatefulWidget {
  final NavSection current;
  final String? filtSourceId, filtPerson;
  final void Function(NavSection, {String? sourceId, String? person}) onNav;
  final AppStore store;
  const _Sidebar({required this.current, this.filtSourceId, this.filtPerson, required this.onNav, required this.store});
  @override State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  bool _peopleOpen = false;
  bool _sourcesOpen = true;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final activeTasks = store.activeTasks();
    final fuCount = store.followupCount();
    final people = store.allPeople();
    final roots = store.rootSources();

    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(left: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('مركز القيادة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _accentL)),
              const SizedBox(height: 2),
              const Text('نظّم ذهنك، أنجز أكثر', style: TextStyle(fontSize: 11, color: _muted)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              children: [
                _NavTile(icon: Icons.home_outlined, label: 'لوحة التحكم', active: widget.current == NavSection.dashboard, onTap: () => widget.onNav(NavSection.dashboard)),
                _NavTile(icon: Icons.check_box_outlined, label: 'كل المهام', badge: activeTasks > 0 ? '$activeTasks' : null,
                    active: widget.current == NavSection.tasks && widget.filtSourceId == null && widget.filtPerson == null,
                    onTap: () => widget.onNav(NavSection.tasks)),
                _NavTile(icon: Icons.refresh, label: 'المتابعة', badge: fuCount > 0 ? '$fuCount' : null,
                    active: widget.current == NavSection.followup && widget.filtPerson == null,
                    onTap: () => widget.onNav(NavSection.followup)),

                // People section
                const _SidebarDivider(),
                GestureDetector(
                  onTap: () => setState(() => _peopleOpen = !_peopleOpen),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(children: [
                      const Text('أشخاص', style: TextStyle(fontSize: 10, color: _muted, fontWeight: FontWeight.w600, letterSpacing: .5)),
                      const Spacer(),
                      Icon(_peopleOpen ? Icons.expand_less : Icons.expand_more, size: 14, color: _muted),
                    ]),
                  ),
                ),
                if (_peopleOpen)
                  if (people.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text('لا يوجد أشخاص بعد', style: TextStyle(fontSize: 11.5, color: _muted)),
                    )
                  else
                    ...people.map((p) => _NavTile(
                          icon: Icons.person_outline,
                          label: p,
                          indent: true,
                          active: widget.filtPerson == p && widget.current == NavSection.tasks,
                          activeColor: _followup,
                          onTap: () => widget.onNav(NavSection.tasks, person: p),
                        )),

                // Sources section
                const _SidebarDivider(),
                GestureDetector(
                  onTap: () => setState(() => _sourcesOpen = !_sourcesOpen),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(children: [
                      const Text('الجهات', style: TextStyle(fontSize: 10, color: _muted, fontWeight: FontWeight.w600, letterSpacing: .5)),
                      const Spacer(),
                      Icon(_sourcesOpen ? Icons.expand_less : Icons.expand_more, size: 14, color: _muted),
                    ]),
                  ),
                ),
                if (_sourcesOpen) ...[
                  if (roots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text('لا توجد جهات', style: TextStyle(fontSize: 11.5, color: _muted)),
                    )
                  else
                    ..._buildSourceTree(roots, store, 0),
                ],

                const _SidebarDivider(),
                _NavTile(icon: Icons.shield_outlined, label: 'سياساتي', active: widget.current == NavSection.policies, onTap: () => widget.onNav(NavSection.policies)),
                _NavTile(icon: Icons.edit_note, label: 'تفريغ الذهن', active: widget.current == NavSection.dump, onTap: () => widget.onNav(NavSection.dump)),
                _NavTile(icon: Icons.account_tree_outlined, label: 'إدارة الجهات', active: widget.current == NavSection.sources, onTap: () => widget.onNav(NavSection.sources)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => showDialog(context: context, builder: (_) => TaskFormDialog(task: store.buildNewTask())),
                style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('+ مهمة جديدة', style: TextStyle(fontSize: 13.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSourceTree(List<Source> sources, AppStore store, int depth) {
    final result = <Widget>[];
    for (final s in sources) {
      final color = hexColor(s.color);
      result.add(_NavTile(
        icon: Icons.circle,
        iconColor: color,
        iconSize: 8,
        label: s.name,
        indent: true,
        indentLevel: depth,
        active: widget.filtSourceId == s.id && widget.current == NavSection.tasks,
        activeColor: color,
        onTap: () => widget.onNav(NavSection.tasks, sourceId: s.id),
      ));
      final children = store.childrenOf(s.id);
      if (children.isNotEmpty) result.addAll(_buildSourceTree(children, store, depth + 1));
    }
    return result;
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();
  @override
  Widget build(BuildContext context) => const Divider(color: _border, height: 16, thickness: .5);
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool active, indent;
  final Color? activeColor, iconColor;
  final double? iconSize;
  final int indentLevel;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon, required this.label, required this.active, required this.onTap,
    this.badge, this.indent = false, this.activeColor, this.iconColor, this.iconSize, this.indentLevel = 0,
  });

  @override
  Widget build(BuildContext context) {
    final aColor = activeColor ?? _accentL;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: EdgeInsets.only(bottom: 2, right: indent ? (16.0 + indentLevel * 12) : 0),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: active ? aColor.withOpacity(.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(icon, size: iconSize ?? 16, color: active ? aColor : (iconColor ?? _muted)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: active ? aColor : _muted, fontWeight: active ? FontWeight.w500 : FontWeight.normal), overflow: TextOverflow.ellipsis)),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: _critical, borderRadius: BorderRadius.circular(10)),
              child: Text(badge!, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ]),
      ),
    );
  }
}

// ── TOPBAR ─────────────────────────────────────────────
class _Topbar extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  const _Topbar({required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: const BoxDecoration(color: _bg, border: Border(bottom: BorderSide(color: _border))),
        child: Row(children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _text)),
          const Spacer(),
          ...actions,
        ]),
      );
}

// ── DASHBOARD VIEW ─────────────────────────────────────
class DashboardView extends StatelessWidget {
  final void Function(NavSection, {String? sourceId, String? person}) onNav;
  const DashboardView({super.key, required this.onNav});

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final today = _todayStr;
    final active = store.tasks.where((t) => !t.isDone).toList();
    final overdue = active.where((t) => t.isOverdue).toList();
    final todayTasks = active.where((t) => t.timing == 'today' && !t.isOverdue).toList();
    final doneToday = store.tasks.where((t) => t.isDone && t.completedAt == today).toList();
    final fuCount = store.followupCount();
    final urgent = [...todayTasks, ...active.where((t) => t.priority == 'critical' && t.timing != 'today' && !t.isOverdue)]
      ..sort((a, b) => _pOrd(a.priority) - _pOrd(b.priority));

    final now = DateTime.now();
    final greet = now.hour < 12 ? 'صباح الخير' : now.hour < 17 ? 'مساء الخير' : 'مساء النور';
    final pol = store.policies.isNotEmpty ? store.policies.first : null;

    return Column(children: [
      _Topbar(title: 'لوحة التحكم', actions: [
        ElevatedButton(
          onPressed: () => showDialog(context: context, builder: (_) => TaskFormDialog(task: store.buildNewTask())),
          style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('+ مهمة'),
        ),
      ]),
      Expanded(child: ListView(padding: const EdgeInsets.all(22), children: [
        // Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_accent.withOpacity(.18), _normal.withOpacity(.08)]),
            border: Border.all(color: _accent.withOpacity(.25)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greet, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _text)),
              Text('${now.day}/${now.month}/${now.year}', style: const TextStyle(fontSize: 12, color: _muted)),
            ]),
            const Spacer(),
            Column(children: [
              Text('${doneToday.length}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _low)),
              const Text('أنجزت اليوم', style: TextStyle(fontSize: 11, color: _muted)),
            ]),
          ]),
        ),
        // Stats grid
        GridView.count(
          crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 11, mainAxisSpacing: 11, childAspectRatio: 1.6,
          children: [
            _StatCard(label: 'متأخرة وحرجة', value: '${overdue.length}', color: _critical, onTap: () => onNav(NavSection.tasks)),
            _StatCard(label: 'مهام اليوم', value: '${todayTasks.length}', color: _high, onTap: () => onNav(NavSection.tasks)),
            _StatCard(label: 'قيد المتابعة', value: '$fuCount', color: _followup, onTap: () => onNav(NavSection.followup)),
            _StatCard(label: 'نشطة إجمالاً', value: '${active.length}', color: _low, onTap: () => onNav(NavSection.tasks)),
          ],
        ),
        const SizedBox(height: 18),
        if (pol != null)
          GestureDetector(
            onTap: () => onNav(NavSection.policies),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _followup.withOpacity(.08),
                border: Border.all(color: _followup.withOpacity(.2)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'تذكير: ', style: TextStyle(color: _followup, fontWeight: FontWeight.bold, fontSize: 12.5)),
                TextSpan(text: pol.title, style: const TextStyle(color: _muted, fontSize: 12.5)),
              ])),
            ),
          ),
        if (overdue.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _critical.withOpacity(.05),
              border: Border.all(color: _critical.withOpacity(.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('متأخرة — تحتاج تدخلاً فورياً (${overdue.length})',
                  style: const TextStyle(fontSize: 11.5, color: _critical, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...overdue.map((t) => TaskCard(task: t)),
            ]),
          ),
        ],
        if (urgent.isNotEmpty) ...[
          const _SectionHeader('مهام اليوم والحرجة'),
          ...urgent.map((t) => TaskCard(task: t)),
          const SizedBox(height: 16),
        ] else if (overdue.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                Icon(Icons.check_circle_outline, size: 48, color: _low.withOpacity(.5)),
                const SizedBox(height: 12),
                const Text('لا مهام عاجلة اليوم!', style: TextStyle(fontSize: 15, color: _text)),
              ]),
            ),
          ),
        if (doneToday.isNotEmpty) ...[
          const Divider(color: _border),
          _SectionHeader('أنجزته اليوم (${doneToday.length})'),
          ...doneToday.map((t) => TaskCard(task: t)),
        ],
      ])),
    ]);
  }

  static int _pOrd(String p) {
    switch (p) {
      case 'critical': return 0;
      case 'high': return 1;
      case 'normal': return 2;
      default: return 3;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final VoidCallback onTap;
  const _StatCard({required this.label, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(color: _surface, border: Border.all(color: _border)),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 3, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(label, style: const TextStyle(fontSize: 11.5, color: _muted)),
                      const SizedBox(height: 4),
                      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10.5, color: _muted, fontWeight: FontWeight.w600, letterSpacing: .5)),
      );
}

// ── TASKS VIEW ─────────────────────────────────────────
class TasksView extends StatefulWidget {
  final String? filtSourceId, filtPerson;
  final void Function(NavSection, {String? sourceId, String? person}) onNav;
  const TasksView({super.key, this.filtSourceId, this.filtPerson, required this.onNav});
  @override State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  String _status = 'active', _priority = 'all', _timing = 'all', _ownership = 'all';
  String _srcId = '', _person = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _srcId = widget.filtSourceId ?? '';
    _person = widget.filtPerson ?? '';
  }

  @override
  void didUpdateWidget(TasksView old) {
    super.didUpdateWidget(old);
    if (widget.filtSourceId != old.filtSourceId) setState(() => _srcId = widget.filtSourceId ?? '');
    if (widget.filtPerson != old.filtPerson) setState(() => _person = widget.filtPerson ?? '');
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    var tasks = store.tasks.toList();

    if (_status == 'active') tasks = tasks.where((t) => !t.isDone).toList();
    else if (_status == 'done') tasks = tasks.where((t) => t.isDone).toList();
    if (_priority != 'all') tasks = tasks.where((t) => t.priority == _priority).toList();
    if (_timing != 'all') tasks = tasks.where((t) => t.timing == _timing).toList();
    if (_ownership == 'me') tasks = tasks.where((t) => t.isOnMe).toList();
    else if (_ownership == 'others') tasks = tasks.where((t) => !t.isOnMe).toList();
    if (_srcId.isNotEmpty) tasks = tasks.where((t) => t.sourceId == _srcId || store.isDescendant(t.sourceId, _srcId)).toList();
    if (_person.isNotEmpty) tasks = tasks.where((t) => t.allPeople.contains(_person)).toList();
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) tasks = tasks.where((t) => t.title.toLowerCase().contains(q) || t.description.toLowerCase().contains(q)).toList();
    tasks.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      return ({'critical':0,'high':1,'normal':2,'low':3}[a.priority]??2).compareTo({'critical':0,'high':1,'normal':2,'low':3}[b.priority]??2);
    });

    final people = store.allPeople();
    final srcName = _srcId.isNotEmpty ? (store.sourceById(_srcId)?.name ?? '') : '';
    final title = _person.isNotEmpty ? _person : srcName.isNotEmpty ? srcName : 'كل المهام';

    return Column(children: [
      _Topbar(title: title, actions: [
        ElevatedButton(
          onPressed: () => showDialog(context: context, builder: (_) => TaskFormDialog(task: store.buildNewTask())),
          style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('+ مهمة'),
        ),
      ]),
      Container(
        color: _surface.withOpacity(.5),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Column(children: [
          // Search
          TextField(
            controller: _searchCtrl,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 13.5, color: _text),
            decoration: InputDecoration(
              hintText: 'ابحث في المهام...',
              hintStyle: const TextStyle(color: _muted),
              filled: true, fillColor: _surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accent)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              prefixIcon: const Icon(Icons.search, color: _muted, size: 18),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          // Filter row 1: status + ownership + dropdowns
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('النشطة', _status == 'active', () => setState(() => _status = 'active')),
              _chip('المنجزة', _status == 'done', () => setState(() => _status = 'done')),
              _chip('الكل', _status == 'all', () => setState(() => _status = 'all')),
              const SizedBox(width: 8),
              _chip('مهامي', _ownership == 'me', () => setState(() => _ownership = _ownership == 'me' ? 'all' : 'me')),
              _chip('على غيري', _ownership == 'others', () => setState(() => _ownership = _ownership == 'others' ? 'all' : 'others')),
              const SizedBox(width: 8),
              // Person dropdown
              _buildDropdown(
                label: _person.isNotEmpty ? _person : 'الأشخاص',
                active: _person.isNotEmpty,
                items: [const DropdownMenuItem(value: '', child: Text('كل الأشخاص')),
                  ...people.map((p) => DropdownMenuItem(value: p, child: Text(p)))],
                value: _person,
                onChanged: (v) => setState(() => _person = v ?? ''),
              ),
              const SizedBox(width: 6),
              // Source dropdown
              _buildSourceDropdown(store),
            ]),
          ),
          const SizedBox(height: 4),
          // Filter row 2: priority
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('كل الأولويات', _priority == 'all', () => setState(() => _priority = 'all')),
              _chip('حرج', _priority == 'critical', () => setState(() => _priority = 'critical'), color: _critical),
              _chip('عالي', _priority == 'high', () => setState(() => _priority = 'high'), color: _high),
              _chip('عادي', _priority == 'normal', () => setState(() => _priority = 'normal'), color: _normal),
              _chip('منخفض', _priority == 'low', () => setState(() => _priority = 'low'), color: _low),
              const SizedBox(width: 8),
              _chip('اليوم', _timing == 'today', () => setState(() => _timing = _timing == 'today' ? 'all' : 'today')),
              _chip('مجدول', _timing == 'scheduled', () => setState(() => _timing = _timing == 'scheduled' ? 'all' : 'scheduled')),
              _chip('لاحقاً', _timing == 'someday', () => setState(() => _timing = _timing == 'someday' ? 'all' : 'someday')),
              _chip('متابعة', _timing == 'followup', () => setState(() => _timing = _timing == 'followup' ? 'all' : 'followup')),
            ]),
          ),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: Text('${tasks.length} مهمة', style: const TextStyle(fontSize: 11.5, color: _muted))),
          const SizedBox(height: 4),
        ]),
      ),
      Expanded(
        child: tasks.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox_outlined, size: 48, color: _muted.withOpacity(.4)),
                const SizedBox(height: 12),
                const Text('لا توجد مهام', style: TextStyle(fontSize: 15, color: _text)),
                const Text('جرّب تغيير الفلتر', style: TextStyle(fontSize: 12.5, color: _muted)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (_, i) => TaskCard(task: tasks[i]),
              ),
      ),
    ]);
  }

  Widget _chip(String label, bool active, VoidCallback onTap, {Color? color}) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(left: 6, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: active ? _accent.withOpacity(.18) : Colors.transparent,
            border: Border.all(color: active ? _accent : _border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(fontSize: 12.5, color: active ? (color ?? _accentL) : _muted, fontWeight: active ? FontWeight.w500 : FontWeight.normal)),
        ),
      );

  Widget _buildDropdown({required String label, required bool active, required List<DropdownMenuItem<String>> items, required String value, required void Function(String?) onChanged}) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(left: 6, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: active ? _accent.withOpacity(.18) : Colors.transparent,
          border: Border.all(color: active ? _accent : _border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: DropdownButton<String>(
          value: value,
          isDense: true, underline: const SizedBox(),
          dropdownColor: _surface2,
          style: TextStyle(fontSize: 12.5, color: active ? _accentL : _muted, fontFamily: 'Arial'),
          items: items,
          onChanged: onChanged,
        ),
      );

  Widget _buildSourceDropdown(AppStore store) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('كل الجهات')),
    ];
    void addNode(String parentId, int depth) {
      for (final s in store.childrenOf(parentId)) {
        items.add(DropdownMenuItem(value: s.id, child: Text('${'  ' * depth}${s.name}')));
        addNode(s.id, depth + 1);
      }
    }
    for (final r in store.rootSources()) {
      items.add(DropdownMenuItem(value: r.id, child: Text(r.name)));
      addNode(r.id, 1);
    }
    return _buildDropdown(label: _srcId.isNotEmpty ? (store.sourceById(_srcId)?.name ?? 'جهة') : 'الجهات', active: _srcId.isNotEmpty, items: items, value: _srcId, onChanged: (v) => setState(() => _srcId = v ?? ''));
  }
}

// ── FOLLOWUP VIEW ──────────────────────────────────────
class FollowupView extends StatefulWidget {
  final String? filtPerson;
  const FollowupView({super.key, this.filtPerson});
  @override State<FollowupView> createState() => _FollowupViewState();
}

class _FollowupViewState extends State<FollowupView> {
  String _person = '';

  @override
  void initState() { super.initState(); _person = widget.filtPerson ?? ''; }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    var tasks = store.tasks.where((t) => !t.isDone && t.timing == 'followup').toList();
    final people = [...{...tasks.expand((t) => t.allPeople)}]..sort();
    if (_person.isNotEmpty) tasks = tasks.where((t) => t.allPeople.contains(_person)).toList();
    tasks.sort((a, b) {
      if (a.dueDate.isNotEmpty && b.dueDate.isNotEmpty) return a.dueDate.compareTo(b.dueDate);
      if (a.dueDate.isNotEmpty) return -1;
      if (b.dueDate.isNotEmpty) return 1;
      return 0;
    });

    return Column(children: [
      _Topbar(title: 'مهام المتابعة', actions: [
        ElevatedButton(
          onPressed: () { final t = store.buildNewTask(); showDialog(context: context, builder: (_) => TaskFormDialog(task: t.copyWith(timing: 'followup'))); },
          style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('+ مهمة متابعة'),
        ),
      ]),
      Container(
        color: _surface.withOpacity(.5),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: _followup.withOpacity(.08), border: Border.all(color: _followup.withOpacity(.2)), borderRadius: BorderRadius.circular(8)),
            child: const Text('المهام المُسندة لأشخاص آخرين أو التي تتابع تنفيذها', style: TextStyle(fontSize: 12.5, color: _muted)),
          ),
          if (people.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('الجميع', _person.isEmpty, () => setState(() => _person = '')),
                ...people.map((p) => _chip(p, _person == p, () => setState(() => _person = p))),
              ]),
            ),
        ]),
      ),
      Expanded(
        child: tasks.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.refresh, size: 48, color: _muted.withOpacity(.4)),
                const SizedBox(height: 12),
                const Text('لا توجد مهام متابعة', style: TextStyle(fontSize: 15, color: _text)),
                const Text('أضف مهمة واختر "متابعة" أو أسندها لشخص', style: TextStyle(fontSize: 12.5, color: _muted)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (_, i) => TaskCard(task: tasks[i]),
              ),
      ),
    ]);
  }

  Widget _chip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: active ? _followup.withOpacity(.18) : Colors.transparent,
            border: Border.all(color: active ? _followup : _border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: TextStyle(fontSize: 12.5, color: active ? _followup : _muted, fontWeight: active ? FontWeight.w500 : FontWeight.normal)),
        ),
      );
}

// ── SOURCES VIEW ───────────────────────────────────────
class SourcesView extends StatelessWidget {
  final void Function(NavSection, {String? sourceId, String? person}) onNav;
  const SourcesView({super.key, required this.onNav});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Column(children: [
      _Topbar(title: 'إدارة الجهات', actions: [
        ElevatedButton(
          onPressed: () => showDialog(context: context, builder: (_) => SourceFormDialog(source: store.buildNewSource())),
          style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('+ جهة جديدة'),
        ),
      ]),
      Expanded(
        child: store.sources.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.account_tree_outlined, size: 48, color: _muted.withOpacity(.4)),
                const SizedBox(height: 12),
                const Text('لا توجد جهات', style: TextStyle(fontSize: 15, color: _text)),
              ]))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: store.rootSources().map((s) => _SourceNode(source: s, depth: 0, store: store, onNav: onNav)).toList(),
              ),
      ),
    ]);
  }
}

class _SourceNode extends StatelessWidget {
  final Source source;
  final int depth;
  final AppStore store;
  final void Function(NavSection, {String? sourceId, String? person}) onNav;
  const _SourceNode({required this.source, required this.depth, required this.store, required this.onNav});

  @override
  Widget build(BuildContext context) {
    final children = store.childrenOf(source.id);
    final color = hexColor(source.color);
    final cnt = store.tasks.where((t) => !t.isDone && t.sourceId == source.id).length;
    final totalCnt = store.tasks.where((t) => !t.isDone && (t.sourceId == source.id || store.isDescendant(t.sourceId, source.id))).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => onNav(NavSection.tasks, sourceId: source.id),
        child: Container(
          margin: EdgeInsets.only(right: depth * 20.0, bottom: 7),
          decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(10)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: depth == 0 ? 3 : 2, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(source.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: _text)),
                        Text('$cnt مهمة نشطة${totalCnt > cnt ? " ($totalCnt شاملاً التفرعات)" : ""}',
                            style: const TextStyle(fontSize: 11.5, color: _muted)),
                      ])),
                      OutlinedButton(
                        onPressed: () => showDialog(context: context, builder: (_) => SourceFormDialog(source: store.buildNewSource(parentId: source.id))),
                        style: OutlinedButton.styleFrom(foregroundColor: _muted, side: const BorderSide(color: _border), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, textStyle: const TextStyle(fontSize: 11)),
                        child: const Text('+ تفرع'),
                      ),
                      const SizedBox(width: 6),
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 16), color: _muted, padding: const EdgeInsets.all(4), constraints: const BoxConstraints(), onPressed: () => showDialog(context: context, builder: (_) => SourceFormDialog(source: source))),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 16), color: _critical, padding: const EdgeInsets.all(4), constraints: const BoxConstraints(), onPressed: () async {
                        final ok = await showDialog<bool>(context: context, builder: (_) => _ConfirmDlg(title: 'حذف الجهة', msg: 'حذف "${source.name}"؟ التفرعات والمهام ستصبح بدون جهة.'));
                        if (ok == true && context.mounted) context.read<AppStore>().deleteSource(source.id);
                      }),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      ...children.map((c) => _SourceNode(source: c, depth: depth + 1, store: store, onNav: onNav)),
    ]);
  }
}

// ── POLICIES VIEW ──────────────────────────────────────
class PoliciesView extends StatelessWidget {
  const PoliciesView({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Column(children: [
      _Topbar(title: 'سياساتي الشخصية', actions: [
        ElevatedButton(
          onPressed: () => showDialog(context: context, builder: (_) => PolicyFormDialog(policy: store.buildNewPolicy())),
          style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('+ سياسة جديدة'),
        ),
      ]),
      Expanded(
        child: store.policies.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shield_outlined, size: 48, color: _muted.withOpacity(.4)),
                const SizedBox(height: 12),
                const Text('لا توجد سياسات', style: TextStyle(fontSize: 15, color: _text)),
              ]))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 320, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: 1.2),
                itemCount: store.policies.length,
                itemBuilder: (_, i) {
                  final p = store.policies[i];
                  return Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: _surface, border: Border.all(color: _border), borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(p.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _accentL))),
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 15), color: _muted, padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => showDialog(context: context, builder: (_) => PolicyFormDialog(policy: p))),
                        IconButton(icon: const Icon(Icons.delete_outline, size: 15), color: _critical, padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () async {
                          final ok = await showDialog<bool>(context: context, builder: (_) => _ConfirmDlg(title: 'حذف', msg: 'حذف "${p.title}"؟'));
                          if (ok == true && context.mounted) context.read<AppStore>().deletePolicy(p.id);
                        }),
                      ]),
                      const SizedBox(height: 6),
                      Expanded(child: Text(p.body, style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.6), overflow: TextOverflow.fade)),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}

// ── DUMP VIEW ──────────────────────────────────────────
class DumpView extends StatefulWidget {
  const DumpView({super.key});
  @override State<DumpView> createState() => _DumpViewState();
}

class _DumpViewState extends State<DumpView> {
  final _ctrl = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Column(children: [
      const _Topbar(title: 'تفريغ الذهن'),
      Expanded(child: ListView(padding: const EdgeInsets.all(22), children: [
        const Text('أفرغ ذهنك هنا — اكتب أي شيء يشغلك', style: TextStyle(fontSize: 12.5, color: _muted)),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          textDirection: TextDirection.rtl,
          maxLines: 4,
          style: const TextStyle(color: _text, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'اكتب هنا...',
            hintStyle: const TextStyle(color: _muted),
            filled: true, fillColor: _surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent)),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          ElevatedButton(
            onPressed: () { final txt = _ctrl.text.trim(); if (txt.isEmpty) return; store.addDump(txt); _ctrl.clear(); },
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('حفظ'),
          ),
          const SizedBox(width: 8),
          if (store.dumps.isNotEmpty)
            OutlinedButton(
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (_) => _ConfirmDlg(title: 'مسح الأفكار', msg: 'مسح كل الأفكار المحفوظة؟'));
                if (ok == true && context.mounted) context.read<AppStore>().clearDumps();
              },
              style: OutlinedButton.styleFrom(foregroundColor: _muted, side: const BorderSide(color: _border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('مسح الكل'),
            ),
        ]),
        if (store.dumps.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('الأفكار المحفوظة (${store.dumps.length})', style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600, letterSpacing: .5)),
          const SizedBox(height: 8),
          ...store.dumps.reversed.map((d) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: _surface, border: Border.all(color: _border), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(child: Text(d.text, style: const TextStyle(fontSize: 13, color: _text))),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () { final task = store.buildNewTask(prefillTitle: d.text); store.deleteDump(d.id); showDialog(context: context, builder: (_) => TaskFormDialog(task: task)); },
                style: OutlinedButton.styleFrom(foregroundColor: _muted, side: const BorderSide(color: _border), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), textStyle: const TextStyle(fontSize: 12)),
                child: const Text('تحويل لمهمة'),
              ),
              IconButton(icon: const Icon(Icons.close, size: 16), color: _critical, onPressed: () => store.deleteDump(d.id)),
            ]),
          )),
        ],
      ])),
    ]);
  }
}

// ── TASK CARD ──────────────────────────────────────────
class TaskCard extends StatelessWidget {
  final Task task;
  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final pColor = priorityColor(task.priority);
    final src = store.sourceById(task.sourceId);
    final od = task.isOverdue;
    final accentColor = od ? _critical : pColor;

    return GestureDetector(
      onTap: () => showDialog(context: context, builder: (_) => TaskFormDialog(task: task)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          color: task.isDone ? _surface.withValues(alpha: .5) : _surface,
          border: Border.all(color: od ? _critical.withValues(alpha: .35) : _border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored left strip
                Container(width: 3, color: accentColor),
                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Checkbox
                      GestureDetector(
                        onTap: () => store.toggleTask(task.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 20, height: 20,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: task.isDone ? _low : Colors.transparent,
                            border: Border.all(color: task.isDone ? _low : _border, width: 2),
                            shape: BoxShape.circle,
                          ),
                          child: task.isDone ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Content
                      Expanded(
                        child: Opacity(
                          opacity: task.isDone ? .5 : 1,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(task.title,
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: _text,
                                    decoration: task.isDone ? TextDecoration.lineThrough : null)),
                            if (task.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  task.description.length > 90 ? '${task.description.substring(0, 90)}...' : task.description,
                                  style: const TextStyle(fontSize: 11.5, color: _muted),
                                ),
                              ),
                            const SizedBox(height: 5),
                            Wrap(spacing: 5, runSpacing: 4, children: [
                              _mkBadge(priorityLabel(task.priority), pColor),
                              _mkBadge(timingLabel(task.timing), timingColor(task.timing)),
                              if (task.isOnMe)
                                _mkBadge('أنا', _accentL, icon: Icons.person_outline)
                              else
                                _mkBadge(task.assignedTo, _high, icon: Icons.person_outline),
                              ...task.collaborators.map((c) => _mkBadge(c, _muted, icon: Icons.people_outline)),
                              if (src != null) _mkBadge(src.name, hexColor(src.color)),
                              if (task.dueDate.isNotEmpty)
                                _mkBadge((od ? 'متأخرة · ' : '') + fmtDate(task.dueDate), od ? _critical : _muted),
                            ]),
                          ]),
                        ),
                      ),
                      // Actions
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.timer_outlined, size: 17),
                          color: _muted, padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          tooltip: 'برومودو',
                          onPressed: () => showDialog(context: context, builder: (_) => PomoDialog(task: task)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          color: _muted, padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => showDialog(context: context, builder: (_) => TaskFormDialog(task: task)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 17),
                          color: _critical, padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () async {
                            final ok = await showDialog<bool>(context: context,
                                builder: (_) => _ConfirmDlg(title: 'حذف المهمة', msg: 'حذف "${task.title}"؟'));
                            if (ok == true && context.mounted) context.read<AppStore>().deleteTask(task.id);
                          },
                        ),
                      ]),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _mkBadge(String label, Color color, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 3)],
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ]),
      );
}

// ── POMODORO DIALOG ────────────────────────────────────
class PomoDialog extends StatefulWidget {
  final Task task;
  const PomoDialog({super.key, required this.task});
  @override State<PomoDialog> createState() => _PomoDialogState();
}

class _PomoDialogState extends State<PomoDialog> {
  static const _schemas = [('25/5', 25, 5), ('50/10', 50, 10), ('90/20', 90, 20)];
  int _si = 0, _remaining = 25 * 60, _cycle = 1, _totalWork = 0;
  String _phase = 'work';
  Timer? _timer;
  bool _running = false;

  @override void dispose() { _timer?.cancel(); super.dispose(); }

  void _toggle() {
    if (_running) { _timer?.cancel(); setState(() => _running = false); return; }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_phase == 'work') _totalWork++;
        _remaining--;
        if (_remaining <= 0) {
          if (_phase == 'work') { _phase = 'break'; _remaining = _schemas[_si].$3 * 60; }
          else { _phase = 'work'; _cycle++; _remaining = _schemas[_si].$2 * 60; }
        }
      });
    });
    setState(() => _running = true);
  }

  void _reset() { _timer?.cancel(); setState(() { _running = false; _phase = 'work'; _remaining = _schemas[_si].$2 * 60; }); }
  void _skip() {
    _timer?.cancel();
    setState(() {
      _running = false;
      if (_phase == 'work') { _phase = 'break'; _remaining = _schemas[_si].$3 * 60; }
      else { _phase = 'work'; _cycle++; _remaining = _schemas[_si].$2 * 60; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final schema = _schemas[_si];
    final total = (_phase == 'work' ? schema.$2 : schema.$3) * 60;
    final pct = 1 - (_remaining / total);
    final phaseColor = _phase == 'work' ? _accentL : _low;
    final m = _remaining ~/ 60, s = _remaining % 60;
    final timeStr = '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.task.title.length > 30 ? '${widget.task.title.substring(0,30)}...' : widget.task.title,
          style: const TextStyle(fontSize: 15, color: _text, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 300,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Schema buttons
            Row(mainAxisAlignment: MainAxisAlignment.center, children: _schemas.asMap().entries.map((e) =>
              GestureDetector(
                onTap: () { _timer?.cancel(); setState(() { _si = e.key; _running = false; _phase = 'work'; _remaining = _schemas[e.key].$2 * 60; }); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                  decoration: BoxDecoration(
                    color: _si == e.key ? _accent.withOpacity(.2) : Colors.transparent,
                    border: Border.all(color: _si == e.key ? _accent : _border),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(e.value.$1, style: TextStyle(fontSize: 12, color: _si == e.key ? _accentL : _muted)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 150, height: 150,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 150, height: 150,
                  child: CircularProgressIndicator(value: pct, strokeWidth: 6, backgroundColor: _border, valueColor: AlwaysStoppedAnimation(phaseColor)),
                ),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(timeStr, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: _text, letterSpacing: 2)),
                  Text(_phase == 'work' ? 'عمل' : 'راحة', style: TextStyle(fontSize: 11, color: phaseColor, fontWeight: FontWeight.w600)),
                  Text('دورة $_cycle', style: const TextStyle(fontSize: 10, color: _muted)),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            Text('مجموع العمل: ${_totalWork ~/ 60} دقيقة', style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              ElevatedButton(
                onPressed: _toggle,
                style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Text(_running ? 'إيقاف مؤقت' : 'بدء'),
              ),
              OutlinedButton(onPressed: _reset, style: OutlinedButton.styleFrom(foregroundColor: _muted, side: const BorderSide(color: _border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('إعادة')),
              OutlinedButton(onPressed: _skip, style: OutlinedButton.styleFrom(foregroundColor: _muted, side: const BorderSide(color: _border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('تخطي')),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق', style: TextStyle(color: _muted))),
        ],
      ),
    );
  }
}

// ── TASK FORM DIALOG ───────────────────────────────────
class TaskFormDialog extends StatefulWidget {
  final Task task;
  const TaskFormDialog({super.key, required this.task});
  @override State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  late TextEditingController _title, _desc, _assigned, _collabCtrl, _dateCtrl;
  late String _priority, _timing, _sourceId;
  late List<String> _collabs;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _isNew = t.title.isEmpty;
    _title = TextEditingController(text: t.title);
    _desc = TextEditingController(text: t.description);
    _assigned = TextEditingController(text: t.assignedTo);
    _collabs = List.from(t.collaborators);
    _collabCtrl = TextEditingController();
    _dateCtrl = TextEditingController(text: t.dueDate);
    _priority = t.priority;
    _timing = t.timing;
    _sourceId = t.sourceId;
  }

  @override
  void dispose() { _title.dispose(); _desc.dispose(); _assigned.dispose(); _collabCtrl.dispose(); _dateCtrl.dispose(); super.dispose(); }

  void _save(AppStore store) {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final assignedTo = _assigned.text.trim();
    final timing = assignedTo.isNotEmpty ? 'followup' : _timing;
    final updated = widget.task.copyWith(
      title: title, description: _desc.text.trim(),
      priority: _priority, timing: timing, sourceId: _sourceId,
      assignedTo: assignedTo, collaborators: _collabs, dueDate: _dateCtrl.text.trim(),
    );
    if (_isNew) store.addTask(updated);
    else store.updateTask(updated);
    Navigator.pop(context);
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: _muted),
    filled: true, fillColor: _surface2,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accent)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final assignedToOther = _assigned.text.trim().isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_isNew ? 'إضافة مهمة جديدة' : 'تعديل المهمة',
            style: const TextStyle(fontSize: 17, color: _text, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title
            _fLabel('عنوان المهمة *'),
            TextField(controller: _title, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13.5, color: _text), decoration: _inputDec('ما هي المهمة؟')),
            const SizedBox(height: 12),
            // Desc
            _fLabel('تفاصيل'),
            TextField(controller: _desc, textDirection: TextDirection.rtl, maxLines: 2, style: const TextStyle(fontSize: 13.5, color: _text), decoration: _inputDec('وصف اختياري...')),
            const SizedBox(height: 12),
            // Assigned + date
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fLabel('المنفذ (فارغ = أنا)'),
                TextField(controller: _assigned, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13.5, color: _text), decoration: _inputDec('اسم الشخص المسؤول'), onChanged: (_) => setState(() {})),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fLabel('تاريخ الاستحقاق'),
                TextField(controller: _dateCtrl, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13.5, color: _text), decoration: _inputDec('YYYY-MM-DD')),
              ])),
            ]),
            const SizedBox(height: 12),
            // Collaborators
            _fLabel('المتعاونون'),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _collabCtrl,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 13.5, color: _text),
                  decoration: _inputDec('اكتب اسماً واضغط Enter'),
                  onSubmitted: (v) {
                    final n = v.trim();
                    if (n.isNotEmpty && !_collabs.contains(n)) setState(() { _collabs.add(n); _collabCtrl.clear(); });
                  },
                ),
              ),
            ]),
            if (_collabs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 6, children: _collabs.map((c) => Chip(
                  label: Text(c, style: const TextStyle(fontSize: 12, color: _text)),
                  backgroundColor: _surface2, deleteIconColor: _muted,
                  onDeleted: () => setState(() => _collabs.remove(c)),
                )).toList()),
              ),
            if (assignedToOther) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _followup.withOpacity(.08), border: Border.all(color: _followup.withOpacity(.2)), borderRadius: BorderRadius.circular(8)),
                child: const Text('لأن المهمة على شخص آخر، ستُضاف تلقائياً لقائمة المتابعة', style: TextStyle(fontSize: 12, color: _followup)),
              ),
            ],
            const SizedBox(height: 12),
            // Priority
            _fLabel('الأولوية'),
            _radioGroup(['critical','high','normal','low'], ['حرج','عالي','عادي','منخفض'], _priority, (v) => setState(() => _priority = v)),
            const SizedBox(height: 10),
            // Timing (only if assigned to me)
            if (!assignedToOther) ...[
              _fLabel('التوقيت'),
              _radioGroup(['today','scheduled','someday','followup'], ['اليوم','مجدول','لاحقاً','متابعة'], _timing, (v) => setState(() => _timing = v)),
              const SizedBox(height: 10),
            ],
            // Source
            _fLabel('الجهة'),
            _buildSourceDd(store),
          ])),
        ),
        actions: [
          if (!_isNew)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (_) => _ConfirmDlg(title: 'حذف', msg: 'حذف هذه المهمة؟'));
                if (ok == true && context.mounted) { store.deleteTask(widget.task.id); Navigator.pop(context); }
              },
              child: const Text('حذف', style: TextStyle(color: _critical)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: _muted))),
          ElevatedButton(
            onPressed: () => _save(store),
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _fLabel(String t) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(t, style: const TextStyle(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w500)));

  Widget _radioGroup(List<String> values, List<String> labels, String current, void Function(String) onChanged) =>
      Wrap(spacing: 7, runSpacing: 7, children: List.generate(values.length, (i) {
        final active = current == values[i];
        return GestureDetector(
          onTap: () => onChanged(values[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: active ? _accent.withOpacity(.15) : Colors.transparent,
              border: Border.all(color: active ? _accent : _border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(labels[i], style: TextStyle(fontSize: 12.5, color: active ? _accentL : _muted, fontWeight: active ? FontWeight.w500 : FontWeight.normal)),
          ),
        );
      }));

  Widget _buildSourceDd(AppStore store) {
    final items = <DropdownMenuItem<String>>[const DropdownMenuItem(value: '', child: Text('بدون جهة'))];
    void addNode(String parentId, int depth) {
      for (final s in store.childrenOf(parentId)) {
        items.add(DropdownMenuItem(value: s.id, child: Text('${'  ' * depth}${s.name}')));
        addNode(s.id, depth + 1);
      }
    }
    for (final r in store.rootSources()) {
      items.add(DropdownMenuItem(value: r.id, child: Text(r.name)));
      addNode(r.id, 1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
      decoration: BoxDecoration(color: _surface2, border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
      child: DropdownButton<String>(
        value: _sourceId,
        isExpanded: true, isDense: true, underline: const SizedBox(),
        dropdownColor: _surface2,
        style: const TextStyle(fontSize: 13.5, color: _text, fontFamily: 'Arial'),
        items: items,
        onChanged: (v) => setState(() => _sourceId = v ?? ''),
      ),
    );
  }
}

// ── SOURCE FORM ────────────────────────────────────────
class SourceFormDialog extends StatefulWidget {
  final Source source;
  const SourceFormDialog({super.key, required this.source});
  @override State<SourceFormDialog> createState() => _SourceFormDialogState();
}

class _SourceFormDialogState extends State<SourceFormDialog> {
  late TextEditingController _name;
  late String _color, _parentId;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    _isNew = widget.source.name.isEmpty;
    _name = TextEditingController(text: widget.source.name);
    _color = widget.source.color;
    _parentId = widget.source.parentId;
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_isNew ? 'إضافة جهة' : 'تعديل الجهة', style: const TextStyle(fontSize: 17, color: _text, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('اسم الجهة *', style: TextStyle(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 5),
            TextField(
              controller: _name,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 13.5, color: _text),
              decoration: InputDecoration(
                hintText: 'مثال: العمل، الجامعة',
                hintStyle: const TextStyle(color: _muted),
                filled: true, fillColor: _surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accent)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              ),
            ),
            const SizedBox(height: 14),
            const Text('التفرع من', style: TextStyle(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 5),
            _buildParentDd(store),
            const SizedBox(height: 14),
            const Text('اللون', style: TextStyle(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _srcColors.map((c) => GestureDetector(
              onTap: () => setState(() => _color = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 27, height: 27,
                decoration: BoxDecoration(
                  color: hexColor(c), shape: BoxShape.circle,
                  border: Border.all(color: _color == c ? Colors.white : Colors.transparent, width: 3),
                ),
              ),
            )).toList()),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: _muted))),
          ElevatedButton(
            onPressed: () {
              final name = _name.text.trim();
              if (name.isEmpty) return;
              final s = Source(id: widget.source.id, name: name, color: _color, parentId: _parentId);
              if (_isNew) store.addSource(s);
              else store.updateSource(s);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _buildParentDd(AppStore store) {
    final items = <DropdownMenuItem<String>>[const DropdownMenuItem(value: '', child: Text('جهة رئيسية'))];
    void addNode(String parentId, int depth) {
      for (final s in store.childrenOf(parentId)) {
        if (s.id == widget.source.id) continue;
        items.add(DropdownMenuItem(value: s.id, child: Text('${'  ' * depth}${s.name}')));
        addNode(s.id, depth + 1);
      }
    }
    for (final r in store.rootSources()) {
      if (r.id == widget.source.id) continue;
      items.add(DropdownMenuItem(value: r.id, child: Text(r.name)));
      addNode(r.id, 1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
      decoration: BoxDecoration(color: _surface2, border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
      child: DropdownButton<String>(
        value: _parentId,
        isExpanded: true, isDense: true, underline: const SizedBox(),
        dropdownColor: _surface2,
        style: const TextStyle(fontSize: 13.5, color: _text, fontFamily: 'Arial'),
        items: items,
        onChanged: (v) => setState(() => _parentId = v ?? ''),
      ),
    );
  }
}

// ── POLICY FORM ────────────────────────────────────────
class PolicyFormDialog extends StatefulWidget {
  final Policy policy;
  const PolicyFormDialog({super.key, required this.policy});
  @override State<PolicyFormDialog> createState() => _PolicyFormDialogState();
}

class _PolicyFormDialogState extends State<PolicyFormDialog> {
  late TextEditingController _title, _body;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    _isNew = widget.policy.title.isEmpty;
    _title = TextEditingController(text: widget.policy.title);
    _body = TextEditingController(text: widget.policy.body);
  }

  @override
  void dispose() { _title.dispose(); _body.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_isNew ? 'إضافة سياسة' : 'تعديل السياسة', style: const TextStyle(fontSize: 17, color: _text, fontWeight: FontWeight.w600)),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _title, textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 13.5, color: _text),
              decoration: InputDecoration(
                labelText: 'عنوان السياسة *', labelStyle: const TextStyle(color: _muted),
                filled: true, fillColor: _surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accent)),
              )),
          const SizedBox(height: 12),
          TextField(controller: _body, textDirection: TextDirection.rtl, maxLines: 5,
              style: const TextStyle(fontSize: 13.5, color: _text),
              decoration: InputDecoration(
                labelText: 'نص السياسة *', labelStyle: const TextStyle(color: _muted),
                filled: true, fillColor: _surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accent)),
              )),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: _muted))),
          ElevatedButton(
            onPressed: () {
              final title = _title.text.trim(), body = _body.text.trim();
              if (title.isEmpty || body.isEmpty) return;
              final p = Policy(id: widget.policy.id, title: title, body: body, createdAt: widget.policy.createdAt);
              if (_isNew) store.addPolicy(p);
              else store.updatePolicy(p);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ── CONFIRM DIALOG ─────────────────────────────────────
class _ConfirmDlg extends StatelessWidget {
  final String title, msg;
  const _ConfirmDlg({required this.title, required this.msg});
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(title, style: const TextStyle(fontSize: 16, color: _text, fontWeight: FontWeight.w600)),
          content: Text(msg, style: const TextStyle(fontSize: 13.5, color: _muted)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(color: _muted))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: _critical, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
}
