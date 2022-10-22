/*
 * @Author       : Linloir
 * @Date         : 2022-10-06 15:44:16
 * @LastEditTime : 2022-10-22 21:25:00
 * @Description  : 
 */

import 'dart:io';

import 'package:tcp_server/database.dart';
import 'package:tcp_server/requesthandler.dart';
import 'package:tcp_server/tcpcontroller/controller.dart';
import 'package:tcp_server/tcpcontroller/payload/message.dart';
import 'package:tcp_server/tcpcontroller/request.dart';
import 'package:tcp_server/tcpcontroller/response.dart';

void main(List<String> arguments) async {
  //Set address
  var port = arguments.isEmpty ? 20706 : int.tryParse(arguments[0]) ?? 20706;

  print('[L] [STARTUP  ]-----------------------');
  print('[L] Running at directory ${Directory.current.path}');
  
  //Create nessesary working directories
  await Directory('${Directory.current.path}/.data').create();
  await Directory('${Directory.current.path}/.data/.tmp').create();
  await Directory('${Directory.current.path}/.data/files').create();

  await DataBaseHelper().initialize();
  Map<int, List<TCPController>> tokenMap = {};
  Map<TCPController, Future<int>> controllerMap = {};
  var listenSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
  listenSocket.listen(
    (socket) {
      var controller = TCPController(socket: socket);
      controller.responseStreamBroadcast.listen(
        null,
        onError: (_) {
          print('[L] [EXCEPTION]-----------------------');
          print('[L] TCP Controller ran into exception');
          print('[L] socket: ${controller.socket.address}:${controller.socket.port}');
          var token = controllerMap[controller];
          controllerMap.remove(controller);
          tokenMap[token]?.remove(controller);
        },
        onDone: () {
          var token = controllerMap[controller];
          controllerMap.remove(controller);
          tokenMap[token]?.remove(controller);
        },
        cancelOnError: true
      );
      controller.requestStreamBroadcast.listen(
        (request) async {
          print('[L] [INCOMING ]-----------------------');
          print('[L] Incoming from ${controller.socket.remoteAddress}:${controller.socket.remotePort}');
          if(request.requestType == RequestType.sendMessage) {
            print('[L] Message: (Message body)');
          }
          else {
            print('[L] Message: ${request.toJSON}');
          }
          if(!(await DataBaseHelper().isTokenValid(tokenid: request.tokenID))) {
            if(controllerMap[controller] == null) {
              controllerMap[controller] = (() async => (await DataBaseHelper().createToken()))();
            }
            request.tokenID = await controllerMap[controller];
            var tokenResponse = TCPResponse(
              type: ResponseType.token,
              status: ResponseStatus.ok,
              body: {
                "tokenid": request.tokenID
              }
            );
            controller.outStream.add(tokenResponse);
          }
          tokenMap[request.tokenID!] ??= [];
          if(!tokenMap[request.tokenID]!.contains(controller)) {
            tokenMap[request.tokenID]!.add(controller);
          }
          switch(request.requestType) {
            case RequestType.checkState: {
              var response = await onCheckState(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.register: {
              var response = await onRegister(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.login: {
              var response = await onLogin(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.logout: {
              var response = await onLogout(request, socket);
              controller.outStream.add(response);
              break;
            }
            case RequestType.profile: {
              var response = await onFetchProfile(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.modifyProfile: {
              var response = await onModifyProfile(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.modifyPassword: {
              var response = await onModifyPassword(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.sendMessage: {
              //Forword Message
              var message = Message.fromJSONObject(request.body);
              await DataBaseHelper().setFetchHistoryFor(
                tokenID: request.tokenID, 
                newTimeStamp: message.timestamp
              );
              var originUserID = message.senderID;
              var onlineDevices = await DataBaseHelper().fetchTokenIDsViaUserID(userID: originUserID);
              for(var device in onlineDevices) {
                if(device == request.tokenID) {
                  continue;
                }
                var targetControllers = tokenMap[device] ?? [];
                var forwardResponse = TCPResponse(
                  type: ResponseType.forwardMessage,
                  status: ResponseStatus.ok,
                  body: message.jsonObject
                );
                for(var controller in targetControllers) {
                  try {
                    print('[L] [MSGFOWARD]-----------------------');
                    print('[L] Forwarding message to ${controller.socket.remoteAddress}:${controller.socket.remotePort}');
                    controller.outStream.add(forwardResponse);
                  } catch(e) {
                    print('[E] [EXCEPTION]-----------------------');
                    var token = controllerMap[controller];
                    controllerMap.remove(controller);
                    tokenMap[token]?.remove(controller);
                    continue;
                  }
                }
                // //Update Fetch Histories
                // await DataBaseHelper().setFetchHistoryFor(
                //   tokenID: device, 
                //   newTimeStamp: message.timestamp
                // );
              }
              var targetUserID = message.receiverID;
              var targetDevices = await DataBaseHelper().fetchTokenIDsViaUserID(userID: targetUserID);
              for(var device in targetDevices) {
                //Forward to socket
                var targetControllers = tokenMap[device] ?? [];
                var forwardResponse = TCPResponse(
                  type: ResponseType.forwardMessage,
                  status: ResponseStatus.ok,
                  body: message.jsonObject
                );
                for(int i = targetControllers.length - 1; i >= 0; i--) {
                  var controller = targetControllers[i];
                  try{
                    print('[L] [MSGFOWARD]-----------------------');
                    print('[L] Forwarding message to ${controller.socket.remoteAddress}:${controller.socket.remotePort}');
                    controller.outStream.add(forwardResponse);
                  } catch(e) {
                    print('[E] [EXCEPTION]-----------------------');
                    var token = controllerMap[controller];
                    controllerMap.remove(controller);
                    tokenMap[token]?.remove(controller);
                    continue;
                  }
                }
                // //Update Fetch Histories
                // await DataBaseHelper().setFetchHistoryFor(
                //   tokenID: device, 
                //   newTimeStamp: message.timestamp
                // );
              }
              var response = await onSendMessage(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.fetchMessage: {
              var response = await onFetchMessage(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.findFile: {
              var response = await onFindFile(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.fetchFile: {
              var response = await onFetchFile(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.searchUser: {
              var response = await onSearchUser(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.addContact: {
              var response = await onAddContact(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              var contactResponse = await onFetchContact(
                TCPRequest.fromData(
                  type: RequestType.fetchContact, 
                  body: {}, 
                  tokenID: request.tokenID
                ), 
                socket
              );
              controller.outStream.add(contactResponse);
              break;
            }
            case RequestType.fetchContact: {
              var response = await onFetchContact(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            case RequestType.ackFetch: {
              onAckFetch(request, socket);
              break;
            }
            case RequestType.unknown: {
              var response = await onUnknownRequest(request, socket);
              try {
                controller.outStream.add(response);
              } catch (e) {
                print('[E] [EXCEPTION]-----------------------');
                var token = controllerMap[controller];
                controllerMap.remove(controller);
                tokenMap[token]?.remove(controller);
              }
              break;
            }
            default: {
              print('[E] Drop out of switch case');
            }
          }
          //Clear temp file
          if(request.payload?.existsSync() ?? false) {
            request.payload?.delete();
          }
        },
        onError: (e) {
          print(e);
          var token = controllerMap[controller];
          controllerMap.remove(controller);
          tokenMap[token]?.remove(controller);
        },
        onDone: () {
          var token = controllerMap[controller];
          controllerMap.remove(controller);
          tokenMap[token]?.remove(controller);
        }
      );
    },
    cancelOnError: true
  );
}
