library usbcan_plugins;

import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'package:usbcan_plugins/usbcan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum UsbCanFormStyle {
  all,
  simple,
}

//it is a widget that can be used to send a can frame.
class UsbCanForm extends StatefulWidget {
  const UsbCanForm(
      {super.key,
      required this.onSendButtonPressed,
      required this.style,
      this.enabledModes = CanWidgetMode.values});

  final void Function(CANFrame) onSendButtonPressed;
  final UsbCanFormStyle style;
  final List<CanWidgetMode> enabledModes;

  @override
  State<UsbCanForm> createState() => _UsbCanFormState();
}

class _UsbCanFormState extends State<UsbCanForm> {
  int _canId = 0;
  Uint8List _data = Uint8List(0);
  bool isRtr = false;
  bool isExtended = false;
  bool isLittleEndian = false;

  CanWidgetMode mode = CanWidgetMode.hexMode;
  @override
  Widget build(BuildContext context) {
    if (widget.style == UsbCanFormStyle.simple) {
      isRtr = false;
      isExtended = false;
      isLittleEndian = false;
      return _mainWidget([]);
    } else {
      return _mainWidget([
        const Spacer(),
        const Text("Endian"),
        Checkbox(
            value: isLittleEndian,
            onChanged: (value) {
              setState(() {
                isLittleEndian = value ?? false;
              });
            }),
        const Spacer(),
        const Text("Rmt"),
        Checkbox(
            value: isRtr,
            onChanged: (value) {
              setState(() {
                isRtr = value ?? false;
              });
            }),
        const Spacer(),
        const Text("Ext"),
        Checkbox(
            value: isExtended,
            onChanged: (value) {
              setState(() {
                isExtended = value ?? false;
              });
            }),
        const Spacer(),
      ]);
    }
  }

  Column _mainWidget(List<Widget> children) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(
              width: 50, child: Text("ID:", style: TextStyle(fontSize: 18))),
          Expanded(
            child: HexSwitchField(
              mode: CanWidgetMode.hexMode,
              onChanged: (value) {
                _canId = value.fold<int>(
                    0,
                    (previousValue, element) =>
                        (previousValue << 8 | (0xFF & element)));
              },
            ),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(
              width: 50, child: Text("Data:", style: TextStyle(fontSize: 18))),
          Expanded(
            child: HexSwitchField(
              mode: mode,
              onChanged: (value) {
                _data = value;
              },
            ),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: children +
            [
              Container(
                padding: const EdgeInsets.all(10),
                child: DropdownMenu(
                  width: 120,
                  initialSelection: CanWidgetMode.hexMode,
                  dropdownMenuEntries: widget.enabledModes
                      .map((mode) => DropdownMenuEntry(
                          value: mode, label: mode.name.replaceAll("Mode", "")))
                      .toList(),
                  onSelected: (value) {
                    setState(() {
                      mode = value as CanWidgetMode? ?? CanWidgetMode.hexMode;
                    });
                  },
                ),
              ),
              ElevatedButton(
                  onPressed: () {
                    Uint8List data = _data;
                    if (isLittleEndian) {
                      data = Uint8List.fromList(data.reversed.toList());
                    }
                    widget.onSendButtonPressed(CANFrame.fromIdAndData(
                        _canId, data,
                        isRtr: isRtr, isExtended: isExtended));
                  },
                  child: const Text("Send"))
            ],
      ),
    ]);
  }
}

enum CanWidgetMode {
  hexMode,
  stringMode,
  floatMode,
  doubleMode,
  int16Mode,
  int32Mode,
  int64Mode,
  uint16Mode,
  uint32Mode,
  uint64Mode,
}

//it is a widget that can be used to input hex data.
class HexSwitchField extends StatefulWidget {
  const HexSwitchField(
      {super.key, required this.onChanged, required this.mode});

  final void Function(Uint8List) onChanged;
  final CanWidgetMode mode;

  @override
  State<HexSwitchField> createState() => _HexSwitchFieldState();
}

class _HexSwitchFieldState extends State<HexSwitchField> {
  Uint8List _data = Uint8List(0);

  @override
  Widget build(BuildContext context) {
    switch (widget.mode) {
      case CanWidgetMode.hexMode:
        return TextField(
          onChanged: (value) {
            _data = Uint8List.fromList(value
                .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
                .split("")
                .toList()
                .asMap()
                .map((key, value) {
                  if (key % 2 == 1) {
                    return MapEntry(key, "$value ");
                  } else {
                    return MapEntry(key, value);
                  }
                })
                .values
                .join()
                .split(" ")
                .map((e) => int.tryParse(e, radix: 16))
                .whereType<int>()
                .toList());
            widget.onChanged(_data);
          },
          controller: TextEditingController(
              text: _data
                  .map((e) => e.toRadixString(16).padLeft(2, "0"))
                  .map(
                    (e) => " $e",
                  )
                  .join()
                  .toUpperCase()),
          keyboardType: TextInputType.visiblePassword,
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              if (newValue.text.length > oldValue.text.length) {
                var sharpedData = newValue.text
                    .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
                    .toUpperCase()
                    .split("")
                    .asMap()
                    .map((key, value) {
                  if (key % 2 == 1) {
                    return MapEntry(key, "$value ");
                  } else {
                    return MapEntry(key, value);
                  }
                });
                return TextEditingValue(
                    text: sharpedData.values.join(),
                    selection: TextSelection.collapsed(
                        offset: sharpedData.values.join().length));
              } else {
                return newValue;
              }
            })
          ],
        );
      case CanWidgetMode.stringMode:
        return TextField(
            keyboardType: TextInputType.visiblePassword,
            onChanged: (value) {
              _data = const AsciiEncoder().convert(value);
              widget.onChanged(_data);
            },
            controller: TextEditingController(
                text: const AsciiDecoder(allowInvalid: true).convert(_data)));
      case CanWidgetMode.floatMode:
        return TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
            ],
            onChanged: (value) {
              _data = value.isEmpty || value == "-"
                  ? Uint8List(0)
                  : Float32List.fromList([double.parse(value)])
                      .buffer
                      .asUint8List();
              widget.onChanged(_data);
            },
            controller: TextEditingController(
                text: _data.buffer.asFloat32List().isEmpty
                    ? ""
                    : _data.buffer.asFloat32List().first.toString()));
      case CanWidgetMode.doubleMode:
        return TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
            ],
            onChanged: (value) {
              _data = value.isEmpty || value == "-"
                  ? Uint8List(0)
                  : Float64List.fromList([double.parse(value)])
                      .buffer
                      .asUint8List();
              widget.onChanged(_data);
            },
            controller: TextEditingController(
                text: _data.buffer.asFloat64List().isEmpty
                    ? ""
                    : _data.buffer.asFloat64List().first.toString()));
      case CanWidgetMode.int16Mode:
        return TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
            ],
            onChanged: (value) {
              _data = value.isEmpty || value == "-"
                  ? Uint8List(0)
                  : Int16List.fromList([int.parse(value)]).buffer.asUint8List();
              widget.onChanged(_data);
            },
            controller: TextEditingController(
                text: _data.buffer.asInt16List().isEmpty
                    ? ""
                    : _data.buffer.asInt16List().first.toString()));
      case CanWidgetMode.int32Mode:
        return TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
            ],
            onChanged: (value) {
              _data = value.isEmpty || value == "-"
                  ? Uint8List(0)
                  : Int32List.fromList([int.parse(value)]).buffer.asUint8List();
              widget.onChanged(_data);
            },
            controller: TextEditingController(
                text: _data.buffer.asInt32List().isEmpty
                    ? ""
                    : _data.buffer.asInt32List().first.toString()));
      case CanWidgetMode.int64Mode:
        return TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
            ],
            onChanged: (value) {
              _data = value.isEmpty || value == "-"
                  ? Uint8List(0)
                  : Int64List.fromList([int.parse(value)]).buffer.asUint8List();
              widget.onChanged(_data);
            },
            controller: TextEditingController(
                text: _data.buffer.asInt64List().isEmpty
                    ? ""
                    : _data.buffer.asInt64List().first.toString()));
      case CanWidgetMode.uint16Mode:
        return TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*'))
            ],
            onChanged: (value) {
              _data = value.isEmpty || value == "-"
                  ? Uint8List(0)
                  : Uint16List.fromList([int.parse(value)])
                      .buffer
                      .asUint8List();
              widget.onChanged(_data);
            },
            controller: TextEditingController(
                text: _data.buffer.asUint16List().isEmpty
                    ? ""
                    : _data.buffer.asUint16List().first.toString()));
      case CanWidgetMode.uint32Mode:
        return TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*'))
            ],
            onChanged: (value) {
              _data = value.isEmpty || value == "-"
                  ? Uint8List(0)
                  : Uint32List.fromList([int.parse(value)])
                      .buffer
                      .asUint8List();
              widget.onChanged(_data);
            },
            controller: TextEditingController(
                text: _data.buffer.asUint32List().isEmpty
                    ? ""
                    : _data.buffer.asUint32List().first.toString()));
      case CanWidgetMode.uint64Mode:
        return TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*'))
            ],
            onChanged: (value) {
              _data = value.isEmpty
                  ? Uint8List(0)
                  : Uint64List.fromList([int.parse(value)])
                      .buffer
                      .asUint8List();
              widget.onChanged(_data);
            },
            controller: TextEditingController(
                text: _data.buffer.asUint64List().isEmpty
                    ? ""
                    : _data.buffer.asUint64List().first.toString()));
      default:
        return Text("Not implemented: ${widget.mode}");
    }
  }
}

/// A widget that displays a CAN frame in a list tile.
class CanFrameTile extends StatelessWidget {
  final CANFrame frame;
  final CanWidgetMode mode;

  final void Function(CANFrame)? onFrameTap;
  final void Function(CANFrame)? onFrameLongPress;

  const CanFrameTile(
      {Key? key,
      required this.frame,
      this.onFrameTap,
      this.onFrameLongPress,
      required this.mode})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case CanWidgetMode.hexMode:
        return _generateWidget(frame.data
            .map((e) => e.toRadixString(16).padLeft(2, "0"))
            .map(
              (e) => " $e",
            )
            .join()
            .toUpperCase());
      case CanWidgetMode.int16Mode:
        return _generateWidget(frame.data.buffer
            .asInt16List()
            .map((e) => e.toString())
            .join()
            .toUpperCase());
      case CanWidgetMode.int32Mode:
        return _generateWidget(frame.data.buffer
            .asInt32List()
            .map((e) => e.toString())
            .join()
            .toUpperCase());
      case CanWidgetMode.int64Mode:
        return _generateWidget(frame.data.buffer
            .asInt64List()
            .map((e) => e.toString())
            .join()
            .toUpperCase());
      case CanWidgetMode.uint16Mode:
        return _generateWidget(frame.data.buffer
            .asUint16List()
            .map((e) => e.toString())
            .join()
            .toUpperCase());
      case CanWidgetMode.uint32Mode:
        return _generateWidget(frame.data.buffer
            .asUint32List()
            .map((e) => e.toString())
            .join()
            .toUpperCase());
      case CanWidgetMode.uint64Mode:
        return _generateWidget(frame.data.buffer
            .asUint64List()
            .map((e) => e.toString())
            .join()
            .toUpperCase());
      case CanWidgetMode.stringMode:
        return _generateWidget(String.fromCharCodes(frame.data));
      case CanWidgetMode.floatMode:
        return _generateWidget(frame.data.buffer
            .asFloat32List()
            .map((e) => e.toString())
            .join()
            .toUpperCase());
      case CanWidgetMode.doubleMode:
        return _generateWidget(frame.data.buffer
            .asFloat64List()
            .map((e) => e.toString())
            .join()
            .toUpperCase());
    }
  }

  ListTile _generateWidget(String dataText) {
    Widget leadingIcon = const Icon(Icons.message);
    if (frame.isError) {
      leadingIcon = const Icon(Icons.error);
    } else if (frame.isRtr) {
      leadingIcon = const Icon(Icons.outgoing_mail);
    } else if (frame.isExtended) {
      leadingIcon = const Icon(Icons.message);
    }
    return ListTile(
      leading: leadingIcon,
      title: Text("ID : ${frame.canId.toString()}"
          " (0x${frame.canId.toRadixString(16).toUpperCase()})"),
      subtitle: Text(dataText + (frame.isExtended ? " (Extended)" : "")),
      onTap: () => onFrameTap?.call(frame),
      onLongPress: () => onFrameLongPress?.call(frame),
    );
  }
}
