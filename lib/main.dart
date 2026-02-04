import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'providers/task_provider.dart';
import 'views/login_screen.dart';
import 'views/wbs_view.dart';
import 'views/gantt_chart_view.dart';
import 'views/project_list_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TaskProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Gantts',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF607557),
            primary: const Color(0xFF607557),
            secondary: const Color(0xFFDAAB55),
            tertiary: const Color(0xFFF3D083),
          ),
          useMaterial3: true,
        ),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData) {
              return const MyHomePage();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final currentProject = taskProvider.currentProject;
        final title = currentProject != null
            ? currentProject.name
            : 'プロジェクト未選択';

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            title: Text(title, style: const TextStyle(fontSize: 16)),
            toolbarHeight: 40,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onPrimary.withValues(alpha: 0.7),
              indicatorColor: Theme.of(context).colorScheme.onPrimary,
              indicatorWeight: 2.0,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_tree, size: 18),
                      SizedBox(width: 8),
                      Text('WBS'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timeline, size: 18),
                      SizedBox(width: 8),
                      Text('ガントチャート'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          drawer: Drawer(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gantts',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                            const Spacer(),
                            if (taskProvider.userEmail != null)
                              Text(
                                taskProvider.userEmail!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.list),
                        title: const Text('プロジェクト一覧'),
                        onTap: () {
                          Navigator.pop(context); // Close drawer
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProjectListView(),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                        child: Text(
                          'データ連携',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.file_download),
                        title: const Text('Excelエクスポート'),
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            await taskProvider.exportTasksToExcel();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('エクスポートしました')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('エクスポート失敗: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.file_upload),
                        title: const Text('Excelインポート'),
                        onTap: () async {
                          Navigator.pop(context);
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Excelインポート'),
                                content: const Text(
                                  'Excelファイルからタスクを取り込みます。\n'
                                  '現在のプロジェクトにタスクが追加されます。よろしいですか？',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('キャンセル'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('インポート'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed == true) {
                            try {
                              await taskProvider.importTasksFromExcel();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('インポートしました')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('インポート失敗: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'プロジェクト切り替え',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...taskProvider.projects.map((project) {
                        return ListTile(
                          leading: const Icon(Icons.folder),
                          title: Text(project.name),
                          selected: project.id == taskProvider.currentProjectId,
                          onTap: () {
                            taskProvider.selectProject(project.id);
                            Navigator.pop(context);
                          },
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(taskProvider.isAnonymous ? 'ゲスト利用終了' : 'ログアウト'),
                  onTap: () async {
                    Navigator.pop(context);
                    if (taskProvider.isAnonymous) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('ゲスト利用終了'),
                            content: const Text(
                              'ゲスト利用を終了しますか？\n'
                              '保存されたすべてのデータが削除され、復旧できなくなります。',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('終了する'),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmed == true) {
                        try {
                          await taskProvider.deleteAccount();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('エラーが発生しました: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    } else {
                      taskProvider.signOut();
                    }
                  },
                ),
                if (!taskProvider.isAnonymous)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'アカウント削除',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('アカウント削除'),
                            content: const Text(
                              '本当にアカウントを削除しますか？\n'
                              'この操作は取り消せません。\n'
                              '保存されているすべてのデータが失われます。',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('削除する'),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmed == true) {
                        try {
                          await taskProvider.deleteAccount();
                        } on FirebaseAuthException catch (e) {
                          if (context.mounted) {
                            if (e.code == 'requires-recent-login') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'セキュリティのため、再ログインが必要です。一度ログアウトして再度ログインしてからお試しください。',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('エラーが発生しました: ${e.message}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('エラーが発生しました: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: const [WBSView(), GanttChartView()],
          ),
        );
      },
    );
  }
}
