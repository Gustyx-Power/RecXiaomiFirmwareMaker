import 'package:flutter/material.dart';

enum FirmwareMode {
  normal,
  nonArb,
  withVendor,
  firmwareless;

  String get label {
    switch (this) {
      case FirmwareMode.normal:
        return 'Standard Firmware';
      case FirmwareMode.nonArb:
        return 'Non-ARB Firmware';
      case FirmwareMode.withVendor:
        return 'Firmware with Vendor';
      case FirmwareMode.firmwareless:
        return 'Firmwareless ROM';
    }
  }

  String get description {
    switch (this) {
      case FirmwareMode.normal:
        return 'Extract all firmware including bootloader and ARB protection';
      case FirmwareMode.nonArb:
        return 'Remove anti-rollback files (xbl, abl, tz) - safe for downgrade';
      case FirmwareMode.withVendor:
        return 'Include firmware files with vendor partition images';
      case FirmwareMode.firmwareless:
        return 'ROM without any firmware files (system only)';
    }
  }

  String get prefix {
    switch (this) {
      case FirmwareMode.normal:
        return 'fw';
      case FirmwareMode.nonArb:
        return 'fw_noarb';
      case FirmwareMode.withVendor:
        return 'fw_vendor';
      case FirmwareMode.firmwareless:
        return 'firmwareless';
    }
  }

  IconData get icon {
    switch (this) {
      case FirmwareMode.normal:
        return Icons.settings;
      case FirmwareMode.nonArb:
        return Icons.shield;
      case FirmwareMode.withVendor:
        return Icons.layers;
      case FirmwareMode.firmwareless:
        return Icons.layers_clear;
    }
  }
}
