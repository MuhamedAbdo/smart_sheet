import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_sheet/utils/pdf_export_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load font from assets
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    
    final dummyRecords = List.generate(8, (i) => 
      {
        'date': '2026-08-14',
        'technician_name': 'Ahmed',
        'crew_members': ['Ali', 'Omar'],
        'client_name': 'Test Client',
        'product_name': 'Box',
        'product_code': 'B123',
        'dimensions': {'length': 10, 'width': 20, 'height': 30},
        'order_number': 'ORD-001',
        'quantity': 1000,
        'start_time': '08:00',
        'end_time': '12:00',
        'line_waste': 10,
        'print_waste': 5,
        'downtime_start': '10:00',
        'downtime_end': '10:15',
        'notes': 'Test notes',
      }
    );

    print("Calling _generateConsolidatedProductionPdfBytes with isProductionLine = true");
    await generateFlexoProductionReportPdfBytes({
      'records': dummyRecords,
      'font': fontData,
      'bold': boldFontData,
      'isProductionLine': true,
      'title': 'Test Title 1'
    });

    print("Calling _generateConsolidatedProductionPdfBytes with isProductionLine = false");
    await generateFlexoProductionReportPdfBytes({
      'records': dummyRecords,
      'font': fontData,
      'bold': boldFontData,
      'isProductionLine': false,
      'title': 'Test Title 2'
    });

    print("Success!");
  } catch (e, stack) {
    print("Caught error in main: $e\n$stack");
  }
}
