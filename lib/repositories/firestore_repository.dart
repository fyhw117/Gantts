import 'package:cloud_firestore/cloud_firestore.dart';
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
}
