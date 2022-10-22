/*
 * @Author       : Linloir
 * @Date         : 2022-10-08 20:52:48
 * @LastEditTime : 2022-10-22 20:56:15
 * @Description  : 
 */

import 'dart:io';

import 'package:tcp_server/database.dart';
import 'package:tcp_server/tcpcontroller/payload/identity.dart';
import 'package:tcp_server/tcpcontroller/payload/message.dart';
import 'package:tcp_server/tcpcontroller/payload/userinfo.dart';
import 'package:tcp_server/tcpcontroller/request.dart';
import 'package:tcp_server/tcpcontroller/response.dart';

Future<TCPResponse> onCheckState(TCPRequest request, Socket socket) async {
  try {
    var userInfo = await DataBaseHelper().checkLoginState(tokenID: request.tokenID);
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok, 
      body: userInfo.jsonObject
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

Future<TCPResponse> onRegister(TCPRequest request, Socket socket) async {
  try {
    UserIdentity identity = UserIdentity.fromJSONObject(request.body);
    var newUserInfo = await DataBaseHelper().registerUser(
      identity: identity, 
      tokenID: request.tokenID
    );
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType), 
      status: ResponseStatus.ok,
      body: newUserInfo.jsonObject
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType), 
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

Future<TCPResponse> onLogin(TCPRequest request, Socket socket) async {
  try {
    var userInfo = await DataBaseHelper().logIn(
      identity: UserIdentity.fromJSONObject(request.body), 
      tokenID: request.tokenID
    );
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok,
      body: userInfo.jsonObject
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

Future<TCPResponse> onLogout(TCPRequest request, Socket socket) async {
  try {
    await DataBaseHelper().logOut(tokenID: request.tokenID);
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok,
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

Future<TCPResponse> onFetchProfile(TCPRequest request, Socket socket) async {
  try {
    var userInfo = await DataBaseHelper().fetchUserInfoViaID(userid: request.body['userid'] as int);
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok,
      body: userInfo.jsonObject
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

Future<TCPResponse> onModifyPassword(TCPRequest request, Socket socket) async {
  try {
    await DataBaseHelper().modifyUserPassword(
      newIdentity: UserIdentity.fromJSONObject(request.body), 
      tokenID: request.tokenID
    );
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

Future<TCPResponse> onModifyProfile(TCPRequest request, Socket socket) async {
  try {
    var newUserInfo = await DataBaseHelper().modifyUserInfo(
      userInfo: UserInfo.fromJSONObject(request.body), 
      tokenID: request.tokenID
    );
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok,
      body: newUserInfo.jsonObject
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

Future<TCPResponse> onSendMessage(TCPRequest request, Socket socket) async {
  try {
    var message = Message.fromJSONObject(request.body);
    if(message.contentType == MessageType.file) {
      await DataBaseHelper().storeFile(
        tempFile: request.payload,
        fileMd5: message.fileMd5
      );
    }
    //Store message
    await DataBaseHelper().storeMessage(
      msg: message,
      fileMd5: message.fileMd5
    );
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok,
      body: {
        'md5encoded': message.md5encoded
      }
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString(),
    );
  }
}

Future<TCPResponse> onFetchMessage(TCPRequest request, Socket socket) async {
  try {
    var messages = await DataBaseHelper().fetchMessagesFor(tokenID: request.tokenID);
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok,
      body: {
        'messages': messages.map((e) => e.jsonObject).toList()
      }
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

Future<TCPResponse> onFindFile(TCPRequest request, Socket socket) async {
  var hasFile = await DataBaseHelper().findFile(fileMd5: request.body['filemd5'] as String);
  return TCPResponse(
    type: ResponseType.fromRequestType(request.requestType),
    status: hasFile ? ResponseStatus.ok : ResponseStatus.err,
    errInfo: hasFile ? null : 'File not found'
  );
}

Future<TCPResponse> onFetchFile(TCPRequest request, Socket socket) async {
  try {
    var filePath = await DataBaseHelper().fetchFilePath(msgMd5: request.body['msgmd5'] as String);
    var file = File(filePath);
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok,
      payload: file
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

Future<TCPResponse> onSearchUser(TCPRequest request, Socket socket) async {
  try {
    var userInfo = await DataBaseHelper().fetchUserInfoViaUsername(username: request.body['username'] as String);
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok,
      body: userInfo.jsonObject
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

Future<TCPResponse> onAddContact(TCPRequest request, Socket socket) async {
  try {
    await DataBaseHelper().addContact(tokenID: request.tokenID, userID: request.body['userid'] as int);
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

Future<TCPResponse> onFetchContact(TCPRequest request, Socket socket) async {
  try {
    var contacts = await DataBaseHelper().fetchContact(tokenID: request.tokenID);
    var pendingContacts = await DataBaseHelper().fetchPendingContacts(tokenID: request.tokenID);
    var requestingContacts = await DataBaseHelper().fetchRequestingContacts(tokenID: request.tokenID);
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.ok,
      body: {
        "contacts": contacts.map((e) => e.jsonObject).toList(),
        "pending": pendingContacts.map((e) => e.jsonObject).toList(),
        "requesting": requestingContacts.map((e) => e.jsonObject).toList()
      }
    );
  } on Exception catch (exception) {
    return TCPResponse(
      type: ResponseType.fromRequestType(request.requestType),
      status: ResponseStatus.err,
      errInfo: exception.toString()
    );
  }
}

void onAckFetch(TCPRequest request, Socket socket) async {
  //Update Fetch Histories
  await DataBaseHelper().setFetchHistoryFor(
    tokenID: request.tokenID, 
    newTimeStamp: request.body['timestamp'] as int,
  );
}

Future<TCPResponse> onUnknownRequest(TCPRequest request, Socket socket) async {
  return TCPResponse(
    type: ResponseType.fromRequestType(request.requestType),
    status: ResponseStatus.err,
    errInfo: 'Unkown request'
  );
}