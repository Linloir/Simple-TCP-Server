/*
 * @Author       : Linloir
 * @Date         : 2022-10-08 15:14:26
 * @LastEditTime : 2022-10-09 17:36:42
 * @Description  : 
 */
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum RequestType {
  checkState    ('STATE'),          //Check login state for device token
  register      ('REGISTER'),       //Register new user
  login         ('LOGIN'),          //Login via username and password
  logout        ('LOGOUT'),         //Logout for current device token
  profile       ('PROFILE'),        //Fetch current logged in user profile
  modifyPassword('MODIFYPASSWD'),   //Modify user password
  modifyProfile ('MODIFYPROFILE'),  //Modify user profile
  sendMessage   ('SENDMSG'),        //Send message
  fetchMessage  ('FETCHMSG'),       //Fetch message
  findFile      ('FINDFILE'),       //Find file by md5 before transmitting the file
  fetchFile     ('FETCHFILE'),      //Fetch file and file md5 by message md5
  searchUser    ('SEARCHUSR'),      //Search username and userid by username
  addContact    ('ADDCONTACT'),     //Add one-way relation to a user
  fetchContact  ('FETCHCONTACT'),   //Fetch all contacts, including requesting and pending
  unknown       ('UNKNOWN');        //Wrong command

  const RequestType(String value): _value = value;
  final String _value;
  String get value => _value;

  //Construct the enum type by value
  factory RequestType.fromValue(String value) {
    return RequestType.values.firstWhere((element) => element._value == value, orElse: () => RequestType.unknown);
  }
}

//Object wrapper for tcp request string
class TCPRequest {
  final Map<String, Object?> _data;
  File? payload;

  TCPRequest(List<int> data, this.payload): _data = jsonDecode(String.fromCharCodes(data));
  TCPRequest.none(): _data = {};

  String get toJSON => jsonEncode(_data);
  RequestType get requestType => RequestType.fromValue(_data['request'] as String);
  int? get tokenID => _data['tokenid'] as int?;
  set tokenID(int? t) => _data['tokenid'] = t;
  Map<String, Object?> get body => _data['body'] as Map<String, Object?>? ?? {};
}