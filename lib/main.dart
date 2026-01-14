import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/task_provider.dart';
import 'views/wbs_view.dart';
import 'views/gantt_chart_view.dart';

import 'views/project_list_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TaskProvider()..loadSampleData(),
      child: MaterialApp(
        title: 'WBS & ガントチャート',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF607557),
            primary: const Color(0xFF607557),
            secondary: const Color(0xFFDAAB55),
            tertiary: const Color(0xFFF3D083),
          ),
          useMaterial3: true,
        ),
        home: const MyHomePage(),
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
              ).colorScheme.onPrimary.withOpacity(0.7),
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
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Text(
                    'GanttChart',
                    style: TextStyle(color: Colors.white, fontSize: 24),
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
          body: TabBarView(
            controller: _tabController,
            children: const [WBSView(), GanttChartView()],
          ),
        );
      },
    );
  }
}
