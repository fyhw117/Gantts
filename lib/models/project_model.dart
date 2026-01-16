import 'package:cloud_firestore/cloud_firestore.dart';
import 'task_model.dart';
import 'package:uuid/uuid.dart';

/// プロジェクトのモデルクラス
class Project {
  String id;
  String name;
  String description;
  DateTime createdAt;
  List<Task> tasks;

  Project({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    this.tasks = const [],
  });

  /// 新しいプロジェクトを作成するファクトリ
  factory Project.create({required String name, String description = ''}) {
    return Project(
      id: const Uuid().v4(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
      tasks: [],
    );
  }

  /// プロジェクトのコピーを作成
  Project copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    List<Task>? tasks,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      tasks: tasks ?? this.tasks,
    );
  }

  /// Firestore用のMapに変換
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      // Tasks are stored in a sub-collection
    };
  }

  /// FirestoreのMapからProjectを生成
  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      tasks: [], // Tasks will be loaded separately
    );
  }
}
