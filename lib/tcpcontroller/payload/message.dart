/*
 * @Author       : Linloir
 * @Date         : 2022-10-08 16:16:19
 * @LastEditTime : 2022-10-09 14:53:11
 * @Description  : Message Info Payload
 */

import 'package:crypto/crypto.dart';
import 'package:tcp_server/utils/typeconverter.dart';

enum MessageType {
  plaintext('plaintext'),
  file('file'),
  image('image');

  factory MessageType.fromStringLiteral(String value) {
    return MessageType.values.firstWhere((element) => element._value == value);
  }
  const MessageType(String value): _value = value;
  final String _value;
  String get literal => _value;
}

class Message {
  final Map<String, Object?> _data;

  Message({
    required int userid,
    required int targetid,
    required MessageType contenttype,
    required String content,
    required int timestamp,
    String? md5encoded,
    String? filemd5
  }): _data = {
    "userid": userid,
    "targetid": targetid,
    "contenttype": contenttype.literal,
    "content": content,
    "timestamp": timestamp,
    "md5encoded": md5encoded ?? md5.convert(
      intToUint8List(userid)
      ..addAll(intToUint8List(targetid))
      ..addAll(intToUint8List(timestamp))
      ..addAll(content.codeUnits)
    ).toString(),
    "filemd5": filemd5
  };
  Message.fromJSONObject(Map<String, Object?> data): _data = data;

  int get senderID => _data['userid'] as int;
  int get receiverID => _data['targetid'] as int;
  MessageType get contentType => MessageType.fromStringLiteral(_data['contenttype'] as String);
  String get content => _data['content'] as String;
  int get timestamp => _data['timestamp'] as int;
  String get md5encoded => _data['md5encoded'] as String;
  String? get fileMd5 => _data['filemd5'] as String?;
  Map<String, Object?> get jsonObject => _data;
}