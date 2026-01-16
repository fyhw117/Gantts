import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/project_model.dart';

class FirestoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Projects ---

  /// ユーザーのプロジェクト一覧を取得 (Stream)
  Stream<List<Project>> getProjectsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Project.fromMap(doc.data()))
              .toList();
        });
  }

  /// プロジェクトを追加
  Future<void> addProject(String userId, Project project) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(project.id)
        .set(project.toMap());
  }

  /// プロジェクトを更新
  Future<void> updateProject(String userId, Project project) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(project.id)
        .update(project.toMap());
  }

  /// プロジェクトを削除
  Future<void> deleteProject(String userId, String projectId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .delete();

    // Note: Subcollections are NOT automatically deleted by Firestore.
    // For a real app, you need a Cloud Function or batch delete logic.
    // For this MVP, we leave the orphaned tasks (or delete manually if feasible).
  }

  // --- Tasks ---

  /// プロジェクト内のタスク一覧を取得
  Future<List<Task>> fetchTasks(String userId, String projectId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .get();

    return snapshot.docs.map((doc) => Task.fromMap(doc.data())).toList();
  }

  /// タスクを追加
  Future<void> addTask(String userId, String projectId, Task task) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .doc(task.id)
        .set(task.toMap());
  }

  /// タスクを更新
  Future<void> updateTask(String userId, String projectId, Task task) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .doc(task.id)
        .update(task.toMap());
  }

  /// タスクを削除
  Future<void> deleteTask(
    String userId,
    String projectId,
    String taskId,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

  /// デフォルトのサンプルプロジェクトを作成
  Future<void> createDefaultProject(String userId) async {
    final project = Project.create(
      name: 'サンプルプロジェクト',
      description: 'GanttChartアプリへようこそ！これはサンプルデータです。',
    );

    // プロジェクトを作成
    await addProject(userId, project);

    // サンプルタスクを作成
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final task1 = Task.create(
      name: 'タスクA',
      startDate: today,
      endDate: today.add(const Duration(days: 2)),
      progress: 1.0,
      color: const Color(0xFFE57373),
    );

    final task2 = Task.create(
      name: 'タスクB',
      startDate: today.add(const Duration(days: 3)),
      endDate: today.add(const Duration(days: 5)),
      progress: 0.5,
      color: const Color(0xFF81C784),
      dependencies: [task1.id],
    );

    final subTask1 = Task.create(
      name: 'タスクB-1',
      startDate: today.add(const Duration(days: 3)),
      endDate: today.add(const Duration(days: 4)),
      progress: 0.8,
      color: const Color(0xFF81C784),
    );

    final subTask2 = Task.create(
      name: 'タスクB-2',
      startDate: today.add(const Duration(days: 4)),
      endDate: today.add(const Duration(days: 5)),
      progress: 0.2,
      color: const Color(0xFF81C784),
    );

    // task2に子タスクを追加
    final task2WithChildren = task2.copyWith(children: [subTask1, subTask2]);

    final task3 = Task.create(
      name: 'タスクC',
      startDate: today.add(const Duration(days: 6)),
      endDate: today.add(const Duration(days: 10)),
      progress: 0.0,
      color: const Color(0xFFFFF176),
      dependencies: [task2.id],
    );

    // タスクを保存 (ルートタスクのみ保存すればOK)
    await addTask(userId, project.id, task1);
    await addTask(userId, project.id, task2WithChildren);
    await addTask(userId, project.id, task3);
  }
}
