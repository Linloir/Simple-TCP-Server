/*
 * @Author       : Linloir
 * @Date         : 2022-10-06 15:44:16
 * @LastEditTime : 2022-10-08 23:57:37
 * @Description  : 
 */

import 'dart:convert';
import 'dart:io';

import 'package:tcp_server/database.dart';
import 'package:tcp_server/requesthandler.dart';
import 'package:tcp_server/tcpcontroller/controller.dart';
import 'package:tcp_server/tcpcontroller/request.dart';
import 'package:tcp_server/tcpcontroller/response.dart';

void main(List<String> arguments) async {
  await DataBaseHelper().initialize();
  var tokenMap = <int, Socket>{};
  var socketMap = <Socket, Future<int>>{};
  var listenSocket = await ServerSocket.bind('127.0.0.1', 20706);
  listenSocket.listen(
    (socket) {
      var controller = TCPController(socket: socket);
      controller.stream.listen((request) async {
        if(request.tokenID == null) {
          if(socketMap[socket] == null) {
            socketMap[socket] = (() async => (await DataBaseHelper().createToken()))();
          }
          request.tokenID = await socketMap[socket];
          var tokenResponse = TCPResponse(
            type: RequestType.token,
            status: ResponseStatus.ok,
            body: {
              "tokenid": request.tokenID
            }
          );
          await socket.addStream(tokenResponse.stream);
        }
        tokenMap[request.tokenID!] = tokenMap[request.tokenID!] ?? socket;
        switch(request.requestType) {
          case RequestType.checkState: {
            var response = await onCheckState(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.register: {
            var response = await onRegister(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.login: {
            var response = await onLogin(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.logout: {
            var response = await onLogout(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.profile: {
            var response = await onFetchProfile(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.modifyProfile: {
            var response = await onModifyProfile(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.modifyPassword: {
            var response = await onModifyPassword(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.sendMessage: {
            //Forword Message
            var message = request.body['message'] as Map<String, Object?>;
            await DataBaseHelper().setFetchHistoryFor(
              tokenID: request.tokenID, 
              newTimeStamp: message['timestamp'] as int
            );
            var originUserID = message['userid'] as int;
            var onlineDevices = await DataBaseHelper().fetchTokenIDsViaUserID(userID: originUserID);
            for(var device in onlineDevices) {
              if(device == request.tokenID) {
                continue;
              }
              var targetSocket = tokenMap[device];
              targetSocket?.write(jsonEncode({
                'response': 'FORWARDMSG',
                'body': {
                  "message": message
                }
              }));
              //Update Fetch Histories
              await DataBaseHelper().setFetchHistoryFor(
                tokenID: device, 
                newTimeStamp: message['timestamp'] as int
              );
            }
            var targetUserID = message['targetid'] as int;
            var targetDevices = await DataBaseHelper().fetchTokenIDsViaUserID(userID: targetUserID);
            for(var device in targetDevices) {
              //Forward to socket
              var targetSocket = tokenMap[device];
              targetSocket?.write(jsonEncode({
                'response': 'FORWARDMSG',
                'body': {
                  "message": message
                }
              }));
              //Update Fetch Histories
              await DataBaseHelper().setFetchHistoryFor(
                tokenID: device, 
                newTimeStamp: message['timestamp'] as int
              );
            }
            var response = await onSendMessage(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.fetchMessage: {
            var response = await onFetchMessage(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.fetchFile: {
            var response = await onFetchFile(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.searchUser: {
            var response = await onSearchUser(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.fetchContact: {
            var response = await onFetchContact(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          case RequestType.unknown: {
            var response = await onUnknownRequest(request, socket);
            await socket.addStream(response.stream);
            break;
          }
          default: {
            print('[E] Drop out of switch case');
          }
        }
      });
    },
  );
}
