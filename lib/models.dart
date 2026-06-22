import 'dart:convert';

class Person {
  final String id;
  String name;
  String role;

  Person({required this.id, required this.name, this.role = ''});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};

  factory Person.fromJson(Map<String, dynamic> j) =>
      Person(id: j['id'] ?? '', name: j['name'] ?? '', role: j['role'] ?? '');
}

class Task {
  final String id;
  String title;
  String description;
  String priority; // critical high normal low
  String timing;   // today scheduled someday followup
  String sourceId;
  String assignedTo; // '' = me, else name
  List<String> collaborators;
  String dueDate;  // yyyy-MM-dd or ''
  String status;   // pending done
  String createdAt;
  String completedAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = 'normal',
    this.timing = 'today',
    this.sourceId = '',
    this.assignedTo = '',
    this.collaborators = const [],
    this.dueDate = '',
    this.status = 'pending',
    required this.createdAt,
    this.completedAt = '',
  });

  bool get isOnMe => assignedTo.trim().isEmpty;
  bool get isDone => status == 'done';
  bool get isOverdue {
    if (dueDate.isEmpty || isDone) return false;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return dueDate.compareTo(todayStr) < 0;
  }

  List<String> get allPeople {
    final r = <String>{};
    if (assignedTo.trim().isNotEmpty) r.add(assignedTo.trim());
    r.addAll(collaborators);
    return r.toList();
  }

  Task copyWith({
    String? title,
    String? description,
    String? priority,
    String? timing,
    String? sourceId,
    String? assignedTo,
    List<String>? collaborators,
    String? dueDate,
    String? status,
    String? completedAt,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        priority: priority ?? this.priority,
        timing: timing ?? this.timing,
        sourceId: sourceId ?? this.sourceId,
        assignedTo: assignedTo ?? this.assignedTo,
        collaborators: collaborators ?? this.collaborators,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'priority': priority,
        'timing': timing,
        'sourceId': sourceId,
        'assignedTo': assignedTo,
        'collaborators': collaborators,
        'dueDate': dueDate,
        'status': status,
        'createdAt': createdAt,
        'completedAt': completedAt,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        priority: j['priority'] ?? 'normal',
        timing: j['timing'] ?? 'today',
        sourceId: j['sourceId'] ?? '',
        assignedTo: j['assignedTo'] ?? '',
        collaborators: List<String>.from(j['collaborators'] ?? []),
        dueDate: j['dueDate'] ?? '',
        status: j['status'] ?? 'pending',
        createdAt: j['createdAt'] ?? '',
        completedAt: j['completedAt'] ?? '',
      );
}

class Source {
  final String id;
  String name;
  String color; // hex
  String parentId; // '' = root

  Source({
    required this.id,
    required this.name,
    this.color = '#58a6ff',
    this.parentId = '',
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'color': color, 'parentId': parentId};

  factory Source.fromJson(Map<String, dynamic> j) => Source(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        color: j['color'] ?? '#58a6ff',
        parentId: j['parentId'] ?? '',
      );
}

class Policy {
  final String id;
  String title;
  String body;
  String createdAt;

  Policy({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'body': body, 'createdAt': createdAt};

  factory Policy.fromJson(Map<String, dynamic> j) => Policy(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        createdAt: j['createdAt'] ?? '',
      );
}

class DumpItem {
  final String id;
  String text;
  String createdAt;

  DumpItem({required this.id, required this.text, required this.createdAt});

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'createdAt': createdAt};

  factory DumpItem.fromJson(Map<String, dynamic> j) =>
      DumpItem(id: j['id'] ?? '', text: j['text'] ?? '', createdAt: j['createdAt'] ?? '');
}
