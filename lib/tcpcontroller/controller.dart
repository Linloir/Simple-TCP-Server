/*
 * @Author       : Linloir
 * @Date         : 2022-10-08 15:10:04
 * @LastEditTime : 2022-10-08 23:11:24
 * @Description  : 
 */

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:tcp_server/tcpcontroller/request.dart';

class TCPController {
  final Socket socket;

  //Stores the incoming bytes of the TCP connection temporarily
  final Uint8List buffer = Uint8List(0);

  //Byte length for json object
  int requestLength = 0;
  //Byte length for subsequent data of the json object
  int payloadLength = 0;

  //Construct a stream which emits events on intact requests
  StreamController<Uint8List> _requestStreamController = StreamController()..close();

  //Construct a payload stream which forward the incoming byte into temp file
  StreamController<Uint8List> _payloadStreamController = StreamController()..close();

  //Provide a request stream for caller functions to listen on
  final StreamController<TCPRequest> _streamController = StreamController();
  Stream<TCPRequest> get stream => _streamController.stream; 

  TCPController({
    required this.socket
  }) {
    socket.listen(socketHandler);
  }

  //Listen to the incoming stream and emits event whenever there is a intact request
  void socketHandler(Uint8List fetchedData) {
    //Put incoming data into buffer
    buffer.addAll(fetchedData);
    //Consume buffer until it's not enough for first 8 byte of a message
    while(true) {
      if(requestLength == 0 && payloadLength == 0) {
        //New request
        if(buffer.length > 8) {
          //Buffered data has more than 8 bytes, enough to read request length and body length
          requestLength = buffer.sublist(0, 4).buffer.asByteData().getInt32(0);
          payloadLength = buffer.sublist(4, 8).buffer.asByteData().getInt32(0);
          //Clear the length indicator bytes
          buffer.removeRange(0, 8);
          //Create temp file to read payload (might be huge)
          var tempFile = File('./temp${DateTime.now().microsecondsSinceEpoch}.temp')..createSync();
          //Initialize payload transmission controller
          _payloadStreamController = StreamController();
          //Bind file to stream
          _payloadStreamController.stream.listen((data) {
            tempFile.writeAsBytes(data, mode: FileMode.append);
          });
          //Bind request construction on stream
          _requestStreamController = StreamController();
          _requestStreamController.stream.listen((requestBytes) {
            //When request stream is closed by controller
            var request = TCPRequest(requestBytes, tempFile);
            _payloadStreamController.done.then((_) {
              _streamController.add(request);
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
          if(buffer.length > requestLength) {
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
            _payloadStreamController.add(buffer.sublist(0, payloadLength));
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
            _payloadStreamController.add(buffer);
            //Reduce payload bytes left
            payloadLength -= buffer.length;
            //Clear buffer
            buffer.clear();
          }
        }
      }
    }
  }
}