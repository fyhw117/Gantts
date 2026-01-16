import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/project_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/firestore_repository.dart';

/// タスクデータを管理するProvider
class TaskProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final FirestoreRepository _firestoreRepository = FirestoreRepository();

  List<Project> _projects = [];
  String? _currentProjectId;
  String? _userId;
  StreamSubscription? _authSubscription;
  StreamSubscription? _projectsSubscription;

  TaskProvider() {
    _initialize();
  }

  void _initialize() {
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      _userId = user?.uid;
      _projectsSubscription?.cancel();
      if (_userId != null) {
        _subscribeToProjects();
      } else {
        _projects = [];
        _currentProjectId = null;
        notifyListeners();
      }
    });
  }

  void _subscribeToProjects() {
    if (_userId == null) return;
    _projectsSubscription = _firestoreRepository
        .getProjectsStream(_userId!)
        .listen((projects) {
          // 既存のタスクデータを保持するためのマップを作成
          final Map<String, List<Task>> existingTasks = {};
          for (var p in _projects) {
            existingTasks[p.id] = p.tasks;
          }

          _projects = projects;

          // プロジェクトIDが同じならタスクを復元（再フェッチまでのつなぎ）
          for (var i = 0; i < _projects.length; i++) {
            if (existingTasks.containsKey(_projects[i].id)) {
              _projects[i] = _projects[i].copyWith(
                tasks: existingTasks[_projects[i].id],
              );
            }
          }

          if (_currentProjectId == null && _projects.isNotEmpty) {
            selectProject(_projects.first.id);
          } else if (_currentProjectId != null &&
              !_projects.any((p) => p.id == _currentProjectId)) {
            // 現在のプロジェクトが削除された場合
            _currentProjectId = _projects.isNotEmpty
                ? _projects.first.id
                : null;
            if (_currentProjectId != null) {
              _fetchTasksForCurrentProject();
            }
          }
          notifyListeners();
        });
  }

  Future<void> _fetchTasksForCurrentProject() async {
    if (_userId == null || _currentProjectId == null) return;

    final projectId = _currentProjectId!;
    try {
      final tasks = await _firestoreRepository.fetchTasks(_userId!, projectId);

      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = _projects[index].copyWith(tasks: tasks);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _projectsSubscription?.cancel();
    super.dispose();
  }

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
  Future<void> addProject(String name, String description) async {
    if (_userId == null) return;
    final newProject = Project.create(name: name, description: description);
    // Optimistic update
    _projects.add(newProject);
    _currentProjectId = newProject.id;
    notifyListeners();

    await _firestoreRepository.addProject(_userId!, newProject);
  }

  /// プロジェクトを選択
  void selectProject(String projectId) {
    if (_projects.any((p) => p.id == projectId)) {
      _currentProjectId = projectId;
      notifyListeners();
      _fetchTasksForCurrentProject();
    }
  }

  /// プロジェクト情報を更新
  Future<void> updateProject(
    String projectId,
    String name,
    String description,
  ) async {
    if (_userId == null) return;
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index != -1) {
      final updatedProject = _projects[index].copyWith(
        name: name,
        description: description,
      );
      _projects[index] = updatedProject;
      notifyListeners();

      await _firestoreRepository.updateProject(_userId!, updatedProject);
    }
  }

  /// プロジェクトを削除
  Future<void> deleteProject(String projectId) async {
    if (_userId == null) return;

    _projects.removeWhere((p) => p.id == projectId);
    if (_currentProjectId == projectId) {
      _currentProjectId = _projects.isNotEmpty ? _projects.first.id : null;
      if (_currentProjectId != null) {
        _fetchTasksForCurrentProject();
      }
    }
    notifyListeners();

    await _firestoreRepository.deleteProject(_userId!, projectId);
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

  /// Task Saving Logic
  Future<void> _saveRootTask(Task rootTask) async {
    if (_userId == null || _currentProjectId == null) return;
    await _firestoreRepository.updateTask(
      _userId!,
      _currentProjectId!,
      rootTask,
    );
  }

  Future<void> _addRootTaskToFirestore(Task rootTask) async {
    if (_userId == null || _currentProjectId == null) return;
    await _firestoreRepository.addTask(_userId!, _currentProjectId!, rootTask);
  }

  Future<void> _deleteRootTaskFromFirestore(Task rootTask) async {
    if (_userId == null || _currentProjectId == null) return;
    await _firestoreRepository.deleteTask(
      _userId!,
      _currentProjectId!,
      rootTask.id,
    );
  }

  /// タスクを追加
  void addTask(Task task, {Task? parent}) {
    final project = currentProject;
    if (project == null || _userId == null) return;

    if (parent == null) {
      project.tasks.add(task);
      notifyListeners();
      _addRootTaskToFirestore(task);
    } else {
      _addChildTask(project.tasks, parent.id, task);
    }
  }

  void _addChildTask(List<Task> tasks, String parentId, Task task) {
    if (_userId == null || _currentProjectId == null) return;

    final rootIndex = tasks.indexWhere(
      (r) => r.id == parentId || r.flatten().any((t) => t.id == parentId),
    );
    if (rootIndex != -1) {
      var root = tasks[rootIndex];
      final newRoot = _insertChildIntoTask(root, parentId, task);
      if (newRoot != null) {
        tasks[rootIndex] = newRoot;
        notifyListeners();
        _saveRootTask(newRoot);
      }
    }
  }

  Task? _insertChildIntoTask(Task current, String parentId, Task newTask) {
    if (current.id == parentId) {
      return current.copyWith(children: [...current.children, newTask]);
    }
    List<Task> newChildren = [];
    bool changed = false;
    for (var child in current.children) {
      final updatedChild = _insertChildIntoTask(child, parentId, newTask);
      if (updatedChild != null) {
        newChildren.add(updatedChild);
        changed = true;
      } else {
        newChildren.add(child);
      }
    }
    if (changed) {
      return current.copyWith(children: newChildren);
    }
    for (int i = 0; i < current.children.length; i++) {
      final update = _insertChildIntoTask(
        current.children[i],
        parentId,
        newTask,
      );
      if (update != null) {
        List<Task> children = List.from(current.children);
        children[i] = update;
        return current.copyWith(children: children);
      }
    }
    return null;
  }

  /// タスクを更新
  void updateTask(String taskId, Task updatedTask) {
    final project = currentProject;
    if (project == null || _userId == null) return;

    for (var i = 0; i < project.tasks.length; i++) {
      if (project.tasks[i].id == taskId) {
        // Updating a root task
        project.tasks[i] = updatedTask;
        notifyListeners();
        _saveRootTask(updatedTask);
        return;
      }

      final newRoot = _updateTaskInTree(project.tasks[i], taskId, updatedTask);
      if (newRoot != null) {
        project.tasks[i] = newRoot;
        notifyListeners();
        _saveRootTask(newRoot);
        return;
      }
    }
  }

  Task? _updateTaskInTree(Task current, String targetId, Task updatedTask) {
    for (int i = 0; i < current.children.length; i++) {
      if (current.children[i].id == targetId) {
        List<Task> children = List.from(current.children);
        children[i] = updatedTask;
        return current.copyWith(children: children);
      }
      final updatedChild = _updateTaskInTree(
        current.children[i],
        targetId,
        updatedTask,
      );
      if (updatedChild != null) {
        List<Task> children = List.from(current.children);
        children[i] = updatedChild;
        return current.copyWith(children: children);
      }
    }
    return null;
  }

  /// タスクを削除
  void deleteTask(String taskId) {
    final project = currentProject;
    if (project == null || _userId == null) return;

    // Check if root
    final rootIndex = project.tasks.indexWhere((t) => t.id == taskId);
    if (rootIndex != -1) {
      final task = project.tasks[rootIndex];
      project.tasks.removeAt(rootIndex);
      notifyListeners();
      _deleteRootTaskFromFirestore(task);
      return;
    }

    // Check children
    for (int i = 0; i < project.tasks.length; i++) {
      final newRoot = _deleteTaskFromTree(project.tasks[i], taskId);
      if (newRoot != null) {
        project.tasks[i] = newRoot;
        notifyListeners();
        _saveRootTask(newRoot);
        return;
      }
    }
  }

  Task? _deleteTaskFromTree(Task current, String targetId) {
    List<Task> children = List.from(current.children);
    int initialLen = children.length;
    children.removeWhere((t) => t.id == targetId);

    if (children.length < initialLen) {
      return current.copyWith(children: children);
    }

    for (int i = 0; i < children.length; i++) {
      final updatedChild = _deleteTaskFromTree(children[i], targetId);
      if (updatedChild != null) {
        children[i] = updatedChild;
        return current.copyWith(children: children);
      }
    }

    return null;
  }

  /// タスクの展開状態を切り替え
  void toggleExpand(String taskId) {
    final project = currentProject;
    if (project == null) return;

    final task = project.tasks
        .expand((t) => t.flatten())
        .firstWhere((t) => t.id == taskId);
    updateTask(taskId, task.copyWith(isExpanded: !task.isExpanded));
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
    // TODO: Save order to Firestore
  }

  /// 子タスクの順序を変更
  void reorderChildTasks(String parentId, int oldIndex, int newIndex) {
    final project = currentProject;
    if (project == null) return;

    final parent = project.tasks
        .expand((t) => t.flatten())
        .firstWhere((t) => t.id == parentId);

    final children = List<Task>.from(parent.children);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = children.removeAt(oldIndex);
    children.insert(newIndex, item);

    updateTask(parentId, parent.copyWith(children: children));
  }

  /// 依存関係を追加/削除
  void addDependency(String fromTaskId, String toTaskId) {
    final project = currentProject;
    if (project == null) return;

    final target = project.tasks
        .expand((t) => t.flatten())
        .firstWhere((t) => t.id == toTaskId);
    if (target.dependencies.contains(fromTaskId)) return;

    final newDeps = List<String>.from(target.dependencies)..add(fromTaskId);
    updateTask(toTaskId, target.copyWith(dependencies: newDeps));
  }

  void removeDependency(String fromTaskId, String toTaskId) {
    final project = currentProject;
    if (project == null) return;
    final target = project.tasks
        .expand((t) => t.flatten())
        .firstWhere((t) => t.id == toTaskId);

    final newDeps = List<String>.from(target.dependencies)..remove(fromTaskId);
    updateTask(toTaskId, target.copyWith(dependencies: newDeps));
  }
}

/// タスクと階層レベルを保持するクラス
class TaskWithLevel {
  final Task task;
  final int level;

  TaskWithLevel({required this.task, required this.level});
}
