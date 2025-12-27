import 'package:flutter/material.dart';

/// タスクのモデルクラス
class Task {
  String id;
  String name;
  String description;
  DateTime startDate;
  DateTime endDate;
  double progress; // 0.0 ~ 1.0
  Color color;
  List<String> dependencies; // 依存タスクのID
  List<Task> children; // 子タスク（WBS用）
  bool isExpanded; // WBSツリーで展開されているか

  Task({
    required this.id,
    required this.name,
    this.description = '',
    required this.startDate,
    required this.endDate,
    this.progress = 0.0,
    this.color = Colors.blue,
    this.dependencies = const [],
    this.children = const [],
    this.isExpanded = false,
  });

  /// 期間（日数）を計算
  int get durationInDays {
    return endDate.difference(startDate).inDays + 1;
  }

  /// 子タスクを持つか
  bool get hasChildren {
    return children.isNotEmpty;
  }

  /// WBSのレベル（深さ）を計算
  int getLevel(Task root, [int currentLevel = 0]) {
    if (root.id == id) return currentLevel;
    for (var child in root.children) {
      final level = getLevel(child, currentLevel + 1);
      if (level >= 0) return level;
    }
    return -1;
  }

  /// タスクのコピーを作成
  Task copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    double? progress,
    Color? color,
    List<String>? dependencies,
    List<Task>? children,
    bool? isExpanded,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      progress: progress ?? this.progress,
      color: color ?? this.color,
      dependencies: dependencies ?? this.dependencies,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  /// すべてのタスクをフラットなリストに展開
  List<Task> flatten() {
    List<Task> result = [this];
    for (var child in children) {
      result.addAll(child.flatten());
    }
    return result;
  }
}
