import 'dart:typed_data';

abstract class Frame {
  Uint8List toUint8List();
}

class CANFrame implements Frame {
  /*                                                                     
   uint8_t command :( if it is normal can frame, it is 0x00. )<<4 
                    | (isRtr << 2 | isExtended << 1 | isError)                  
   uint8_t id[4] : can id                                                 
   uint8_t dlc : data length                                              
   uint8_t data[8] : data                                                 
   */
  CANFrame(Uint8List frame) {
    isRtr = (frame[0] & 0x04) != 0;
    isExtended = (frame[0] & 0x02) != 0;
    isError = (frame[0] & 0x01) != 0;
    canId = (frame[1] << 24) | (frame[2] << 16) | (frame[3] << 8) | frame[4];
    //frame[5] is dlc.
    data = frame.sublist(6, 6 + frame[5]);
  }

  CANFrame.fromIdAndData(this.canId, this.data,
      {this.isRtr = false, this.isExtended = false, this.isError = false});

  late int canId;
  late Uint8List data;
  late bool isError;
  late bool isExtended;
  late bool isRtr;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CANFrame &&
          canId == other.canId &&
          isRtr == other.isRtr &&
          isExtended == other.isExtended &&
          isError == other.isError &&
          data == other.data;

  @override
  int get hashCode {
    return canId.hashCode ^
        isRtr.hashCode ^
        isExtended.hashCode ^
        isError.hashCode ^
        data.hashCode;
  }

  @override
  String toString() {
    return 'CANFrame{canId: $canId, isRtr: $isRtr, isExtended: $isExtended, isError: $isError, data: $data}';
  }

  @override
  Uint8List toUint8List() {
    Uint8List frame = Uint8List(6 + data.length);
    frame[0] = (isRtr ? 0x04 : 0x00) |
        (isExtended ? 0x02 : 0x00) |
        (isError ? 0x01 : 0x00);
    frame[1] = (canId >> 24) & 0xFF;
    frame[2] = (canId >> 16) & 0xFF;
    frame[3] = (canId >> 8) & 0xFF;
    frame[4] = canId & 0xFF;
    frame[5] = data.length;
    frame.setRange(6, 6 + data.length, data);
    return frame;
  }
}

class RobomasterTargetFrame implements Frame {
  const RobomasterTargetFrame(this.motorNumber, this.target);

  static const int commandID = 3;

  final int motorNumber;
  final double target;

  @override
  Uint8List toUint8List() {
    var data = Uint8List(5);
    data[0] = (commandID << 4) + (1 << 3) + 0x7 & motorNumber;
    data.setRange(
        1, 1 + 4, Float32List.fromList([target]).buffer.asUint8List());
    return data;
  }
}

enum RobomasterMotorType { c610, c620 }

enum RobomasterMotorMode { dis, vel, pos }

class RobomasterSettingFrame implements Frame {
  const RobomasterSettingFrame(
    this.motorType,
    this.motorMode,
    this.motorNumber,
    this.temparture,
    this.kp,
    this.ki,
    this.kd,
    this.ke,
  );

  static const int commandID = 3;
  final int temparture;
  final double kd;
  final double ke;
  final double ki;
  final double kp;
  final RobomasterMotorMode motorMode;
  final int motorNumber;
  final RobomasterMotorType motorType;

  @override
  Uint8List toUint8List() {
    int mode = switch (motorMode) {
      RobomasterMotorMode.dis => 0,
      RobomasterMotorMode.vel => 1,
      RobomasterMotorMode.pos => 2,
    };

    var data = Uint8List(19);
    data[0] = (commandID << 4) + 0x7 & motorNumber;
    data[1] = (motorType == RobomasterMotorType.c610 ? 1 : 0) << 7 + mode;
    data[2] = temparture;
    data.setRange(3, 3 + 4 * 4,
        Float32List.fromList([kp, ki, kd, ke]).buffer.asUint8List());
    return data;
  }
}
