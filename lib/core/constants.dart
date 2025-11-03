class AppConstants {
  // App Info
  static const String appName = 'RecXiaomiFirmwareMaker';
  static const String appVersion = '1.0';
  static const String appDescription = 'Modern Xiaomi Firmware Creator with Payload.bin Support';

  // File Extensions
  static const List<String> supportedExtensions = ['zip'];

  // Timeout Duration
  static const Duration processTimeout = Duration(minutes: 30);

  // Buffer Size
  static const int bufferSize = 4 * 1024 * 1024; // 4MB

  // Supported Devices
  static const List<String> supportedDeviceExamples = [
    'Xiaomi Mi 8 (Legacy)',
    'Xiaomi Mi 9',
    'Redmi K20',
    'POCO F1',
    'Redmi Note 8',
    'Xiaomi Mi 11 (Modern)',
    'Redmi K40',
    'POCO X3',
    'POCO F3'
    'POCO F4',
    'POCO F5',
    'Redmi Note 12',
    'Xiaomi 13',
    'POCO F5 Pro',
  ];
}

class FirmwareExtensions {
  static const List<String> legacyFirmwareFiles = [
    'NON-HLOS.bin', 'adspso.bin', 'cmnlib.mbn', 'cmnlib64.mbn',
    'devcfg.mbn', 'hyp.mbn', 'keymaster.mbn', 'xbl.elf', 'xbl_config.elf',
    'tz.mbn', 'abl.elf', 'dspso.bin', 'BTFM.bin', 'imagefv.elf',
    'qupv3fw.elf', 'storsec.mbn', 'km4.mbn', 'logo.bin', 'splash.img',
  ];

  static const List<String> modernFirmwareFiles = [
    'xbl.img', 'xbl.elf', 'xbl_config.img', 'xbl_config.elf', 'abl.img',
    'abl.elf', 'tz.img', 'tz.mbn', 'boot.img', 'vendor_boot.img',
    'dtbo.img', 'recovery.img', 'init_boot.img', 'vbmeta.img',
    'vbmeta_system.img', 'vbmeta_vendor.img', 'modem.img', 'dsp.img',
    'bluetooth.img', 'featenabler.img', 'logo.img', 'splash.img',
    'hyp.img', 'devcfg.img', 'keymaster.img', 'cmnlib.img', 'cmnlib64.img',
    'ImageFv.img', 'qupfw.img', 'uefisecapp.img', 'shrm.img', 'aop.img',
    'aop_config.img', 'cpucp.img', 'qupv3fw.img', 'imagefv.img',
  ];

  static const List<String> arbFiles = [
    'xbl.elf', 'xbl.img', 'xbl_config.elf', 'xbl_config.img',
    'abl.elf', 'abl.img', 'tz.mbn', 'tz.img',
  ];

  static const List<String> vendorFiles = [
    'vendor.img', 'vendor.transfer.list', 'vendor.new.dat',
    'vendor.new.dat.br', 'vendor.patch.dat', 'vendor_dlkm.img',
  ];

  static const List<String> superPartitionComponents = [
    'system.img', 'system_ext.img', 'vendor.img', 'product.img',
    'odm.img', 'vendor_dlkm.img', 'odm_dlkm.img', 'system_dlkm.img',
  ];
}
