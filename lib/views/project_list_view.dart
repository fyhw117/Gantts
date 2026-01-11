import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../models/project_model.dart';

class ProjectListView extends StatelessWidget {
  const ProjectListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロジェクト一覧'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          final projects = taskProvider.projects;

          if (projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('プロジェクトがありません'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showProjectDialog(context),
                    child: const Text('新しいプロジェクトを作成'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final isSelected = project.id == taskProvider.currentProjectId;

              return Dismissible(
                key: Key(project.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('プロジェクト削除'),
                      content: Text(
                        '"${project.name}" を削除してもよろしいですか？\n含まれるすべてのタスクも削除されます。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('キャンセル'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('削除'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  taskProvider.deleteProject(project.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${project.name} を削除しました')),
                  );
                },
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(project.name.substring(0, 1)),
                  ),
                  title: Text(project.name),
                  subtitle: Text(project.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showProjectDialog(context, project: project),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                  selected: isSelected,
                  onTap: () {
                    taskProvider.selectProject(project.id);
                    Navigator.pop(context); // ドロワーから開かれている場合は閉じる、あるいはメイン画面に戻る
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProjectDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showProjectDialog(BuildContext context, {Project? project}) {
    final nameController = TextEditingController(text: project?.name ?? '');
    final descriptionController = TextEditingController(
      text: project?.description ?? '',
    );
    final isEditing = project != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'プロジェクト編集' : '新しいプロジェクト'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'プロジェクト名'),
              autofocus: true,
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: '説明'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                if (isEditing) {
                  Provider.of<TaskProvider>(
                    context,
                    listen: false,
                  ).updateProject(
                    project.id,
                    name,
                    descriptionController.text.trim(),
                  );
                } else {
                  Provider.of<TaskProvider>(
                    context,
                    listen: false,
                  ).addProject(name, descriptionController.text.trim());
                }
                Navigator.pop(context);
              }
            },
            child: Text(isEditing ? '保存' : '作成'),
          ),
        ],
      ),
    );
  }
}
