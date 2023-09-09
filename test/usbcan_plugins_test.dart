import 'package:flutter_test/flutter_test.dart';
import 'package:usbcan_plugins/usbcan.dart';

void main() {
  test("make usbcan instance and try connection", () {
    UsbCan usbCan = UsbCan();
    usbCan.connectUSB();
  });
}
