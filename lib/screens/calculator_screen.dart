// lib/screens/calculator_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = "";
  String _result = "";
  bool _isResultDisplayed = false;
  bool _isScientificMode = false;
  bool _is2nd = false;
  bool _isDegreeMode = true;
  final List<String> _history = [];

  void _onButtonPressed(String value) {
    setState(() {
      if (value == "AC") {
        _expression = "";
        _result = "";
        _isResultDisplayed = false;
      } else if (value == "backspace") {
        if (_isResultDisplayed) {
          _expression = _result;
          _result = "";
          _isResultDisplayed = false;
          if (_expression.isNotEmpty) {
            _expression = _expression.substring(0, _expression.length - 1);
          }
        } else if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (value == "toggle_scientific") {
        _isScientificMode = !_isScientificMode;
      } else if (value == "2nd") {
        _is2nd = !_is2nd;
      } else if (value == "deg") {
        _isDegreeMode = !_isDegreeMode;
      } else if (value == "=") {
        _calculateResult();
      } else {
        _handleInput(value);
      }
    });
  }

  void _handleInput(String value) {
    final isOperator = ["+", "-", "×", "÷"].contains(value);

    if (_isResultDisplayed) {
      if (isOperator) {
        _expression = _result + (value == "-" ? " - " : " $value ");
      } else if (value == "%") {
        _expression = "$_result%";
      } else if (value == "xʸ") {
        _expression = _is2nd ? "$_result^2" : "$_result^";
      } else if (value == "x!") {
        _expression = "$_result!";
      } else if (value == "1/x") {
        _expression = "1/($_result)";
      } else if (["sin", "cos", "tan", "ln", "lg", "√x", "("].contains(value)) {
        String funcStr = "";
        if (value == "sin") {
          funcStr = _is2nd ? "asin(" : "sin(";
        } else if (value == "cos") {
          funcStr = _is2nd ? "acos(" : "cos(";
        } else if (value == "tan") {
          funcStr = _is2nd ? "atan(" : "tan(";
        } else if (value == "ln") {
          funcStr = _is2nd ? "e^(" : "ln(";
        } else if (value == "lg") {
          funcStr = _is2nd ? "10^(" : "log(10, ";
        } else if (value == "√x") {
          funcStr = _is2nd ? "cbrt(" : "sqrt(";
        } else if (value == "(") {
          funcStr = "(";
        }
        _expression = funcStr;
      } else if (["π", "e"].contains(value)) {
        _expression = value;
      } else {
        _expression = value == "." ? "0." : value;
      }
      _result = "";
      _isResultDisplayed = false;
      return;
    }

    if (isOperator) {
      if (_expression.isEmpty) {
        if (value == "-") {
          _expression = "-";
        }
        return;
      }

      String trimmed = _expression.trimRight();
      if (trimmed.endsWith("+") ||
          trimmed.endsWith("-") ||
          trimmed.endsWith("×") ||
          trimmed.endsWith("÷")) {
        trimmed = trimmed.substring(0, trimmed.length - 1).trimRight();
        _expression = "$trimmed $value ";
      } else {
        _expression = "$trimmed $value ";
      }
    } else if (value == "%") {
      if (_expression.isNotEmpty && !_expression.trim().endsWith("%")) {
        _expression = "${_expression.trim()}%";
      }
    } else if (value == "xʸ") {
      if (_expression.isNotEmpty) {
        _expression =
            _is2nd ? "${_expression.trim()}^2" : "${_expression.trim()}^";
      }
    } else if (value == "x!") {
      if (_expression.isNotEmpty && !_expression.trim().endsWith("!")) {
        _expression = "${_expression.trim()}!";
      }
    } else if (value == "1/x") {
      if (_expression.isEmpty) {
        _expression = "1/";
      } else {
        _expression = "1/(${_expression.trim()})";
      }
    } else if (["sin", "cos", "tan", "ln", "lg", "√x", "(", ")"]
        .contains(value)) {
      String funcStr = "";
      if (value == "sin") {
        funcStr = _is2nd ? "asin(" : "sin(";
      } else if (value == "cos") {
        funcStr = _is2nd ? "acos(" : "cos(";
      } else if (value == "tan") {
        funcStr = _is2nd ? "atan(" : "tan(";
      } else if (value == "ln") {
        funcStr = _is2nd ? "e^(" : "ln(";
      } else if (value == "lg") {
        funcStr = _is2nd ? "10^(" : "log(10, ";
      } else if (value == "√x") {
        funcStr = _is2nd ? "cbrt(" : "sqrt(";
      } else {
        funcStr = value;
      }

      _expression += funcStr;
    } else if (["π", "e"].contains(value)) {
      _expression += value;
    } else if (value == ".") {
      final tokens = _expression.split(RegExp(r'[\s+\-×÷^()]'));
      final currentToken = tokens.isNotEmpty ? tokens.last : "";
      if (!currentToken.contains(".")) {
        if (currentToken.isEmpty) {
          _expression += "0.";
        } else {
          _expression += ".";
        }
      }
    } else {
      _expression += value;
    }
  }

  void _calculateResult() {
    if (_expression.trim().isEmpty) return;
    try {
      String formattedExpression = _expression
          .replaceAll('×', '*')
          .replaceAll('x', '*')
          .replaceAll('÷', '/')
          .replaceAll('%', '/100')
          .replaceAll('π', '3.141592653589793')
          .replaceAll(RegExp(r'\be\b'), '2.718281828459045');

      formattedExpression =
          formattedExpression.replaceAllMapped(RegExp(r'(\d+)!'), (match) {
        int n = int.parse(match.group(1)!);
        if (n < 0 || n > 20) return "0";
        int result = 1;
        for (int i = 2; i <= n; i++) {
          result *= i;
        }
        return result.toString();
      });

      String cleanExpr = formattedExpression.trimRight();
      while (cleanExpr.endsWith('+') ||
          cleanExpr.endsWith('-') ||
          cleanExpr.endsWith('*') ||
          cleanExpr.endsWith('/') ||
          cleanExpr.endsWith('^')) {
        cleanExpr = cleanExpr.substring(0, cleanExpr.length - 1).trimRight();
      }

      int openCount = '('.allMatches(cleanExpr).length;
      int closeCount = ')'.allMatches(cleanExpr).length;
      if (openCount > closeCount) {
        cleanExpr += ')' * (openCount - closeCount);
      }

      if (cleanExpr.isEmpty) return;

      ShuntingYardParser parser = ShuntingYardParser();
      Expression exp = parser.parse(cleanExpr);
      ContextModel contextModel = ContextModel();
      // ignore: deprecated_member_use
      double eval = exp.evaluate(EvaluationType.REAL, contextModel);

      if (eval.isNaN || eval.isInfinite) {
        _result = "خطأ في العملية";
        _isResultDisplayed = true;
        return;
      }

      String resString = (eval % 1 == 0)
          ? eval.toInt().toString()
          : eval
              .toStringAsFixed(6)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');

      final historyEntry = "${_expression.trim()} = $resString";
      if (_history.isEmpty || _history.last != historyEntry) {
        _history.add(historyEntry);
      }

      _result = resString;
      _isResultDisplayed = true;
    } catch (e) {
      _result = "خطأ";
      _isResultDisplayed = true;
    }
  }

  String _formatWithCommas(String text) {
    if (text.isEmpty || text == "خطأ" || text == "خطأ في العملية") return text;
    return text.replaceAllMapped(RegExp(r'\b(\d+)(\.\d+)?\b'), (match) {
      String intPart = match.group(1)!;
      String? decPart = match.group(2);
      RegExp reg = RegExp(r'(\d+)(\d{3})');
      while (reg.hasMatch(intPart)) {
        intPart = intPart.replaceAllMapped(reg, (m) => '${m[1]},${m[2]}');
      }
      return intPart + (decPart ?? '');
    });
  }

  String _getCurrentDisplayText() {
    if (_isResultDisplayed && _result.isNotEmpty) {
      return _formatWithCommas(_result);
    }
    return _expression.isEmpty ? "0" : _formatWithCommas(_expression);
  }

  void _clearAll() {
    setState(() {
      _expression = "";
      _result = "";
      _isResultDisplayed = false;
      _history.clear();
    });
  }

  void _onHistoryItemTapped(String item) {
    String rawItem = item.replaceAll(',', '');
    if (rawItem.contains("=")) {
      final parts = rawItem.split("=");
      final res = parts.last.trim();
      setState(() {
        _expression = res;
        _result = "";
        _isResultDisplayed = false;
      });
    } else {
      setState(() {
        _expression = rawItem.trim();
        _result = "";
        _isResultDisplayed = false;
      });
    }
  }

  void _showHistoryBottomSheet() {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _history.isEmpty
                          ? null
                          : () {
                              _clearAll();
                              setModalState(() {});
                              Navigator.pop(context);
                            },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        "مسح السجل",
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                    Text(
                      "سجل العمليات",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: _history.isEmpty
                      ? Center(
                          child: Text(
                            "لا توجد عمليات سابقة",
                            style: TextStyle(
                              fontSize: 18,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _history.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _history[_history.length - 1 - index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              title: Text(
                                _formatWithCommas(item),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 20,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              onTap: () {
                                _onHistoryItemTapped(item);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "الآلة الحاسبة",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.history_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: _showHistoryBottomSheet,
            tooltip: "سجل العمليات",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                // 1. قسم الشاشة (Display Area)
                Expanded(
                  flex: 3,
                  child: _buildDisplayArea(isDark),
                ),
                const SizedBox(height: 8),
                // 2. قسم الأزرار (Keypad Area)
                Expanded(
                  flex: _isScientificMode ? 5 : 4,
                  child: _buildKeypadArea(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayArea(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // قائمة (سجل) بالعمليات السابقة تظهر فوق بعضها محاذاة لليمين بلون باهت (Grey)
          Expanded(
            child: _history.isEmpty
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (int i = 0; i < _history.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: InkWell(
                              onTap: () => _onHistoryItemTapped(_history[i]),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                child: Text(
                                  _formatWithCommas(_history[i]),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          // الرقم الحالي بخط ضخم جداً
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              _getCurrentDisplayText(),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: _isScientificMode ? 52 : 64,
                fontWeight: FontWeight.w300,
                letterSpacing: -1.0,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadArea(bool isDark) {
    final rows = _isScientificMode
        ? [
            ['2nd', 'deg', 'sin', 'cos', 'tan'],
            ['xʸ', 'lg', 'ln', '(', ')'],
            ['√x', 'AC', 'backspace', '%', '÷'],
            ['x!', '7', '8', '9', '×'],
            ['1/x', '4', '5', '6', '-'],
            ['π', '1', '2', '3', '+'],
            ['toggle_scientific', 'e', '0', '.', '='],
          ]
        : [
            ['AC', 'backspace', '%', '÷'],
            ['7', '8', '9', '×'],
            ['4', '5', '6', '-'],
            ['1', '2', '3', '+'],
            ['toggle_scientific', '0', '.', '='],
          ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey<bool>(_isScientificMode),
        children: [
          for (int r = 0; r < rows.length; r++)
            Expanded(
              child: Row(
                children: [
                  for (int c = 0; c < rows[r].length; c++)
                    Expanded(
                      child: _buildButton(rows[r][c], isDark),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton(String value, bool isDark) {
    final isEquals = value == "=";
    final isControlOrOp = [
      "AC",
      "backspace",
      "%",
      "÷",
      "×",
      "-",
      "+",
      "toggle_scientific"
    ].contains(value);

    Color textColor;
    if (isEquals) {
      textColor = Colors.white;
    } else if (isControlOrOp) {
      textColor = const Color(0xFFFF9500); // البرتقالي للأزرار الأساسية والتحكم
    } else {
      textColor = isDark ? Colors.white : Colors.black;
    }

    final bgColor = isEquals
        ? const Color(0xFFFF9500)
        : (isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA));

    return Container(
      margin: EdgeInsets.all(_isScientificMode ? 4.0 : 6.0),
      decoration: BoxDecoration(
        color: bgColor,
        shape: isEquals ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isEquals ? null : BorderRadius.circular(16),
        boxShadow: [
          // ظل علوي أيسر (Top-Left Highlight)
          BoxShadow(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
            offset: _isScientificMode
                ? const Offset(-2.5, -2.5)
                : const Offset(-4, -4),
            blurRadius: _isScientificMode ? 4 : 8,
          ),
          // ظل سفلي أيمن (Bottom-Right Shadow)
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : Colors.grey.shade300,
            offset: _isScientificMode
                ? const Offset(2.5, 2.5)
                : const Offset(4, 4),
            blurRadius: _isScientificMode ? 4 : 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: isEquals
            ? const CircleBorder()
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
        child: InkWell(
          onTap: () => _onButtonPressed(value),
          onLongPress: value == "AC" ? () => _clearAll() : null,
          customBorder: isEquals
              ? const CircleBorder()
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
          child: Center(
            child: _buildButtonChild(value, isDark, textColor),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonChild(String value, bool isDark, Color color) {
    switch (value) {
      case "backspace":
        return Icon(Icons.backspace_outlined,
            size: _isScientificMode ? 24 : 28, color: color);
      case "÷":
        return Icon(CupertinoIcons.divide,
            size: _isScientificMode ? 26 : 30, color: color);
      case "×":
        return Icon(CupertinoIcons.multiply,
            size: _isScientificMode ? 26 : 30, color: color);
      case "toggle_scientific":
        return Icon(Icons.autorenew_rounded,
            size: _isScientificMode ? 26 : 30, color: color);
      case "AC":
        return Text(
          "AC",
          style: TextStyle(
              fontSize: _isScientificMode ? 22 : 26,
              fontWeight: FontWeight.w600,
              color: color),
        );
      case "%":
        return Text(
          "%",
          style: TextStyle(
              fontSize: _isScientificMode ? 24 : 28,
              fontWeight: FontWeight.w500,
              color: color),
        );
      case "-":
        return Text(
          "-",
          style: TextStyle(
              fontSize: _isScientificMode ? 30 : 36,
              fontWeight: FontWeight.w500,
              color: color),
        );
      case "+":
        return Text(
          "+",
          style: TextStyle(
              fontSize: _isScientificMode ? 28 : 32,
              fontWeight: FontWeight.w500,
              color: color),
        );
      case "=":
        return Text(
          "=",
          style: TextStyle(
              fontSize: _isScientificMode ? 30 : 36,
              fontWeight: FontWeight.w600,
              color: color),
        );
      case "2nd":
        return Text(
          _is2nd ? "1st" : "2nd",
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: _is2nd ? const Color(0xFFFF9500) : color),
        );
      case "deg":
        return Text(
          _isDegreeMode ? "deg" : "rad",
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w500, color: color),
        );
      case "sin":
        return Text(
          _is2nd ? "asin" : "sin",
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w500, color: color),
        );
      case "cos":
        return Text(
          _is2nd ? "acos" : "cos",
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w500, color: color),
        );
      case "tan":
        return Text(
          _is2nd ? "atan" : "tan",
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w500, color: color),
        );
      case "xʸ":
        return Text(
          _is2nd ? "x²" : "xʸ",
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w500, color: color),
        );
      case "lg":
        return Text(
          _is2nd ? "10ˣ" : "lg",
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w500, color: color),
        );
      case "ln":
        return Text(
          _is2nd ? "eˣ" : "ln",
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w500, color: color),
        );
      case "√x":
        return Text(
          _is2nd ? "³√x" : "√x",
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w500, color: color),
        );
      case "x!":
        return Text(
          "x!",
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w500, color: color),
        );
      case "1/x":
        return Text(
          "1/x",
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w500, color: color),
        );
      case "π":
        return Text(
          "π",
          style: TextStyle(
              fontSize: 21, fontWeight: FontWeight.w500, color: color),
        );
      case "e":
        return Text(
          "e",
          style: TextStyle(
              fontSize: 21, fontWeight: FontWeight.w500, color: color),
        );
      case "(":
      case ")":
        return Text(
          value,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w500, color: color),
        );
      default:
        // الأرقام 0-9 والنقطة .
        return Text(
          value,
          style: TextStyle(
              fontSize: _isScientificMode ? 26 : 30,
              fontWeight: FontWeight.w500,
              color: color),
        );
    }
  }
}
