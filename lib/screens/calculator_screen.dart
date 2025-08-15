// lib/src/screens/utils/calculator_screen.dart

import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = "";
  String _result = "";
  bool _isResultDisplayed = false;

  void _onButtonPressed(String value) {
    setState(() {
      if (value == "C") {
        _expression = "";
        _result = "";
        _isResultDisplayed = false;
      } else if (value == "=") {
        try {
          // ✅ تنسيق التعبير
          String formattedExpression = _expression
              .replaceAll('x', '*')
              .replaceAll('÷', '/')
              .replaceAll('%', '/100');

          // ✅ استخدام Parser() (لا يزال شغال في ^2.5.0)
          Parser parser = Parser();
          Expression exp = parser.parse(formattedExpression);

          // ✅ ContextModel لتقييم التعبير
          ContextModel contextModel = ContextModel();
          double eval = exp.evaluate(EvaluationType.REAL, contextModel);

          // ✅ تنسيق الناتج
          _result = (eval % 1 == 0)
              ? eval.toInt().toString()
              : eval.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '');
          _isResultDisplayed = true;
        } catch (e) {
          _result = "خطأ";
          _isResultDisplayed = true;
        }
      } else if (value == "⌫") {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else {
        if (_isResultDisplayed) {
          if (RegExp(r'[0-9.]').hasMatch(value)) {
            _expression = value;
            _result = "";
          } else {
            _expression = _result + value;
            _result = "";
          }
        } else {
          _expression += value;
        }
        _isResultDisplayed = false;
      }
    });
  }

  Widget _buildButton(String text,
      {Color? color, Color? textColor, VoidCallback? onPressed}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    Color fgColor;

    if (color != null) {
      bgColor = color;
    } else if (text == "C") {
      bgColor = Colors.orange.shade300;
    } else if (text == "⌫") {
      bgColor = Colors.red.shade400;
    } else if (text == "=") {
      bgColor = Colors.blue.shade600;
    } else {
      bgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    }

    fgColor = textColor ??
        (bgColor == Colors.grey.shade800 || bgColor == Colors.grey.shade200
            ? (isDark ? Colors.white : Colors.black)
            : Colors.white);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: onPressed ?? () => _onButtonPressed(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            textStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          child: Text(text, style: TextStyle(color: fgColor, fontSize: 20)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("الآلة الحاسبة"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // النتيجة
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade900
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expression.isEmpty ? "0" : _expression,
                      style: TextStyle(
                        fontSize: 28,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result.isEmpty ? "0" : _result,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // الصفوف
            _buildRow(["(", ")", "C", "⌫"]),
            _buildRow(["7", "8", "9", "÷"]),
            _buildRow(["4", "5", "6", "x"]),
            _buildRow(["1", "2", "3", "-"]),
            _buildRow(["%", "0", ".", "+"]),
            _buildRow(["="], isLastRow: true), // الزر = فقط
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> buttons, {bool isLastRow = false}) {
    return Row(
      children: [
        for (int i = 0; i < buttons.length; i++) ...[
          if (isLastRow && buttons[i] == "=")
            Expanded(
              flex: 2,
              child: _buildButton(
                "=",
                color: Colors.blue.shade600,
                textColor: Colors.white,
              ),
            )
          else
            _buildButton(buttons[i]),
          if (i < buttons.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
