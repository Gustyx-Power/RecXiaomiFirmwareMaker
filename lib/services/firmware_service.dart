import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import '../models/firmware_mode.dart';
import '../utils/logger.dart';

class FirmwareService {
  final Function(String) onLog;
  final logger = Logger();

  FirmwareService({required this.onLog});

  Future<String> createFirmware({
    required String inputRomPath,
    required FirmwareMode mode,
  }) async {
    try {
      onLog('🚀 Starting firmware extraction...');
      onLog('');

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final workDir = Directory('${tempDir.path}/firmware_work_$timestamp');
      final outputDir = Directory('${tempDir.path}/firmware_output');
      final firmwareDir = Directory('${workDir.path}/firmware-update');

      await workDir.create(recursive: true);
      await outputDir.create(recursive: true);
      await firmwareDir.create(recursive: true);

      onLog('📦 Extracting ROM: ${path.basename(inputRomPath)}');
      await extractZip(inputRomPath, workDir.path);
      onLog('✅ ROM extracted');
      onLog('');

      // Check for payload.bin
      final payloadPath = await findPayloadBin(workDir);
      if (payloadPath != null) {
        onLog('🎯 Payload.bin DETECTED!');
        onLog('');

        // Extract with payload_dumper
        await extractPayloadBinRust(payloadPath, firmwareDir, workDir);
      } else {
        onLog('📋 No payload.bin - extracting from ROM');
        await extractAllFirmwareFiles(workDir, firmwareDir);
      }

      // Count files
      int totalFiles = await countFiles(firmwareDir);

      onLog('');
      onLog('📊 Total files: $totalFiles');
      onLog('');

      if (totalFiles == 0) {
        throw Exception('No firmware files found!');
      }

      // Process based on mode
      onLog('⚙️  Mode: ${mode.label}');
      onLog('');

      switch (mode) {
        case FirmwareMode.normal:
          onLog('✅ Standard Firmware');
          break;
        case FirmwareMode.nonArb:
          onLog('🔥 Removing ARB files');
          await removeArbFiles(firmwareDir);
          break;
        case FirmwareMode.withVendor:
          onLog('📦 With vendor files');
          break;
        case FirmwareMode.firmwareless:
          onLog('⚡ Firmware only');
          await filterFirmwarelessRom(firmwareDir);
          break;
      }

      onLog('');
      onLog('📝 Creating scripts...');
      await createUpdaterScript(firmwareDir);

      final romName = path.basenameWithoutExtension(inputRomPath);
      final outputName = '${mode.prefix}_$romName.zip';
      final outputPath = '${outputDir.path}/$outputName';

      onLog('📦 Creating ZIP...');
      await createZip(firmwareDir.path, outputPath);

      if (!await File(outputPath).exists()) {
        throw Exception('ZIP creation failed');
      }

      onLog('');
      onLog('🧹 Cleaning up...');
      try {
        await workDir.delete(recursive: true);
      } catch (_) {}

      final fileSize = await File(outputPath).length();
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

      onLog('');
      onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      onLog('✨ SUCCESS!');
      onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      onLog('');
      onLog('📁 Output: $outputName');
      onLog('📊 Size: $fileSizeMB MB');
      onLog('📍 Path: ${outputDir.path}');
      onLog('');

      return outputPath;

    } catch (e) {
      onLog('');
      onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      onLog('❌ ERROR!');
      onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      onLog('');
      onLog('Error: $e');
      onLog('');
      logger.error('Failed: $e');
      rethrow;
    }
  }

  Future<void> extractZip(String zipPath, String outputPath) async {
    try {
      final inputStream = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeBuffer(inputStream);

      for (final file in archive) {
        final filePath = '$outputPath/${file.name}';
        if (file.isFile) {
          final fileDir = Directory(path.dirname(filePath));
          await fileDir.create(recursive: true);
          await File(filePath).writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }
      inputStream.close();
    } catch (e) {
      onLog('❌ ZIP error: $e');
      rethrow;
    }
  }

  Future<String?> findPayloadBin(Directory workDir) async {
    try {
      await for (final entity in workDir.list(recursive: true)) {
        if (entity is File &&
            path.basename(entity.path).toLowerCase() == 'payload.bin') {
          return entity.path;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _findPayloadDumper() async {
    try {
      // Try multiple possible locations
      final locations = [
        'payload_dumper', // In PATH
        '${Platform.environment['HOME']}/.local/bin/payload_dumper', // Auto-installed
        '${Platform.environment['HOME']}/.extra/bin/payload_dumper', // Official script location
        '/usr/local/bin/payload_dumper', // System-wide
        '/usr/bin/payload_dumper', // System binary
      ];

      for (final loc in locations) {
        try {
          final result = await Process.run(
            loc,
            ['--version'],
            runInShell: false,
          ).timeout(const Duration(seconds: 3));

          if (result.exitCode == 0) {
            return loc;
          }
        } catch (_) {
          continue;
        }
      }

      // Try 'which' command as fallback
      try {
        final whichResult = await Process.run('which', ['payload_dumper']);
        if (whichResult.exitCode == 0) {
          final foundPath = whichResult.stdout.toString().trim();
          if (foundPath.isNotEmpty && await File(foundPath).exists()) {
            return foundPath;
          }
        }
      } catch (_) {}

    } catch (_) {}

    return null;
  }

  Future<void> extractPayloadBinRust(
      String payloadPath,
      Directory firmwareDir,
      Directory workDir,
      ) async {
    try {
      final payloadOutputDir = '${workDir.path}/payload_extracted';
      await Directory(payloadOutputDir).create(recursive: true);

      onLog('📊 Payload.bin size: ${(await File(payloadPath).length() / (1024 * 1024)).toStringAsFixed(0)} MB');
      onLog('⏳ Extracting...');
      onLog('');

      // Find payload_dumper binary
      var dumperPath = await _findPayloadDumper();

      if (dumperPath == null) {
        onLog('❌ payload_dumper not found in any location');
        onLog('');
        onLog('💡 Searched locations:');
        onLog('  - System PATH');
        onLog('  - ~/.local/bin/payload_dumper');
        onLog('  - ~/.extra/bin/payload_dumper');
        onLog('  - /usr/local/bin/payload_dumper');
        onLog('');
        onLog('💡 Install using Dependency Check or run:');
        onLog('   bash <(curl -sSL https://raw.githubusercontent.com/rhythmcache/payload-dumper-rust/main/scripts/install.sh)');
        onLog('');
        throw Exception('payload_dumper binary not found');
      }


      onLog('✓ Using: $dumperPath');
      onLog('');

      // Run extraction
      final result = await Process.run(
        dumperPath,
        [payloadPath, '-o', payloadOutputDir],
        runInShell: false,
      ).timeout(const Duration(minutes: 20));

      if (result.exitCode != 0) {
        onLog('❌ Extraction error:');
        if (result.stderr.isNotEmpty) {
          onLog(result.stderr.toString());
        }
        throw Exception('Extraction failed: exit code ${result.exitCode}');
      }

      // Copy extracted files
      int copied = 0;
      await for (final entity in Directory(payloadOutputDir).list(recursive: false)) {
        if (entity is File) {
          final fname = path.basename(entity.path);
          if (fname.toLowerCase() == 'payload.bin') continue;

          final destPath = '${firmwareDir.path}/$fname';
          await entity.copy(destPath);
          onLog('  ✓ $fname');
          copied++;
        }
      }

      onLog('');
      onLog('✅ Extracted $copied files');

      if (copied == 0) {
        throw Exception('No files extracted from payload.bin!');
      }

    } catch (e) {
      onLog('❌ Error: $e');
      rethrow;
    }
  }

  Future<void> extractAllFirmwareFiles(
      Directory workDir,
      Directory firmwareDir,
      ) async {
    try {
      int copied = 0;

      await for (final entity in workDir.list(recursive: true)) {
        if (entity is File) {
          final fname = path.basename(entity.path).toLowerCase();

          if (fname.startsWith('system') ||
              fname.startsWith('vendor') ||
              fname.startsWith('product') ||
              fname.startsWith('odm') ||
              fname == 'super.img' ||
              fname == 'payload.bin') {
            continue;
          }

          if (fname.endsWith('.img') ||
              fname.endsWith('.bin') ||
              fname.endsWith('.mbn') ||
              fname.endsWith('.elf')) {

            final destPath = '${firmwareDir.path}/$fname';
            await entity.copy(destPath);
            copied++;
          }
        }
      }

      if (copied > 0) {
        onLog('  ✓ Copied $copied firmware files');
      }
    } catch (e) {
      onLog('  ⚠️  Error: $e');
    }
  }

  Future<int> countFiles(Directory dir) async {
    int count = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && !entity.path.contains('META-INF')) {
          count++;
        }
      }
    } catch (_) {}
    return count;
  }

  Future<void> removeArbFiles(Directory firmwareDir) async {
    int removed = 0;
    for (final arbFile in FirmwareExtensions.arbFiles) {
      final file = File('${firmwareDir.path}/$arbFile');
      if (await file.exists()) {
        try {
          await file.delete();
          removed++;
        } catch (_) {}
      }
    }
    if (removed > 0) {
      onLog('✅ Removed $removed ARB files');
    }
  }

  Future<void> filterFirmwarelessRom(Directory firmwareDir) async {
    try {
      int removed = 0;
      int kept = 0;

      final toRemove = [
        'system.img', 'vendor.img', 'product.img', 'odm.img',
        'super.img', 'system.transfer.list', 'system.new.dat',
      ];

      await for (final entity in firmwareDir.list(recursive: true)) {
        if (entity is File && !entity.path.contains('META-INF')) {
          final fname = path.basename(entity.path).toLowerCase();

          bool shouldRemove = false;
          for (final pattern in toRemove) {
            if (fname.contains(pattern)) {
              shouldRemove = true;
              break;
            }
          }

          if (shouldRemove) {
            try {
              await entity.delete();
              removed++;
            } catch (_) {}
          } else {
            kept++;
          }
        }
      }

      onLog('✅ Filtered: kept $kept, removed $removed');
    } catch (e) {
      onLog('⚠️  Filter error: $e');
    }
  }

  Future<void> createUpdaterScript(Directory firmwareDir) async {
    try {
      final metaInfDir = Directory(
        '${firmwareDir.path}/META-INF/com/google/android',
      );
      await metaInfDir.create(recursive: true);

      final updateBinary = File('${metaInfDir.path}/update-binary');
      await updateBinary.writeAsString('''#!/sbin/sh
OUTFD="/proc/self/fd/\$2"
ZIPFILE="\$3"

ui_print() {
  echo "ui_print \$1" > "\$OUTFD"
  echo "ui_print" > "\$OUTFD"
}

ui_print "RecXiaomiFirmwareMaker v2.0"
cd /tmp
mkdir -p fw_pkg
unzip -o "\$ZIPFILE" -d fw_pkg/

for img in fw_pkg/*.img; do
  [ -f "\$img" ] || continue
  filename=\$(basename "\$img" .img)
  
  if [ -b "/dev/block/bootdevice/by-name/\$filename" ]; then
    dd if="\$img" of="/dev/block/bootdevice/by-name/\$filename" bs=4M 2>/dev/null
  elif [ -b "/dev/block/by-name/\$filename" ]; then
    dd if="\$img" of="/dev/block/by-name/\$filename" bs=4M 2>/dev/null
  fi
done

ui_print "Done!"
exit 0
''');

      final updaterScript = File('${metaInfDir.path}/updater-script');
      await updaterScript.writeAsString('# Update\n');

      if (Platform.isLinux || Platform.isMacOS) {
        await Process.run('chmod', ['+x', updateBinary.path]);
      }
    } catch (e) {
      onLog('⚠️  Script error: $e');
    }
  }

  Future<void> createZip(String sourceDir, String outputZipPath) async {
    try {
      final encoder = ZipFileEncoder();
      encoder.create(outputZipPath);
      encoder.addDirectory(Directory(sourceDir));
      encoder.close();
    } catch (e) {
      onLog('❌ ZIP error: $e');
      rethrow;
    }
  }
}
