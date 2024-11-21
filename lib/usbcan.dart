library usbcan_plugins;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:cobs2/cobs2.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:usbcan_plugins/frames.dart';

enum Command { normal, establishmentOfCommunication }

class UsbCan {
  UsbDevice? device;
  bool connectionEstablished = false;
  Stream<CANFrame>? _stream;
  Stream<CANFrame> get stream {
    _stream ??= _usbStream().asBroadcastStream();
    return _stream!;
  }

  Future<bool> connectUSB() async {
    UsbDevice? newDevice;
    //Search a usbcan.
    List<UsbDevice> devices = await UsbSerial.listDevices();
    for (var element in devices) {
      if (Platform.isAndroid) {
        if (element.vid == 0x0483 && element.pid == 0x0409) {
          newDevice = element;
          break;
        }
      } else if (Platform.isWindows) {
        if (element.vid == 0x0483) {
          newDevice = element;
          break;
        }
      }
    }
    if (newDevice == null) return false;

    if (device != null && device!.port != null) {
      await device!.port!.close();
    }
    print("Connecting to ...");
    device = newDevice;

    if (device == null) {
      return false;
    }
    try {
      await device!.create();
    } catch (e) {
      return false;
    }
    if (device!.port == null) return false;
    device!.port!.setPortParameters(
        115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    print("Connecting to ...");
    //open a port.
    if (!(await device!.port!.open())) return false;

    print("Connecting to ...");
    return true;
  }

  Future<bool> sendFrame(Frame frame) async {
    return await _sendUint8List(frame.toUint8List());
  }

  Future<bool> sendCommand(Command command, Uint8List data) async {
    Uint8List sendData = Uint8List(data.length + 1);
    switch (command) {
      case Command.normal:
        assert(false, "[deprecated] Use sendFrame instead.");
        sendData[0] = 0 << 4;
        break;
      case Command.establishmentOfCommunication:
        sendData[0] = 1 << 4;
    }
    sendData.setRange(1, data.length + 1, data);
    return await _sendUint8List(sendData);
  }

  //for test
  Future<bool> sendString(String text) async {
    return await _sendUint8List(ascii.encode(text));
  }

  //Simply send Uin8list data.
  Future<bool> _sendUint8List(Uint8List rawData) async {
    if (device == null || device!.port == null) return false;
    ByteData encoded = ByteData(64);
    EncodeResult encodeResult =
        encodeCOBS(encoded, ByteData.sublistView(rawData));
    if (encodeResult.status != EncodeStatus.OK) return false;
    Uint8List encodedList = Uint8List(encodeResult.outLen + 1);
    encodedList.setRange(0, encodeResult.outLen, encoded.buffer.asUint8List());
    encodedList.last = 0;
    device!.port!.write(encodedList);
    return true;
  }

  Stream<CANFrame> _usbStream() async* {
    while (device == null || device!.port == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final reader = _usbRawStream();
    await for (Uint8List data in reader) {
      switch (data[0] >> 4) {
        case 0: //normalframe
          yield CANFrame(data);
          break;
        case 1: //establishment sucsess
          connectionEstablished = true;
          break;
      }
    }
  }

  //this is stream for receive data.
  //it do COBS.
  Stream<Uint8List> _usbRawStream() async* {
    List<int> buffer = List.generate(64, (index) => 0);
    int bufferIndex = 0;
    final stream = device!.port!.inputStream!.handleError((error) {
      print(error);
    });
    await for (Uint8List data in stream) {
      for (int i = 0; i < data.length; i++) {
        if (data[i] == 0) {
          ByteData decoded = ByteData(64);
          DecodeResult decodeResult = decodeCOBS(
              decoded, ByteData.sublistView(Uint8List.fromList(buffer), 0, i));
          if (decodeResult.status != DecodeStatus.OK) {
            buffer = Uint8List(0);
            continue;
          }
          yield decoded.buffer.asUint8List();
          buffer.setAll(0, List.generate(64, (index) => 0));
          bufferIndex = 0;
        } else {
          buffer[bufferIndex] = data[i];
          bufferIndex++;
        }
      }
    }
  }
}
