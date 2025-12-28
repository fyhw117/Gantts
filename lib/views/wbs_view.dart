import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';

/// WBS（作業分解構成図）ビュー
class WBSView extends StatelessWidget {
  const WBSView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        return Column(
          children: [
            _buildHeader(context, taskProvider),
            Expanded(
              child: taskProvider.rootTasks.isEmpty
                  ? _buildEmptyState()
                  : ReorderableListView.builder(
                      onReorder: (oldIndex, newIndex) {
                        taskProvider.reorderRootTasks(oldIndex, newIndex);
                      },
                      itemCount: taskProvider.rootTasks.length,
                      itemBuilder: (context, index) {
                        final task = taskProvider.rootTasks[index];
                        return _buildTaskTree(
                          context,
                          taskProvider,
                          task,
                          0,
                          key: ValueKey(task.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, TaskProvider taskProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'WBS - 作業分解構成図',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showAddTaskDialog(context, taskProvider, null),
            icon: const Icon(Icons.add),
            label: const Text('タスク追加'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'タスクがありません',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'タスク追加ボタンから新しいタスクを作成してください',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTree(
    BuildContext context,
    TaskProvider taskProvider,
    Task task,
    int level, {
    Key? key,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTaskItem(context, taskProvider, task, level),
        if (task.isExpanded && task.hasChildren)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              taskProvider.reorderChildTasks(task.id, oldIndex, newIndex);
            },
            children: task.children.map((child) {
              return _buildTaskTree(
                context,
                taskProvider,
                child,
                level + 1,
                key: ValueKey(child.id),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTaskItem(
    BuildContext context,
    TaskProvider taskProvider,
    Task task,
    int level,
  ) {
    return Container(
      margin: EdgeInsets.only(left: level * 24.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListTile(
        leading: task.hasChildren
            ? IconButton(
                icon: Icon(
                  task.isExpanded ? Icons.expand_more : Icons.chevron_right,
                ),
                onPressed: () => taskProvider.toggleExpand(task.id),
              )
            : const SizedBox(width: 48),
        title: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              color: task.color,
              margin: const EdgeInsets.only(right: 8),
            ),
            Expanded(
              child: Text(
                task.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(task.description),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${_formatDate(task.startDate)} - ${_formatDate(task.endDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${task.durationInDays}日',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(task.color),
            ),
            const SizedBox(height: 2),
            Text(
              '進捗: ${(task.progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'add_child':
                _showAddTaskDialog(context, taskProvider, task);
                break;
              case 'edit':
                _showEditTaskDialog(context, taskProvider, task);
                break;
              case 'delete':
                _confirmDelete(context, taskProvider, task);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'add_child',
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline),
                  SizedBox(width: 8),
                  Text('子タスク追加'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('編集'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('削除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  void _showAddTaskDialog(
    BuildContext context,
    TaskProvider taskProvider,
    Task? parentTask,
  ) {
    showDialog(
      context: context,
      builder: (context) => TaskEditDialog(
        onSave: (task) {
          taskProvider.addTask(task, parent: parentTask);
        },
        parentTask: parentTask,
      ),
    );
  }

  void _showEditTaskDialog(
    BuildContext context,
    TaskProvider taskProvider,
    Task task,
  ) {
    showDialog(
      context: context,
      builder: (context) => TaskEditDialog(
        task: task,
        onSave: (updatedTask) {
          taskProvider.updateTask(task.id, updatedTask);
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    TaskProvider taskProvider,
    Task task,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タスクの削除'),
        content: Text('「${task.name}」を削除しますか？\n子タスクも同時に削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              taskProvider.deleteTask(task.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

/// タスク編集ダイアログ
class TaskEditDialog extends StatefulWidget {
  final Task? task;
  final Task? parentTask;
  final Function(Task) onSave;

  const TaskEditDialog({
    super.key,
    this.task,
    this.parentTask,
    required this.onSave,
  });

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late DateTime _startDate;
  late DateTime _endDate;
  late double _progress;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _startDate = widget.task?.startDate ?? DateTime.now();
    _endDate = widget.task?.endDate ?? DateTime.now().add(const Duration(days: 7));
    _progress = widget.task?.progress ?? 0.0;
    _color = widget.task?.color ?? Colors.blue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? 'タスク追加' : 'タスク編集'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'タスク名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '説明',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('開始日'),
              subtitle: Text(_formatDate(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() => _startDate = date);
                }
              },
            ),
            ListTile(
              title: const Text('終了日'),
              subtitle: Text(_formatDate(_endDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() => _endDate = date);
                }
              },
            ),
            const SizedBox(height: 16),
            Text('進捗: ${(_progress * 100).toStringAsFixed(0)}%'),
            Slider(
              value: _progress,
              onChanged: (value) => setState(() => _progress = value),
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: '${(_progress * 100).toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 16),
            const Text('色'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Colors.blue,
                Colors.green,
                Colors.orange,
                Colors.red,
                Colors.purple,
                Colors.teal,
                Colors.pink,
                Colors.amber,
              ].map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _color = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _color == color
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('タスク名を入力してください')),
              );
              return;
            }

            final task = Task(
              id: widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              name: _nameController.text,
              description: _descriptionController.text,
              startDate: _startDate,
              endDate: _endDate,
              progress: _progress,
              color: _color,
              children: widget.task?.children ?? [],
              isExpanded: widget.task?.isExpanded ?? false,
            );

            widget.onSave(task);
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
