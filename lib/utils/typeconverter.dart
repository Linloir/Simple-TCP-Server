/*
 * @Author       : Linloir
 * @Date         : 2022-10-08 17:21:45
 * @LastEditTime : 2022-10-08 17:29:21
 * @Description  : Type Converters
 */

import 'dart:typed_data';

import 'package:convert/convert.dart';

String uint8ListToHexString(Uint8List data) {
  return data.buffer.asUint8List().map((e) => e.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List hexToUint8List(String string) {
  return Uint8List.fromList(hex.decode(string));
}

Uint8List intToUint8List(int value) {
  return Uint8List(4)..buffer.asInt32List()[0] = value;
}