import 'package:flutter/material.dart';

void main() {
  print(parseTimeStrToMinutes('02:15 ã'));
  print(parseTimeStrToMinutes('02:15 Õ'));
  print(parseTimeStrToMinutes('10:30'));
  print(parseTimeStrToMinutes('12:00 ã'));
}

int? parseTimeStrToMinutes(String timeStr) {
  if (timeStr.isEmpty || timeStr == '--:--') return null;
  
  timeStr = timeStr.trim();
  int addMins = 0;
  if (timeStr.toLowerCase().contains('pm') || timeStr.contains('ã')) {
    addMins = 12 * 60;
  }
  
  // Extract hours and minutes using regex
  final RegExp timeRegex = RegExp(r'(\d+)\s*:\s*(\d+)');
  final match = timeRegex.firstMatch(timeStr);
  
  if (match != null && match.groupCount >= 2) {
    final hours = int.tryParse(match.group(1)!) ?? 0;
    final minutes = int.tryParse(match.group(2)!) ?? 0;
    
    int total = hours * 60 + minutes + addMins;
    
    if (addMins > 0 && hours == 12) {
      total -= 12 * 60;
    }
    if (addMins == 0 && hours == 12 && (timeStr.toLowerCase().contains('am') || timeStr.contains('Õ'))) {
      total -= 12 * 60;
    }
    return total;
  }
  return null;
}
