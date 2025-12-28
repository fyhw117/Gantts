import 'package:flutter/material.dart';
import '../models/task_model.dart';

/// タスクデータを管理するProvider
class TaskProvider extends ChangeNotifier {
  List<Task> _rootTasks = [];

  List<Task> get rootTasks => _rootTasks;

  /// すべてのタスクをフラットなリストで取得
  List<Task> getAllTasks() {
    List<Task> allTasks = [];
    for (var task in _rootTasks) {
      allTasks.addAll(task.flatten());
    }
    return allTasks;
  }

  /// 階層構造を保持しながら、表示すべきタスクを取得（折りたたみを考慮）
  List<TaskWithLevel> getVisibleTasksWithLevel() {
    List<TaskWithLevel> visibleTasks = [];
    for (var task in _rootTasks) {
      _addVisibleTasksRecursive(task, 0, visibleTasks);
    }
    return visibleTasks;
  }

  void _addVisibleTasksRecursive(Task task, int level, List<TaskWithLevel> result) {
    result.add(TaskWithLevel(task: task, level: level));
    if (task.isExpanded && task.hasChildren) {
      for (var child in task.children) {
        _addVisibleTasksRecursive(child, level + 1, result);
      }
    }
  }

  /// タスクを追加
  void addTask(Task task, {Task? parent}) {
    if (parent == null) {
      _rootTasks.add(task);
    } else {
      // 親タスクを見つけて子として追加
      _addChildTask(parent.id, task);
    }
    notifyListeners();
  }

  void _addChildTask(String parentId, Task task) {
    for (var i = 0; i < _rootTasks.length; i++) {
      if (_rootTasks[i].id == parentId) {
        _rootTasks[i] = _rootTasks[i].copyWith(
          children: [..._rootTasks[i].children, task],
        );
        return;
      }
      _addChildTaskRecursive(_rootTasks[i], parentId, task);
    }
  }

  void _addChildTaskRecursive(Task current, String parentId, Task newTask) {
    for (var i = 0; i < current.children.length; i++) {
      if (current.children[i].id == parentId) {
        current.children[i] = current.children[i].copyWith(
          children: [...current.children[i].children, newTask],
        );
        return;
      }
      _addChildTaskRecursive(current.children[i], parentId, newTask);
    }
  }

  /// タスクを更新
  void updateTask(String taskId, Task updatedTask) {
    for (var i = 0; i < _rootTasks.length; i++) {
      if (_rootTasks[i].id == taskId) {
        _rootTasks[i] = updatedTask;
        notifyListeners();
        return;
      }
      _updateTaskRecursive(_rootTasks[i], taskId, updatedTask);
    }
    notifyListeners();
  }

  void _updateTaskRecursive(Task current, String taskId, Task updatedTask) {
    for (var i = 0; i < current.children.length; i++) {
      if (current.children[i].id == taskId) {
        current.children[i] = updatedTask;
        return;
      }
      _updateTaskRecursive(current.children[i], taskId, updatedTask);
    }
  }

  /// タスクを削除
  void deleteTask(String taskId) {
    _rootTasks.removeWhere((task) => task.id == taskId);
    for (var task in _rootTasks) {
      _deleteTaskRecursive(task, taskId);
    }
    notifyListeners();
  }

  void _deleteTaskRecursive(Task current, String taskId) {
    current.children.removeWhere((child) => child.id == taskId);
    for (var child in current.children) {
      _deleteTaskRecursive(child, taskId);
    }
  }

  /// タスクの展開状態を切り替え
  void toggleExpand(String taskId) {
    for (var i = 0; i < _rootTasks.length; i++) {
      if (_rootTasks[i].id == taskId) {
        _rootTasks[i] = _rootTasks[i].copyWith(
          isExpanded: !_rootTasks[i].isExpanded,
        );
        notifyListeners();
        return;
      }
      _toggleExpandRecursive(_rootTasks[i], taskId);
    }
    notifyListeners();
  }

  void _toggleExpandRecursive(Task current, String taskId) {
    for (var i = 0; i < current.children.length; i++) {
      if (current.children[i].id == taskId) {
        current.children[i] = current.children[i].copyWith(
          isExpanded: !current.children[i].isExpanded,
        );
        return;
      }
      _toggleExpandRecursive(current.children[i], taskId);
    }
  }

  /// ルートタスクの順序を変更
  void reorderRootTasks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final task = _rootTasks.removeAt(oldIndex);
    _rootTasks.insert(newIndex, task);
    notifyListeners();
  }

  /// 子タスクの順序を変更
  void reorderChildTasks(String parentId, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    for (var i = 0; i < _rootTasks.length; i++) {
      if (_rootTasks[i].id == parentId) {
        final children = List<Task>.from(_rootTasks[i].children);
        final task = children.removeAt(oldIndex);
        children.insert(newIndex, task);
        _rootTasks[i] = _rootTasks[i].copyWith(children: children);
        notifyListeners();
        return;
      }
      if (_reorderChildTasksRecursive(_rootTasks[i], parentId, oldIndex, newIndex)) {
        notifyListeners();
        return;
      }
    }
  }

  bool _reorderChildTasksRecursive(Task current, String parentId, int oldIndex, int newIndex) {
    for (var i = 0; i < current.children.length; i++) {
      if (current.children[i].id == parentId) {
        final children = List<Task>.from(current.children[i].children);
        final task = children.removeAt(oldIndex);
        children.insert(newIndex, task);
        current.children[i] = current.children[i].copyWith(children: children);
        return true;
      }
      if (_reorderChildTasksRecursive(current.children[i], parentId, oldIndex, newIndex)) {
        return true;
      }
    }
    return false;
  }

  /// サンプルデータを読み込み
  void loadSampleData() {
    _rootTasks = [
      Task(
        id: '1',
        name: 'プロジェクト企画',
        description: 'プロジェクトの立ち上げと企画',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 15),
        progress: 0.8,
        color: Colors.blue,
        isExpanded: true,
        children: [
          Task(
            id: '1-1',
            name: '要件定義',
            description: 'システム要件の定義',
            startDate: DateTime(2025, 1, 1),
            endDate: DateTime(2025, 1, 7),
            progress: 1.0,
            color: Colors.blue,
          ),
          Task(
            id: '1-2',
            name: '基本設計',
            description: 'システムの基本設計',
            startDate: DateTime(2025, 1, 8),
            endDate: DateTime(2025, 1, 15),
            progress: 0.6,
            color: Colors.blue,
          ),
        ],
      ),
      Task(
        id: '2',
        name: '開発フェーズ',
        description: '実装作業',
        startDate: DateTime(2025, 1, 16),
        endDate: DateTime(2025, 2, 28),
        progress: 0.3,
        color: Colors.green,
        isExpanded: true,
        children: [
          Task(
            id: '2-1',
            name: 'フロントエンド開発',
            description: 'UI/UXの実装',
            startDate: DateTime(2025, 1, 16),
            endDate: DateTime(2025, 2, 10),
            progress: 0.5,
            color: Colors.green,
          ),
          Task(
            id: '2-2',
            name: 'バックエンド開発',
            description: 'サーバー側の実装',
            startDate: DateTime(2025, 1, 16),
            endDate: DateTime(2025, 2, 15),
            progress: 0.3,
            color: Colors.green,
          ),
          Task(
            id: '2-3',
            name: '統合テスト',
            description: 'システム全体のテスト',
            startDate: DateTime(2025, 2, 16),
            endDate: DateTime(2025, 2, 28),
            progress: 0.0,
            color: Colors.green,
          ),
        ],
      ),
      Task(
        id: '3',
        name: 'リリース準備',
        description: '本番環境への展開準備',
        startDate: DateTime(2025, 3, 1),
        endDate: DateTime(2025, 3, 15),
        progress: 0.0,
        color: Colors.orange,
      ),
    ];
    notifyListeners();
  }
}

/// タスクと階層レベルを保持するクラス
class TaskWithLevel {
  final Task task;
  final int level;

  TaskWithLevel({required this.task, required this.level});
}
