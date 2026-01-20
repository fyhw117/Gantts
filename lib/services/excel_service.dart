import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show Color;

import '../models/task_model.dart';
import '../models/project_model.dart';

class ExcelService {
  static const String sheetName = 'Tasks';
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// タスクをExcelファイルとしてエクスポート・保存・共有する
  Future<void> exportTasks(Project project, List<Task> tasks) async {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final Sheet sheet = excel[sheetName];

    // ヘッダー作成
    final headers = [
      'ID',
      'ParentID',
      'Name',
      'StartDate',
      'EndDate',
      'Progress',
      'Color', // Hex string
      'Dependencies', // Comma separated IDs
      'Description',
    ];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // データ行作成
    // 親IDを特定するために、階層構造をトラバースするヘルパーが必要
    // しかし、Taskモデルには親IDが含まれていないため、flatten時に親IDを渡すなどの工夫が必要
    // ここでは、TaskProvider側からフラットなタスクリストを受け取るのではなく、
    // ルートタスクを受け取ってここ再帰的に処理する方が確実だが、
    // 既存の getAllTasks() があるなら、それを活用しつつ親子関係をマッピングする。
    // 今回は TaskProvider.getAllTasks() は単なるフラットリストで親情報がない。
    // 正確な親子関係を得るには、project.tasks (ルートタスクのリスト) からトラバースする。

    for (var rootTask in project.tasks) {
      _appendTaskRecursive(sheet, rootTask, null);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final fileName =
        '${project.name}_${_dateFormat.format(DateTime.now())}.xlsx';

    if (kIsWeb) {
      // Web: Download
      final blob = html.Blob([fileBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile: Share
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(fileBytes);
      await Share.shareXFiles([XFile(path)], text: 'Exported Tasks');
    }
  }

  void _appendTaskRecursive(Sheet sheet, Task task, String? parentId) {
    final row = [
      TextCellValue(task.id),
      TextCellValue(parentId ?? ''),
      TextCellValue(task.name),
      TextCellValue(_dateFormat.format(task.startDate)),
      TextCellValue(_dateFormat.format(task.endDate)),
      DoubleCellValue(task.progress),
      TextCellValue(task.color.value.toRadixString(16)),
      TextCellValue(task.dependencies.join(',')),
      TextCellValue(task.description),
    ];
    sheet.appendRow(row);

    for (var child in task.children) {
      _appendTaskRecursive(sheet, child, task.id);
    }
  }

  /// Excelファイルを選択してインポートし、タスクのリスト（階層構造込み）を返す
  Future<List<Task>> importTasks() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return [];
    }

    final bytes = result.files.first.bytes;
    if (bytes == null) return [];

    final excel = Excel.decodeBytes(bytes);
    if (!excel.tables.containsKey(sheetName)) {
      // シート名が違う場合は最初のシートを使う
      if (excel.tables.isNotEmpty) {
        return _parseSheet(excel.tables[excel.tables.keys.first]!);
      }
      return [];
    }

    return _parseSheet(excel.tables[sheetName]!);
  }

  List<Task> _parseSheet(Sheet sheet) {
    // 0行目はヘッダーと仮定
    if (sheet.maxRows < 2) return [];

    // ヘルパー: CellValueから値を取り出す
    dynamic _getCellValue(CellValue? cellValue) {
      if (cellValue is TextCellValue) {
        return cellValue.value;
      } else if (cellValue is IntCellValue) {
        return cellValue.value;
      } else if (cellValue is DoubleCellValue) {
        return cellValue.value;
      } else if (cellValue is DateCellValue) {
        // DateCellValue might have year, month, day, etc.
        // For now return string representation or handle specifically if needed.
        return cellValue.toString();
      }
      return cellValue?.toString();
    }

    final List<Map<String, dynamic>> rawTasks = [];
    final headerRow = sheet.row(0);
    // Header handling
    final headers = headerRow.map((c) {
      final val = _getCellValue(c?.value);
      return val?.toString() ?? '';
    }).toList();

    // カラムインデックスの特定
    final idIndex = headers.indexOf('ID');
    final parentIdIndex = headers.indexOf('ParentID');
    final nameIndex = headers.indexOf('Name');
    final startDateIndex = headers.indexOf('StartDate');
    final endDateIndex = headers.indexOf('EndDate');
    final progressIndex = headers.indexOf('Progress');
    final colorIndex = headers.indexOf('Color');
    final depIndex = headers.indexOf('Dependencies');
    final descIndex = headers.indexOf('Description');

    if (idIndex == -1 || nameIndex == -1) return []; // 必須カラム

    for (var i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      // 空行スキップ判定
      if (row.isEmpty || row.every((c) => c == null || c.value == null))
        continue;

      // ヘルパー: セル値取得
      String getStr(int idx) {
        if (idx < 0 || idx >= row.length || row[idx] == null) return '';
        final val = _getCellValue(row[idx]!.value);
        return val?.toString() ?? '';
      }

      double getDouble(int idx) {
        if (idx < 0 || idx >= row.length || row[idx] == null) return 0.0;
        final val = _getCellValue(row[idx]!.value);
        if (val is double) return val;
        if (val is int) return val.toDouble();
        if (val is String) return double.tryParse(val) ?? 0.0;
        return 0.0;
      }

      rawTasks.add({
        'id': getStr(idIndex),
        'parentId': getStr(parentIdIndex),
        'name': getStr(nameIndex),
        'startDate': getStr(startDateIndex),
        'endDate': getStr(endDateIndex),
        'progress': getDouble(progressIndex),
        'color': getStr(colorIndex),
        'dependencies': getStr(depIndex),
        'description': getStr(descIndex),
      });
    }

    // 再構築: IDマップ作成
    final Map<String, Task> taskMap = {};
    final Map<String, String?> parentMap = {}; // TaskID -> ParentID

    for (var raw in rawTasks) {
      final id = raw['id'] as String;
      if (id.isEmpty) continue; // IDなしはスキップ

      final name = raw['name'] as String;
      final startDateStr = raw['startDate'] as String;
      final endDateStr = raw['endDate'] as String;
      final progress = raw['progress'] as double;
      final colorStr = raw['color'] as String;
      final depStr = raw['dependencies'] as String;
      final desc = raw['description'] as String;
      final parentId = raw['parentId'] as String;

      // Date Parsing
      DateTime start = DateTime.tryParse(startDateStr) ?? DateTime.now();
      DateTime end = DateTime.tryParse(endDateStr) ?? DateTime.now();

      // Color Parsing
      Color color = const Color(0xFF42A5F5);
      if (colorStr.isNotEmpty) {
        final hex = int.tryParse(colorStr, radix: 16);
        if (hex != null) {
          // Alpha値が含まれていない場合、不透明にする処理などは適宜
          // カラーコードがFF******形式であることを期待
          color = Color(hex);
        }
      }

      // Dependencies
      List<String> deps = depStr.isNotEmpty
          ? depStr.split(',').where((s) => s.isNotEmpty).toList()
          : [];

      final task = Task(
        id: id,
        name: name,
        description: desc,
        startDate: start,
        endDate: end,
        progress: progress,
        color: color,
        dependencies: deps,
        children: [],
        isExpanded: true,
      );

      taskMap[id] = task;
      parentMap[id] = parentId.isEmpty ? null : parentId;
    }

    // ツリー構築
    final List<Task> rootTasks = [];

    for (var id in taskMap.keys) {
      final task = taskMap[id]!;
      final parentId = parentMap[id];

      if (parentId != null && taskMap.containsKey(parentId)) {
        taskMap[parentId]!.children.add(task);
      } else {
        rootTasks.add(task);
      }
    }

    return rootTasks;
  }
}
