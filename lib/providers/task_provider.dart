import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/project_model.dart';

/// タスクデータを管理するProvider
class TaskProvider extends ChangeNotifier {
  List<Project> _projects = [];
  String? _currentProjectId;

  List<Project> get projects => _projects;
  String? get currentProjectId => _currentProjectId;

  Project? get currentProject {
    if (_currentProjectId == null) return null;
    try {
      return _projects.firstWhere((p) => p.id == _currentProjectId);
    } catch (e) {
      return null;
    }
  }

  List<Task> get rootTasks {
    return currentProject?.tasks ?? [];
  }

  /// プロジェクトを追加
  void addProject(String name, String description) {
    final newProject = Project.create(name: name, description: description);
    _projects.add(newProject);
    _currentProjectId = newProject.id;
    notifyListeners();
  }

  /// プロジェクトを選択
  void selectProject(String projectId) {
    if (_projects.any((p) => p.id == projectId)) {
      _currentProjectId = projectId;
      notifyListeners();
    }
  }

  /// プロジェクト情報を更新
  void updateProject(String projectId, String name, String description) {
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index != -1) {
      _projects[index] = _projects[index].copyWith(
        name: name,
        description: description,
      );
      notifyListeners();
    }
  }

  /// プロジェクトを削除
  void deleteProject(String projectId) {
    _projects.removeWhere((p) => p.id == projectId);
    if (_currentProjectId == projectId) {
      _currentProjectId = _projects.isNotEmpty ? _projects.first.id : null;
    }
    notifyListeners();
  }

  /// すべてのタスクをフラットなリストで取得（現在のプロジェクト）
  List<Task> getAllTasks() {
    List<Task> allTasks = [];
    for (var task in rootTasks) {
      allTasks.addAll(task.flatten());
    }
    return allTasks;
  }

  /// 階層構造を保持しながら、表示すべきタスクを取得（折りたたみを考慮）
  List<TaskWithLevel> getVisibleTasksWithLevel() {
    List<TaskWithLevel> visibleTasks = [];
    for (var task in rootTasks) {
      _addVisibleTasksRecursive(task, 0, visibleTasks);
    }
    return visibleTasks;
  }

  void _addVisibleTasksRecursive(
    Task task,
    int level,
    List<TaskWithLevel> result,
  ) {
    result.add(TaskWithLevel(task: task, level: level));
    if (task.isExpanded && task.hasChildren) {
      for (var child in task.children) {
        _addVisibleTasksRecursive(child, level + 1, result);
      }
    }
  }

  /// タスクを追加
  void addTask(Task task, {Task? parent}) {
    final project = currentProject;
    if (project == null) return;

    if (parent == null) {
      project.tasks.add(task);
    } else {
      // 親タスクを見つけて子として追加
      _addChildTask(project.tasks, parent.id, task);
    }
    notifyListeners();
  }

  void _addChildTask(List<Task> tasks, String parentId, Task task) {
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i].id == parentId) {
        tasks[i] = tasks[i].copyWith(children: [...tasks[i].children, task]);
        return;
      }
      _addChildTaskRecursive(tasks[i], parentId, task);
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
    final project = currentProject;
    if (project == null) return;

    for (var i = 0; i < project.tasks.length; i++) {
      if (project.tasks[i].id == taskId) {
        project.tasks[i] = updatedTask;
        notifyListeners();
        return;
      }
      _updateTaskRecursive(project.tasks[i], taskId, updatedTask);
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
    final project = currentProject;
    if (project == null) return;

    project.tasks.removeWhere((task) => task.id == taskId);
    for (var task in project.tasks) {
      _deleteTaskRecursive(task, taskId);
    }
    notifyListeners();
  }

  void _deleteTaskRecursive(Task current, String taskId) {
    if (current.children.isEmpty) return;
    current.children.removeWhere((child) => child.id == taskId);
    for (var child in current.children) {
      _deleteTaskRecursive(child, taskId);
    }
  }

  /// タスクの展開状態を切り替え
  void toggleExpand(String taskId) {
    final project = currentProject;
    if (project == null) return;

    for (var i = 0; i < project.tasks.length; i++) {
      if (project.tasks[i].id == taskId) {
        project.tasks[i] = project.tasks[i].copyWith(
          isExpanded: !project.tasks[i].isExpanded,
        );
        notifyListeners();
        return;
      }
      _toggleExpandRecursive(project.tasks[i], taskId);
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
    final project = currentProject;
    if (project == null) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final task = project.tasks.removeAt(oldIndex);
    project.tasks.insert(newIndex, task);
    notifyListeners();
  }

  /// 子タスクの順序を変更
  void reorderChildTasks(String parentId, int oldIndex, int newIndex) {
    final project = currentProject;
    if (project == null) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    for (var i = 0; i < project.tasks.length; i++) {
      if (project.tasks[i].id == parentId) {
        final children = List<Task>.from(project.tasks[i].children);
        final task = children.removeAt(oldIndex);
        children.insert(newIndex, task);
        project.tasks[i] = project.tasks[i].copyWith(children: children);
        notifyListeners();
        return;
      }
      if (_reorderChildTasksRecursive(
        project.tasks[i],
        parentId,
        oldIndex,
        newIndex,
      )) {
        notifyListeners();
        return;
      }
    }
  }

  bool _reorderChildTasksRecursive(
    Task current,
    String parentId,
    int oldIndex,
    int newIndex,
  ) {
    for (var i = 0; i < current.children.length; i++) {
      if (current.children[i].id == parentId) {
        final children = List<Task>.from(current.children[i].children);
        final task = children.removeAt(oldIndex);
        children.insert(newIndex, task);
        current.children[i] = current.children[i].copyWith(children: children);
        return true;
      }
      if (_reorderChildTasksRecursive(
        current.children[i],
        parentId,
        oldIndex,
        newIndex,
      )) {
        return true;
      }
    }
    return false;
  }

  /// 依存関係を追加
  void addDependency(String fromTaskId, String toTaskId) {
    if (fromTaskId == toTaskId) return; // 自分自身への依存は不可

    final project = currentProject;
    if (project == null) return;

    // 循環参照チェックは簡易的に省略（必要なら実装）
    _updateTaskDependency(project.tasks, toTaskId, fromTaskId, true);
    notifyListeners();
  }

  /// 依存関係を削除
  void removeDependency(String fromTaskId, String toTaskId) {
    final project = currentProject;
    if (project == null) return;

    _updateTaskDependency(project.tasks, toTaskId, fromTaskId, false);
    notifyListeners();
  }

  void _updateTaskDependency(
    List<Task> tasks,
    String targetTaskId,
    String dependencyId,
    bool isAdd,
  ) {
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i].id == targetTaskId) {
        List<String> newDependencies = List.from(tasks[i].dependencies);
        if (isAdd) {
          if (!newDependencies.contains(dependencyId)) {
            newDependencies.add(dependencyId);
          }
        } else {
          newDependencies.remove(dependencyId);
        }
        tasks[i] = tasks[i].copyWith(dependencies: newDependencies);
        return;
      }
      _updateTaskDependency(
        tasks[i].children,
        targetTaskId,
        dependencyId,
        isAdd,
      );
    }
  }

  /// サンプルデータを読み込み
  void loadSampleData() {
    _projects = [
      Project(
        id: 'p1',
        name: '業務システム開発',
        description: '基幹業務システムの刷新プロジェクト',
        createdAt: DateTime.now(),
        tasks: [
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
            ],
          ),
        ],
      ),
      Project(
        id: 'p2',
        name: 'ウェブサイトリニューアル',
        description: 'コーポレートサイトの全面リニューアル',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        tasks: [
          Task(
            id: 'w1',
            name: 'デザイン作成',
            description: 'トップページと下層ページのデザイン',
            startDate: DateTime(2025, 2, 1),
            endDate: DateTime(2025, 2, 14),
            progress: 0.2,
            color: Colors.purple,
          ),
          Task(
            id: 'w2',
            name: 'コーディング',
            description: 'HTML/CSS/JS実装',
            startDate: DateTime(2025, 2, 15),
            endDate: DateTime(2025, 2, 28),
            progress: 0.0,
            color: Colors.cyan,
          ),
        ],
      ),
    ];

    // 最初のプロジェクトを選択
    if (_projects.isNotEmpty) {
      _currentProjectId = _projects.first.id;
    }

    notifyListeners();
  }
}

/// タスクと階層レベルを保持するクラス
class TaskWithLevel {
  final Task task;
  final int level;

  TaskWithLevel({required this.task, required this.level});
}
