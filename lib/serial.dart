library usbcan_plugins;

import 'dart:io';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

//TODO: #1 This is a stupid implementation. It should be changed.

//It is same behavior of UsbSerial on usbserial package.
class Serial {
  static Future<List<Device>> listDevices() async {
    if (Platform.isWindows) {
      return (SerialPort.availablePorts)
          .map((e) => Device.fromSerialPort(e))
          .toList();
    } else if (Platform.isAndroid) {
      return (await UsbSerial.listDevices())
          .map((e) => Device.fromUsbDevice(e))
          .toList();
    }
    return [];
  }
}

//It is same behavior of UsbSerial on usbserial package.
class Device {
  UsbDevice? usbDevice;
  SerialPort? serialPort;
  int? get vid {
    if (Platform.isAndroid) {
      if (usbDevice != null) {
        return usbDevice!.vid;
      }
    } else if (Platform.isWindows) {
      if (serialPort != null) {
        return serialPort!.vendorId;
      }
    }
    return null;
  }

  int? get pid {
    if (Platform.isAndroid) {
      if (usbDevice != null) {
        return usbDevice!.pid;
      } else if (Platform.isWindows) {
        if (serialPort != null) {
          return serialPort!.productId;
        }
      }
    }
    return null;
  }

  Port? get port {
    if (usbDevice != null) {
      return Port.fromUsbDevice(usbDevice!);
    } else if (serialPort != null) {
      return Port.fromSerialPort(serialPort!);
    }
    print("Device is not created.");
    return null;
  }

  Future<void> create() async {
    if (Platform.isAndroid) {
      if (usbDevice != null) {
        await usbDevice!.create();
      }
    } else if (Platform.isWindows) {
      //notthing to do.
    }
  }

  Device.fromUsbDevice(UsbDevice this.usbDevice);
  Device.fromSerialPort(String portName) {
    serialPort = SerialPort(portName);
  }
}

//It is same behavior of UsbPort on usbserial package.
class Port {
  UsbDevice? usbDevice;
  SerialPort? serialPort;
  void setPortParameters(int baudRate) {
    if (usbDevice != null) {
      if (usbDevice!.port != null) {
        usbDevice!.port!.setPortParameters(baudRate, UsbPort.DATABITS_8,
            UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
      }
    } else if (serialPort != null) {
      //notthing to do.
    }
  }

  Future<bool> open() {
    if (Platform.isAndroid) {
      return usbDevice!.port!.open();
    } else if (Platform.isWindows) {
      return Future.value(serialPort!.openReadWrite());
    }
    return Future.value(false);
  }

  Future<bool> close() {
    if (Platform.isAndroid) {
      return usbDevice!.port!.close();
    } else if (Platform.isWindows) {
      return Future.value(serialPort!.close());
    }
    return Future.value(false);
  }

  Future write(Uint8List data) async {
    if (Platform.isAndroid) {
      await usbDevice!.port!.write(data);
    } else if (Platform.isWindows) {
      serialPort!.write(data);
    }
  }

  Stream<Uint8List>? get inputStream {
    if (Platform.isAndroid) {
      return usbDevice!.port!.inputStream;
    } else if (Platform.isWindows) {
      return SerialPortReader(serialPort!).stream;
    }
    throw Exception('Device is not created.');
  }

  Port.fromUsbDevice(UsbDevice this.usbDevice);
  Port.fromSerialPort(SerialPort this.serialPort);
}
