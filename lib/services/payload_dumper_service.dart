import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

class PayloadDumperService {
  final Function(String) onLog;
  final logger = Logger();

  PayloadDumperService({required this.onLog});

  Future<bool> isPayloadBinAvailable(String workDirPath) async {
    try {
      final dir = Directory(workDirPath);
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File &&
            path.basename(entity.path).toLowerCase() == 'payload.bin') {
          return true;
        }
      }
    } catch (e) {
      onLog('⚠️  Error checking payload.bin: $e');
    }
    return false;
  }

  Future<String?> findPayloadBin(String workDirPath) async {
    try {
      final dir = Directory(workDirPath);
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File &&
            path.basename(entity.path).toLowerCase() == 'payload.bin') {
          return entity.path;
        }
      }
    } catch (e) {
      onLog('⚠️  Error finding payload.bin: $e');
    }
    return null;
  }

  Future<void> extractPayloadBin({
    required String payloadBinPath,
    required String outputDirPath,
  }) async {
    try {
      onLog('🔓 Extracting payload.bin (this may take a while)...');

      final payloadDir = Directory(outputDirPath);
      await payloadDir.create(recursive: true);

      // Try using python module directly with full path
      bool extracted = false;

      // Method 1: Direct python3 -m payload_dumper with full PATH
      extracted = await _tryPayloadDumperMethod1(payloadBinPath, outputDirPath);

      // Method 2: Find payload_dumper.py in user site-packages
      if (!extracted) {
        extracted = await _tryPayloadDumperMethod2(payloadBinPath, outputDirPath);
      }

      // Method 3: Use virtual environment if exists
      if (!extracted) {
        extracted = await _tryPayloadDumperMethod3(payloadBinPath, outputDirPath);
      }

      // Method 4: Fallback - copy payload.bin to output for manual extraction
      if (!extracted) {
        onLog('⚠️  Automated extraction failed');
        onLog('💡 Payload.bin will be kept for manual extraction');
        onLog('💡 Or use: python3 -m payload_dumper "$payloadBinPath" -o "$outputDirPath"');
        throw Exception('Could not extract payload.bin automatically');
      }

      onLog('✅ Payload.bin extracted successfully');
    } catch (e) {
      onLog('❌ Extraction failed: $e');
      rethrow;
    }
  }

  Future<bool> _tryPayloadDumperMethod1(String payloadPath, String outputDir) async {
    try {
      onLog('  Attempt 1: Using python3 -m payload_dumper...');

      final result = await Process.run(
        'python3',
        ['-m', 'payload_dumper', payloadPath, '-o', outputDir],
        runInShell: true,
        environment: {
          ...Platform.environment,
          'PYTHONUNBUFFERED': '1',
        },
      ).timeout(const Duration(minutes: 25));

      if (result.exitCode == 0) {
        onLog('  ✅ Method 1 successful!');
        return true;
      } else {
        onLog('  ⚠️  Exit code: ${result.exitCode}');
        if (result.stderr.isNotEmpty) {
          final stderr = result.stderr.toString();
          onLog('  Error: ${stderr.length > 150 ? stderr.substring(0, 150) : stderr}');
        }
        return false;
      }
    } catch (e) {
      onLog('  ⚠️  Method 1 timeout/error: $e');
      return false;
    }
  }

  Future<bool> _tryPayloadDumperMethod2(String payloadPath, String outputDir) async {
    try {
      onLog('  Attempt 2: Finding payload_dumper in site-packages...');

      // Find site-packages directory
      final findResult = await Process.run(
        'python3',
        ['-c', 'import site; print(site.USER_SITE)'],
        runInShell: true,
      ).timeout(const Duration(seconds: 5));

      if (findResult.exitCode == 0) {
        final sitePkgs = findResult.stdout.toString().trim();
        final payloadDumperPath = '$sitePkgs/payload_dumper/__main__.py';

        onLog('  Found site-packages: $sitePkgs');

        final result = await Process.run(
          'python3',
          [payloadDumperPath, payloadPath, '-o', outputDir],
          runInShell: true,
        ).timeout(const Duration(minutes: 25));

        if (result.exitCode == 0) {
          onLog('  ✅ Method 2 successful!');
          return true;
        }
      }
      return false;
    } catch (e) {
      onLog('  ⚠️  Method 2 failed: $e');
      return false;
    }
  }

  Future<bool> _tryPayloadDumperMethod3(String payloadPath, String outputDir) async {
    try {
      onLog('  Attempt 3: Using virtual environment...');

      // Check common venv locations
      final homeDir = Platform.environment['HOME'] ?? '';
      final venvPaths = [
        '$homeDir/.venv_recfirmware/bin/python',
        '$homeDir/.venv/bin/python',
        '$homeDir/venv/bin/python',
        '/usr/local/bin/python3',
        '/opt/homebrew/bin/python3',
      ];

      for (final venvPythonPath in venvPaths) {
        try {
          final venvCheck = await Process.run('test', ['-f', venvPythonPath])
              .timeout(const Duration(seconds: 2));

          if (venvCheck.exitCode == 0) {
            onLog('  Found Python: $venvPythonPath');

            final result = await Process.run(
              venvPythonPath,
              ['-m', 'payload_dumper', payloadPath, '-o', outputDir],
              runInShell: true,
            ).timeout(const Duration(minutes: 25));

            if (result.exitCode == 0) {
              onLog('  ✅ Method 3 successful!');
              return true;
            }
          }
        } catch (_) {
          continue;
        }
      }

      return false;
    } catch (e) {
      onLog('  ⚠️  Method 3 failed: $e');
      return false;
    }
  }

  Future<void> verifyExtraction(String outputDirPath) async {
    try {
      final dir = Directory(outputDirPath);
      int imgCount = 0;
      final List<String> extractedFiles = [];

      await for (final entity in dir.list()) {
        if (entity is File) {
          final filename = path.basename(entity.path);
          if (filename.endsWith('.img') ||
              filename.endsWith('.bin') ||
              filename.endsWith('.mbn') ||
              filename.endsWith('.elf')) {
            imgCount++;
            extractedFiles.add(filename);
          }
        }
      }

      if (imgCount > 0) {
        onLog('📊 Extracted files:');
        for (final file in extractedFiles.take(10)) {
          onLog('  ✓ $file');
        }
        if (extractedFiles.length > 10) {
          onLog('  ... and ${extractedFiles.length - 10} more files');
        }
        onLog('📊 Total: $imgCount firmware images');
      }

      if (imgCount == 0) {
        throw Exception('No firmware files extracted');
      }
    } catch (e) {
      onLog('⚠️  Verification error: $e');
    }
  }
}
