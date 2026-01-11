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
}
