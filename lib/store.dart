import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import 'models.dart';

class AppStore extends ChangeNotifier {
  List<Task> tasks = [];
  List<Source> sources = [];
  List<Policy> policies = [];
  List<DumpItem> dumps = [];

  final _db = FirebaseFirestore.instance;

  // ── Init ──
  Future<void> init() async {
    await Future.wait([_loadTasks(), _loadSources(), _loadPolicies(), _loadDumps()]);
    if (sources.isEmpty) await _initDefaultSources();
    notifyListeners();
  }

  Future<void> _loadTasks() async {
    final snap = await _db.collection('tasks').orderBy('createdAt').get();
    tasks = snap.docs.map((d) => Task.fromJson({...d.data(), 'id': d.id})).toList();
  }

  Future<void> _loadSources() async {
    final snap = await _db.collection('sources').get();
    sources = snap.docs.map((d) => Source.fromJson({...d.data(), 'id': d.id})).toList();
  }

  Future<void> _loadPolicies() async {
    final snap = await _db.collection('policies').orderBy('createdAt').get();
    policies = snap.docs.map((d) => Policy.fromJson({...d.data(), 'id': d.id})).toList();
  }

  Future<void> _loadDumps() async {
    final snap = await _db.collection('dumps').orderBy('createdAt').get();
    dumps = snap.docs.map((d) => DumpItem.fromJson({...d.data(), 'id': d.id})).toList();
  }

  Future<void> _initDefaultSources() async {
    final defaults = [
      Source(id: _uid(), name: 'العمل', color: '#58a6ff'),
      Source(id: _uid(), name: 'الشخصي', color: '#3fb950'),
      Source(id: _uid(), name: 'الأسرة', color: '#f0883e'),
    ];
    for (final s in defaults) {
      await _db.collection('sources').doc(s.id).set(s.toJson()..remove('id'));
    }
    sources = defaults;
  }

  String _uid() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().microsecond % 9999).toString();

  String get _todayStr {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  // ── Tasks ──
  Future<void> addTask(Task t) async {
    final data = t.toJson()..remove('id');
    await _db.collection('tasks').doc(t.id).set(data);
    tasks.add(t);
    notifyListeners();
  }

  Future<void> updateTask(Task t) async {
    final data = t.toJson()..remove('id');
    await _db.collection('tasks').doc(t.id).update(data);
    final i = tasks.indexWhere((x) => x.id == t.id);
    if (i >= 0) tasks[i] = t;
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    await _db.collection('tasks').doc(id).delete();
    tasks.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  Future<void> toggleTask(String id) async {
    final t = tasks.firstWhere((x) => x.id == id);
    final done = t.isDone;
    final updated = t.copyWith(
      status: done ? 'pending' : 'done',
      completedAt: done ? '' : _todayStr,
    );
    await updateTask(updated);
  }

  Task buildNewTask({String prefillTitle = ''}) => Task(
        id: _uid(),
        title: prefillTitle,
        priority: 'normal',
        timing: 'today',
        createdAt: DateTime.now().toIso8601String(),
      );

  // ── Sources ──
  Future<void> addSource(Source s) async {
    await _db.collection('sources').doc(s.id).set(s.toJson()..remove('id'));
    sources.add(s);
    notifyListeners();
  }

  Future<void> updateSource(Source s) async {
    await _db.collection('sources').doc(s.id).update(s.toJson()..remove('id'));
    final i = sources.indexWhere((x) => x.id == s.id);
    if (i >= 0) sources[i] = s;
    notifyListeners();
  }

  Future<void> deleteSource(String id) async {
    await _db.collection('sources').doc(id).delete();
    sources.removeWhere((x) => x.id == id);
    // orphan children
    for (int i = 0; i < sources.length; i++) {
      if (sources[i].parentId == id) {
        final updated = Source(id: sources[i].id, name: sources[i].name, color: sources[i].color, parentId: '');
        await _db.collection('sources').doc(updated.id).update({'parentId': ''});
        sources[i] = updated;
      }
    }
    // clear source from tasks
    for (int i = 0; i < tasks.length; i++) {
      if (tasks[i].sourceId == id) {
        final updated = tasks[i].copyWith(sourceId: '');
        await _db.collection('tasks').doc(updated.id).update({'sourceId': ''});
        tasks[i] = updated;
      }
    }
    notifyListeners();
  }

  Source buildNewSource({String parentId = ''}) =>
      Source(id: _uid(), name: '', color: '#58a6ff', parentId: parentId);

  List<Source> rootSources() {
    final list = sources.where((s) => s.parentId.isEmpty).cast<Source>().toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<Source> childrenOf(String parentId) {
    final list = sources.where((s) => s.parentId == parentId).cast<Source>().toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Source? sourceById(String id) {
    try { return sources.firstWhere((s) => s.id == id); } catch (_) { return null; }
  }

  String sourcePath(String id) {
    final s = sourceById(id);
    if (s == null) return '';
    if (s.parentId.isEmpty) return s.name;
    return '${sourcePath(s.parentId)} / ${s.name}';
  }

  bool isDescendant(String childId, String ancestorId) {
    var s = sourceById(childId);
    while (s != null) {
      if (s.parentId == ancestorId) return true;
      s = sourceById(s.parentId);
    }
    return false;
  }

  // ── Policies ──
  Future<void> addPolicy(Policy p) async {
    await _db.collection('policies').doc(p.id).set(p.toJson()..remove('id'));
    policies.add(p);
    notifyListeners();
  }

  Future<void> updatePolicy(Policy p) async {
    await _db.collection('policies').doc(p.id).update(p.toJson()..remove('id'));
    final i = policies.indexWhere((x) => x.id == p.id);
    if (i >= 0) policies[i] = p;
    notifyListeners();
  }

  Future<void> deletePolicy(String id) async {
    await _db.collection('policies').doc(id).delete();
    policies.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  Policy buildNewPolicy() =>
      Policy(id: _uid(), title: '', body: '', createdAt: DateTime.now().toIso8601String());

  // ── Dumps ──
  Future<void> addDump(String text) async {
    final d = DumpItem(id: _uid(), text: text, createdAt: DateTime.now().toIso8601String());
    await _db.collection('dumps').doc(d.id).set(d.toJson()..remove('id'));
    dumps.add(d);
    notifyListeners();
  }

  Future<void> deleteDump(String id) async {
    await _db.collection('dumps').doc(id).delete();
    dumps.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  Future<void> clearDumps() async {
    final batch = _db.batch();
    for (final d in dumps) batch.delete(_db.collection('dumps').doc(d.id));
    await batch.commit();
    dumps.clear();
    notifyListeners();
  }

  // ── People ──
  List<String> allPeople() {
    final s = <String>{};
    for (final t in tasks) s.addAll(t.allPeople);
    return s.toList()..sort();
  }

  // ── Stats ──
  int activeTasks() => tasks.where((t) => !t.isDone).length;
  int followupCount() => tasks.where((t) => !t.isDone && t.timing == 'followup').length;
  int doneTodayCount() => tasks.where((t) => t.isDone && t.completedAt == _todayStr).length;
}
