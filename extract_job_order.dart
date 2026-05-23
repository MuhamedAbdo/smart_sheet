// ignore_for_file: avoid_print, unused_local_variable

import 'dart:io';
import 'dart:convert';

void main() {
  const transcriptPath =
      r"C:\Users\MuhamedAbdo\.gemini\antigravity\brain\f10ec95e-c0a3-48cd-979f-d993502637d7\.system_generated\logs\transcript.jsonl";
  final file = File(transcriptPath);

  if (!file.existsSync()) {
    print("Error: transcript file not found at $transcriptPath");
    return;
  }

  String serviceCode = "";
  String dialogCode = "";

  final lines = file.readAsLinesSync();
  final lineRegex = RegExp(r"^\s*(\d+):\s(.*)$");

  for (final line in lines) {
    try {
      final data = jsonDecode(line) as Map<String, dynamic>;
      final type = data["type"];
      final content = data["content"]?.toString() ?? "";
      final toolCalls = data["tool_calls"] as List<dynamic>?;

      // 1. Extract from tool_calls (write_to_file)
      if (toolCalls != null) {
        for (final tc in toolCalls) {
          final name = tc["name"];
          final args = tc["args"] as Map<String, dynamic>?;
          if (args != null) {
            final targetFile = args["TargetFile"]?.toString() ?? "";
            final codeContent = args["CodeContent"]?.toString() ?? "";

            if (targetFile.contains("job_order_service.dart") &&
                codeContent.isNotEmpty) {
              serviceCode = codeContent;
            }
            if (targetFile.contains("job_order_dialog.dart") &&
                codeContent.isNotEmpty) {
              dialogCode = codeContent;
            }
          }
        }
      }

      // 2. Fallback or override from VIEW_FILE outputs
      if (type == "VIEW_FILE" || type == "CODE_ACTION") {
        if (content.contains("class JobOrderService") ||
            content.contains("class JobOrderData")) {
          if (content.contains("Total Lines:")) {
            final contentLines = content.split("\n");
            final List<String> codeLines = [];
            for (final l in contentLines) {
              final match = lineRegex.firstMatch(l);
              if (match != null) {
                codeLines.add(match.group(2)!);
              }
            }
            if (codeLines.isNotEmpty) {
              serviceCode = codeLines.join("\n");
            }
          }
        }
        if (content.contains("class JobOrderDialog")) {
          if (content.contains("Total Lines:")) {
            final contentLines = content.split("\n");
            final List<String> codeLines = [];
            for (final l in contentLines) {
              final match = lineRegex.firstMatch(l);
              if (match != null) {
                codeLines.add(match.group(2)!);
              }
            }
            if (codeLines.isNotEmpty) {
              dialogCode = codeLines.join("\n");
            }
          }
        }
      }
    } catch (e) {
      // ignore
    }
  }

  print("Extracted service code length: ${serviceCode.length}");
  print("Extracted dialog code length: ${dialogCode.length}");

  if (serviceCode.isNotEmpty) {
    File("d:/projects/smart_sheet/lib/services/job_order_service.dart")
      ..createSync(recursive: true)
      ..writeAsStringSync(serviceCode);
    print("Wrote service file successfully!");
  } else {
    print("Warning: service code was empty!");
  }

  if (dialogCode.isNotEmpty) {
    File("d:/projects/smart_sheet/lib/screens/job_order_dialog.dart")
      ..createSync(recursive: true)
      ..writeAsStringSync(dialogCode);
    print("Wrote dialog file successfully!");
  } else {
    print("Warning: dialog code was empty!");
  }
}
