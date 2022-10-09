/*
 * @Author       : Linloir
 * @Date         : 2022-10-08 15:10:04
 * @LastEditTime : 2022-10-09 20:21:53
 * @Description  : 
 */

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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

  //Construct a stream which emits events on intact requests
  StreamController<List<int>> _requestStreamController = StreamController()..close();

  //Construct a payload stream which forward the incoming byte into temp file
  StreamController<List<int>> _payloadStreamController = StreamController()..close();

  //Provide a request stream for caller functions to listen on
  final StreamController<TCPRequest> _inStreamController = StreamController();
  Stream<TCPRequest> get inStream => _inStreamController.stream;

  //Provide a post stream for caller functions to push to
  final StreamController<TCPResponse> _outStreamController = StreamController();
  StreamSink<TCPResponse> get outStream => _outStreamController.sink;

  TCPController({
    required this.socket
  }) {
    socket.listen(socketHandler);
    _outStreamController.stream.listen((response) async {
      await socket.addStream(response.stream);
    });
  }

  //Listen to the incoming stream and emits event whenever there is a intact request
  void socketHandler(Uint8List fetchedData) {
    //Put incoming data into buffer
    buffer.addAll(fetchedData);
    //Consume buffer until it's not enough for first 8 byte of a message
    while(true) {
      if(requestLength == 0 && payloadLength == 0 && _payloadStreamController.isClosed) {
        //New request
        if(buffer.length >= 8) {
          //Buffered data has more than 8 bytes, enough to read request length and body length
          requestLength = Uint8List.fromList(buffer.sublist(0, 4)).buffer.asInt32List()[0];
          payloadLength = Uint8List.fromList(buffer.sublist(4, 8)).buffer.asInt32List()[0];
          //Clear the length indicator bytes
          buffer.removeRange(0, 8);
          //Create temp file to read payload (might be huge)
          var tempFile = File('${Directory.current.path}/.tmp/${DateTime.now().microsecondsSinceEpoch}')..createSync();
          //Initialize payload transmission controller
          _payloadStreamController = StreamController();
          //Create a future that listens to the status of the payload transmission
          var payloadTransmission = Future(() async {
            await for(var data in _payloadStreamController.stream) {
              await tempFile.writeAsBytes(data, mode: FileMode.append, flush: true);
            }
          });
          //Bind request construction on stream
          _requestStreamController = StreamController();
          _requestStreamController.stream.listen((requestBytes) {
            //When request stream is closed by controller
            payloadTransmission.then((_) {
              _inStreamController.add(TCPRequest(requestBytes, tempFile));
            });
          });
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
            _requestStreamController.add(buffer.sublist(0, requestLength));
            _requestStreamController.close();
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
            _payloadStreamController.add(Uint8List.fromList(buffer.sublist(0, payloadLength)));
            //Clear buffer
            buffer.removeRange(0, payloadLength);
            //Set payload length to zero
            payloadLength = 0;
            //Close the payload transmission stream
            _payloadStreamController.close();
          }
          else {
            //Part of payload
            //Transmit all to stream
            _payloadStreamController.add(Uint8List.fromList(buffer));
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
}