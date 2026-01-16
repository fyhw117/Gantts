import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Firestore用のMapに変換
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'progress': progress,
      'color': color.value,
      'dependencies': dependencies,
      'children': children.map((child) => child.toMap()).toList(),
      'isExpanded': isExpanded,
    };
  }

  /// FirestoreのMapからTaskを生成
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      color: Color(map['color'] ?? 0xFF42A5F5), // Default Blue
      dependencies: List<String>.from(map['dependencies'] ?? []),
      children:
          (map['children'] as List<dynamic>?)
              ?.map((childMap) => Task.fromMap(childMap))
              .toList() ??
          [],
      isExpanded: map['isExpanded'] ?? false,
    );
  }
}
