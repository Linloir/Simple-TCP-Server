/*
 * @Author       : Linloir
 * @Date         : 2022-10-08 15:10:04
 * @LastEditTime : 2022-10-19 10:41:12
 * @Description  : 
 */

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:tcp_server/tcpcontroller/request.dart';
import 'package:tcp_server/tcpcontroller/response.dart';

class TCPController {
  final Socket socket;

  //Stores the incoming bytes of the TCP connection temporarily
  final List<int> buffer = [];

  //Byte length for json object
  int requestLength = 0;
  //Byte length for subsequent data of the json object
  int payloadLength = 0;

  int _fileCounter = 0;

  //Construct a stream which emits events on intact requests
  final StreamController<List<int>> _requestRawStreamController = StreamController();
  final StreamController<File> _payloadRawStreamController = StreamController();

  //Construct a payload stream which forward the incoming byte into temp file
  StreamController<List<int>> _payloadPullStreamController = StreamController()..close();

  //Provide a request stream for caller functions to listen on
  final StreamController<TCPRequest> _requestStreamController = StreamController();
  Stream<TCPRequest>? _requestStreamBroadcast;
  Stream<TCPRequest> get requestStreamBroadcast {
    _requestStreamBroadcast ??= _requestStreamController.stream.asBroadcastStream();
    return _requestStreamBroadcast!;
  }

  //Provide a post stream for caller functions to push to
  final StreamController<TCPResponse> _responseStreamController = StreamController();
  StreamSink<TCPResponse> get outStream => _responseStreamController;
  Stream<TCPResponse>? _responseStreamBroadcast;
  Stream<TCPResponse> get responseStreamBroadcast {
    _responseStreamBroadcast ??= _responseStreamController.stream.asBroadcastStream();
    return _responseStreamBroadcast!;
  }

  TCPController({
    required this.socket
  }) {
    print('[L] [CONNECTED]-----------------------');
    print('[L] Connection Established');
    print('[L] Remote: ${socket.remoteAddress}:${socket.remotePort}');
    print('[L] Local: ${socket.address}:${socket.port}');
    Future(() async {
      await for(var request in socket) {
        _pullRequest(request);
        await Future.delayed(const Duration(microseconds: 0));
      }
    }).then((_) {
      print('[L] [CLOSED   ]-----------------------');
      print('[L] Connection closed: ${socket.address}:${socket.port}<-${socket.remoteAddress}:${socket.remotePort}');
      _requestStreamController.close();
    }).onError((error, stackTrace) {
      print(error);
      _requestStreamController.addError(error ?? Error());
    },);
    // socket.listen(
    //   _pullRequest,
    //   onError: (e) {
    //     print(e);
    //     _requestStreamController.addError(e);
    //   },
    //   onDone: () {
    //     print('[L] [CLOSED   ]-----------------------');
    //     print('[L] Connection closed: ${socket.address}:${socket.port}<-${socket.remoteAddress}:${socket.remotePort}');
    //     _requestStreamController.close();
    //   },
    //   cancelOnError: true,
    // );
    //This future never ends, would that be bothersome?
    Future(() async {
      try{
        await for(var response in responseStreamBroadcast) {
          await socket.addStream(response.stream);
        }
      } catch (e) {
        print(e);
        await socket.flush();
        socket.close();
      }
    });
    //This one will fail if two request are handled simultaneously, which cause a stream
    //adding to the socket which was already added by the previous stream
    // _outStreamController.stream.listen((response) async {
    //   await socket.addStream(response.stream);
    // });
    Future(() async {
      var requestQueue = StreamQueue(_requestRawStreamController.stream);
      var payloadQueue = StreamQueue(_payloadRawStreamController.stream);
      while(await Future<bool>(() => !_requestRawStreamController.isClosed && !_payloadRawStreamController.isClosed)) {
        var request = await requestQueue.next;
        var payload = await payloadQueue.next;
        await _pushRequest(requestBytes: request, tempFile: payload);
      }
      requestQueue.cancel();
      payloadQueue.cancel();
    });
  }

  //Listen to the incoming stream and emits event whenever there is a intact request
  void _pullRequest(Uint8List fetchedData) {
    //Put incoming data into buffer
    buffer.addAll(fetchedData);
    //Consume buffer until it's not enough for first 8 byte of a message
    while(true) {
      if(requestLength == 0 && payloadLength == 0 && _payloadPullStreamController.isClosed) {
        //New request
        if(buffer.length >= 12) {
          //Buffered data has more than 8 bytes, enough to read request length and body length
          requestLength = Uint8List.fromList(buffer.sublist(0, 4)).buffer.asInt32List()[0];
          payloadLength = Uint8List.fromList(buffer.sublist(4, 12)).buffer.asInt64List()[0];
          //Clear the length indicator bytes
          buffer.removeRange(0, 12);
          //Initialize payload transmission controller
          _payloadPullStreamController = StreamController();
          //Create a future that listens to the status of the payload transmission
          () {
            var payloadPullStream = _payloadPullStreamController.stream;
            var tempFile = File('${Directory.current.path}/.tmp/${DateTime.now().microsecondsSinceEpoch}$_fileCounter')..createSync();
            _fileCounter += 1;
            _fileCounter %= 1000;
            Future(() async {
              await for(var data in payloadPullStream) {
                await tempFile.writeAsBytes(data, mode: FileMode.writeOnlyAppend);
              }
              _payloadRawStreamController.add(tempFile);
            });
          }();
        }
        else {
          //Buffered data is not long enough
          //Do nothing
          break;
        }
      }
      else {
        //Currently awaiting full transmission
        if(requestLength > 0) {
          //Currently processing on a request
          if(buffer.length >= requestLength) {
            //Got intact request json
            //Emit request buffer through stream
            _requestRawStreamController.add(buffer.sublist(0, requestLength));
            //Remove proccessed buffer
            buffer.removeRange(0, requestLength);
            //Clear awaiting request length
            requestLength = 0;
          }
          else {
            //Got part of request json
            //do nothing
            break;
          }
        }
        else {
          //Currently processing on a payload
          if(buffer.length >= payloadLength) {
            //Last few bytes to emit
            //Send the last few bytes to stream
            _payloadPullStreamController.add(buffer.sublist(0, payloadLength));
            //Clear buffer
            buffer.removeRange(0, payloadLength);
            //Set payload length to zero
            payloadLength = 0;
            //Close the payload transmission stream
            _payloadPullStreamController.close();
          }
          else {
            //Part of payload
            //Transmit all to stream
            _payloadPullStreamController.add([...buffer]);
            //Reduce payload bytes left
            payloadLength -= buffer.length;
            //Clear buffer
            buffer.clear();
            //Exit and wait for another submit
            break;
          }
        }
      }
    }
  }

  Future<void> _pushRequest({
    required List<int> requestBytes,
    required File tempFile
  }) async {
    _requestStreamController.add(TCPRequest(requestBytes, tempFile));
  }
}