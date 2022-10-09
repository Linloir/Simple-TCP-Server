/*
 * @Author       : Linloir
 * @Date         : 2022-10-08 22:40:47
 * @LastEditTime : 2022-10-09 16:39:02
 * @Description  : 
 */

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tcp_server/tcpcontroller/request.dart';

enum ResponseType {
  token         ('TOKEN'),          //Only exists when server is sending message
  checkState    ('STATE'),          //Check login state for device token
  register      ('REGISTER'),       //Register new user
  login         ('LOGIN'),          //Login via username and password
  logout        ('LOGOUT'),         //Logout for current device token
  profile       ('PROFILE'),        //Fetch current logged in user profile
  modifyPassword('MODIFYPASSWD'),   //Modify user password
  modifyProfile ('MODIFYPROFILE'),  //Modify user profile
  sendMessage   ('SENDMSG'),        //Send message
  forwardMessage('FORWARDMSG'),     //Forward message
  fetchMessage  ('FETCHMSG'),       //Fetch message
  findFile      ('FINDFILE'),       //Find file by md5 before transmitting the file
  fetchFile     ('FETCHFILE'),      //Fetch file and file md5 by message md5
  searchUser    ('SEARCHUSR'),      //Search username and userid by username
  addContact    ('ADDCONTACT'),     //Add one-way relation to a user
  fetchContact  ('FETCHCONTACT'),   //Fetch all contacts, including requesting and pending
  unknown       ('UNKNOWN');        //Wrong command

  const ResponseType(String value): _value = value;
  final String _value;
  String get value => _value;

  //Construct the enum type by value
  factory ResponseType.fromValue(String value) {
    return ResponseType.values.firstWhere((element) => element._value == value, orElse: () => ResponseType.unknown);
  }
  factory ResponseType.fromRequestType(RequestType type) {
    return ResponseType.values.firstWhere((element) => element._value == type.value, orElse: () => ResponseType.unknown);
  }
}

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
    required ResponseType type,
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
  Stream<List<int>> get stream async* {
    yield Uint8List(4)..buffer.asInt32List()[0] = responseLength;
    yield Uint8List(4)..buffer.asInt32List()[0] = payloadLength;
    yield Uint8List.fromList(responseJson.codeUnits);
    if(payloadFile != null) {
      yield await payloadFile!.readAsBytes();
    }
  }
}