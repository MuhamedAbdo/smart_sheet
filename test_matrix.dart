// ignore_for_file: avoid_print, deprecated_member_use, depend_on_referenced_packages
import 'package:vector_math/vector_math_64.dart';

void main() {
  var m1 = Matrix4.identity()
    ..translate(2.0, 3.0)
    ..scale(2.5);
  var m2 = Matrix4.identity()
    ..setEntry(0, 0, 2.5)
    ..setEntry(1, 1, 2.5)
    ..setEntry(0, 3, 2.0)
    ..setEntry(1, 3, 3.0);
  print(m1);
  print(m2);
}
