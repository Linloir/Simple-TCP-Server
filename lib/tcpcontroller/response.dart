/*
 * @Author       : Linloir
 * @Date         : 2022-10-08 22:40:47
 * @LastEditTime : 2022-10-08 23:05:01
 * @Description  : 
 */

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tcp_server/tcpcontroller/request.dart';

enum ResponseStatus {
  ok('OK'),
  err('ERR');

  final String _value;
  const ResponseStatus(String v): _value = v;

  String get value => _value;
}

class TCPResponse {
  final String responseJson;
  final File? payloadFile;

  TCPResponse({
    required RequestType type,
    required ResponseStatus status,
    Map<String, Object?>? body,
    String? errInfo,
    File? payload
  }): 
    responseJson = jsonEncode({
      "response": type.value, 
      "status": status.value,
      "info": errInfo,
      "body": body,
    }), 
    payloadFile = payload;

  int get responseLength => responseJson.length;
  int get payloadLength => payloadFile?.lengthSync() ?? 0;
  Stream<Uint8List> get stream async* {
    yield Uint8List(4)..buffer.asInt32List()[0] = responseLength;
    yield Uint8List(4)..buffer.asInt32List()[0] = payloadLength;
    yield Uint8List.fromList(responseJson.codeUnits);
    if(payloadFile != null) {
      yield await payloadFile!.readAsBytes();
    }
  }
}