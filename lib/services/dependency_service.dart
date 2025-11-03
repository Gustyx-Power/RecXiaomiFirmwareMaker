import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

class DependencyService {
  final Function(String) onLog;
  final logger = Logger();

  DependencyService({required this.onLog});

  Future<Map<String, bool>> checkAllDependencies() async {
    onLog('🔍 Checking system dependencies...');

    final results = <String, bool>{};

    // Check Python3
    results['python3'] = await _checkPython3();

    // Check pip3
    results['pip3'] = await _checkPip3();

    // Check payload_dumper (nama binary yang benar)
    results['payload_dumper'] = await _checkPayloadDumper();

    // Check unzip (Linux/Mac only)
    if (Platform.isLinux || Platform.isMacOS) {
      results['unzip'] = await _checkUnzip();
    }

    return results;
  }

  Future<void> installMissingDependencies(Map<String, bool> results) async {
    final missing = results.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();

    if (missing.isEmpty) {
      onLog('✅ All dependencies are installed!');
      return;
    }

    onLog('📦 Installing missing: ${missing.join(", ")}');

    try {
      for (final dep in missing) {
        if (dep == 'payload_dumper') {
          await _installPayloadDumper();
        } else if (Platform.isLinux) {
          await _installLinuxDependencies([dep]);
        } else if (Platform.isWindows) {
          await _installWindowsDependencies([dep]);
        } else if (Platform.isMacOS) {
          await _installMacDependencies([dep]);
        }
      }
    } catch (e) {
      onLog('⚠️  Auto-install failed: $e');
      onLog('📝 Please install manually');
    }
  }

  Future<bool> _checkPython3() async {
    try {
      final result = await Process.run('python3', ['--version']);
      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        onLog('✅ Python3: $version');
        return true;
      }
    } catch (e) {
      onLog('❌ Python3 not found');
    }
    return false;
  }

  Future<bool> _checkPip3() async {
    try {
      final result = await Process.run('pip3', ['--version']);
      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        onLog('✅ pip3: $version');
        return true;
      }
    } catch (e) {
      onLog('❌ pip3 not found');
    }
    return false;
  }

  Future<bool> _checkPayloadDumper() async {
    try {
      onLog('🔍 Checking payload_dumper...');

      final result = await Process.run(
        'payload_dumper',
        ['--version'],
        runInShell: false,
      ).timeout(const Duration(seconds: 5));

      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        onLog('✅ payload_dumper: $version');
        return true;
      }
    } catch (e) {
      onLog('❌ payload_dumper not found');
    }
    return false;
  }

  Future<bool> _checkUnzip() async {
    try {
      final result = await Process.run('which', ['unzip']);
      if (result.exitCode == 0) {
        onLog('✅ unzip: available');
        return true;
      }
    } catch (e) {
      onLog('❌ unzip not found');
    }
    return false;
  }

  Future<void> _installPayloadDumper() async {
    try {
      onLog('📥 Installing payload_dumper...');
      onLog('');

      // Detect system and architecture
      String assetName = '';

      if (Platform.isLinux) {
        final archResult = await Process.run('uname', ['-m']);
        final arch = archResult.stdout.toString().trim();

        if (arch.contains('x86_64')) {
          assetName = 'payload_dumper-linux-x86_64.zip';
        } else if (arch.contains('aarch64') || arch.contains('arm64')) {
          assetName = 'payload_dumper-linux-aarch64.zip';
        } else if (arch.contains('armv7')) {
          assetName = 'payload_dumper-linux-armv7.zip';
        } else {
          throw Exception('Unsupported Linux architecture: $arch');
        }
      } else if (Platform.isMacOS) {
        assetName = 'payload_dumper-macos-x86_64.zip';
      } else if (Platform.isWindows) {
        assetName = 'payload_dumper-windows-x86_64.zip';
      } else {
        throw Exception('Unsupported OS');
      }

      final downloadUrl = 'https://github.com/rhythmcache/payload-dumper-rust/releases/download/payload-dumper-rust-v0.7.5/$assetName';

      onLog('📦 Asset: $assetName');
      onLog('🌐 Downloading from GitHub...');
      onLog('');

      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/$assetName';
      final extractDir = '${tempDir.path}/payload_dumper_extract_${DateTime.now().millisecondsSinceEpoch}';

      // Download using wget or curl
      ProcessResult? downloadResult;

      try {
        onLog('⏳ Trying wget...');
        downloadResult = await Process.run(
          'wget',
          ['-q', '--show-progress', '-O', zipPath, downloadUrl],
          runInShell: true,
        ).timeout(const Duration(minutes: 5));

        if (downloadResult.exitCode != 0) {
          throw Exception('wget failed');
        }
      } catch (e) {
        onLog('⚠️  wget failed, trying curl...');

        downloadResult = await Process.run(
          'curl',
          ['-L', '--progress-bar', '-o', zipPath, downloadUrl],
          runInShell: true,
        ).timeout(const Duration(minutes: 5));

        if (downloadResult.exitCode != 0) {
          throw Exception('Download failed: ${downloadResult.stderr}');
        }
      }

      onLog('✓ Downloaded');

      // Verify ZIP exists
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        throw Exception('ZIP file not found after download');
      }

      final fileSize = await zipFile.length();
      if (fileSize < 10000) {
        throw Exception('ZIP too small (${fileSize}B) - likely error page');
      }

      onLog('✓ ZIP size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Extract ZIP
      onLog('⏳ Extracting ZIP...');
      await Directory(extractDir).create(recursive: true);

      final unzipResult = await Process.run(
        'unzip',
        ['-q', '-o', zipPath, '-d', extractDir],
        runInShell: true,
      );

      if (unzipResult.exitCode != 0) {
        throw Exception('Unzip failed: ${unzipResult.stderr}');
      }

      onLog('✓ Extracted');

      // Find binary in extracted files
      String? binaryPath;
      final binaryName = Platform.isWindows ? 'payload_dumper.exe' : 'payload_dumper';

      await for (final entity in Directory(extractDir).list(recursive: true)) {
        if (entity is File) {
          final name = path.basename(entity.path);
          if (name == binaryName) {
            binaryPath = entity.path;
            break;
          }
        }
      }

      if (binaryPath == null) {
        // List all files in extract dir for debugging
        onLog('⚠️  Binary not found. Contents:');
        await for (final entity in Directory(extractDir).list(recursive: true)) {
          if (entity is File) {
            onLog('  - ${path.basename(entity.path)}');
          }
        }
        throw Exception('Binary $binaryName not found in ZIP');
      }

      onLog('✓ Found binary: ${path.basename(binaryPath)}');

      // Install to ~/.local/bin (no sudo needed)
      if (Platform.isLinux || Platform.isMacOS) {
        final homeDir = Platform.environment['HOME'] ?? '';
        final localBin = '$homeDir/.local/bin';
        final installPath = '$localBin/payload_dumper';

        await Directory(localBin).create(recursive: true);
        await File(binaryPath).copy(installPath);
        await Process.run('chmod', ['+x', installPath]);

        onLog('✅ Installed to: $installPath');
        onLog('');
        onLog('💡 Add to PATH (run in terminal):');
        onLog('   echo \'export PATH="\$HOME/.local/bin:\$PATH"\' >> ~/.bashrc');
        onLog('   source ~/.bashrc');

      } else if (Platform.isWindows) {
        final appDir = await getApplicationDocumentsDirectory();
        final toolsDir = Directory('${appDir.path}/RecXiaomiFirmwareMaker/tools');
        await toolsDir.create(recursive: true);

        final installPath = '${toolsDir.path}/payload_dumper.exe';
        await File(binaryPath).copy(installPath);

        onLog('✅ Installed to: $installPath');
        onLog('💡 Add to Windows PATH: ${toolsDir.path}');
      }

      // Cleanup
      try {
        await Directory(extractDir).delete(recursive: true);
        await File(zipPath).delete();
      } catch (_) {}

      onLog('');
      onLog('✅ Installation complete!');
      onLog('⚠️  Please restart application');

    } catch (e) {
      onLog('❌ Auto-install failed: $e');
      onLog('');
      onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      onLog('💡 Manual Installation:');
      onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      onLog('');
      onLog('Terminal (Easy):');
      onLog('  bash <(curl -sSL https://raw.githubusercontent.com/rhythmcache/payload-dumper-rust/main/scripts/install.sh)');
      onLog('');
      onLog('Manual:');
      onLog('  1. Visit: https://github.com/rhythmcache/payload-dumper-rust/releases');
      onLog('  2. Download ZIP for your OS');
      onLog('  3. Extract: unzip payload_dumper-*.zip');
      onLog('  4. Install: sudo mv payload_dumper /usr/local/bin/');
      onLog('  5. Or: mv payload_dumper ~/.local/bin/');
      onLog('  6. Make executable: chmod +x ~/.local/bin/payload_dumper');
      onLog('');
      onLog('Then restart this app');
      onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      rethrow;
    }
  }

  Future<void> _installLinuxDependencies(List<String> missing) async {
    String distro = await _detectLinuxDistro();
    onLog('📱 Detected OS: $distro');

    try {
      for (final dep in missing) {
        if (dep == 'python3' || dep == 'pip3' || dep == 'unzip') {
          await _installLinuxPackage(dep, distro);
        }
      }
    } catch (e) {
      onLog('⚠️  Installation error: $e');
      _printLinuxManualInstructions(distro);
    }
  }

  Future<String> _detectLinuxDistro() async {
    try {
      final osRelease = File('/etc/os-release');
      if (await osRelease.exists()) {
        final content = await osRelease.readAsString();
        if (content.contains('ID=arch')) return 'Arch';
        if (content.contains('ID=ubuntu')) return 'Ubuntu';
        if (content.contains('ID=debian')) return 'Debian';
        if (content.contains('ID=fedora')) return 'Fedora';
        if (content.contains('ID=zorin')) return 'Zorin';
      }
    } catch (_) {}
    return 'Linux';
  }

  Future<void> _installLinuxPackage(String package, String distro) async {
    late String command;
    late List<String> args;

    onLog('📦 Installing $package on $distro...');

    switch (distro) {
      case 'Arch':
        command = 'sudo';
        args = ['pacman', '-S', '--noconfirm', _getArchPackageName(package)];
        break;
      case 'Ubuntu':
      case 'Debian':
      case 'Zorin':
        command = 'sudo';
        args = ['apt', 'install', '-y', _getDebianPackageName(package)];
        break;
      case 'Fedora':
        command = 'sudo';
        args = ['dnf', 'install', '-y', _getFedoraPackageName(package)];
        break;
      default:
        command = 'sudo';
        args = ['apt', 'install', '-y', _getDebianPackageName(package)];
    }

    try {
      final result = await Process.run(command, args, runInShell: true)
          .timeout(const Duration(minutes: 5));

      if (result.exitCode == 0) {
        onLog('✅ $package installed successfully');
      } else {
        onLog('⚠️  Installation warning');
      }
    } catch (e) {
      onLog('⚠️  Failed: $e');
    }
  }

  Future<void> _installWindowsDependencies(List<String> missing) async {
    onLog('📱 Detected OS: Windows');

    if (missing.contains('python3') || missing.contains('pip3')) {
      onLog('⚠️  Windows requires manual Python installation');
      _printWindowsManualInstructions();
    }
  }

  Future<void> _installMacDependencies(List<String> missing) async {
    onLog('📱 Detected OS: macOS');

    try {
      for (final dep in missing) {
        if (dep == 'python3' || dep == 'pip3') {
          await _installMacPackageWithBrew(dep);
        }
      }
    } catch (e) {
      onLog('⚠️  Installation error: $e');
      _printMacManualInstructions();
    }
  }

  Future<void> _installMacPackageWithBrew(String package) async {
    onLog('📦 Installing $package via Homebrew...');

    try {
      final brewCheck = await Process.run('which', ['brew']);
      if (brewCheck.exitCode != 0) {
        throw Exception('Homebrew not installed');
      }

      final result = await Process.run(
        'brew',
        ['install', package],
        runInShell: true,
      ).timeout(const Duration(minutes: 5));

      if (result.exitCode == 0) {
        onLog('✅ $package installed successfully');
      } else {
        throw Exception('Installation failed');
      }
    } catch (e) {
      onLog('⚠️  Failed to install $package: $e');
      rethrow;
    }
  }

  String _getArchPackageName(String dep) {
    switch (dep) {
      case 'python3':
        return 'python';
      case 'pip3':
        return 'python-pip';
      case 'unzip':
        return 'unzip';
      default:
        return dep;
    }
  }

  String _getDebianPackageName(String dep) {
    switch (dep) {
      case 'python3':
        return 'python3';
      case 'pip3':
        return 'python3-pip';
      case 'unzip':
        return 'unzip';
      default:
        return dep;
    }
  }

  String _getFedoraPackageName(String dep) {
    switch (dep) {
      case 'python3':
        return 'python3';
      case 'pip3':
        return 'python3-pip';
      case 'unzip':
        return 'unzip';
      default:
        return dep;
    }
  }

  void _printLinuxManualInstructions(String distro) {
    onLog('');
    onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    onLog('📝 Manual Installation for $distro:');
    onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (distro == 'Zorin' || distro == 'Ubuntu' || distro == 'Debian') {
      onLog('');
      onLog('  sudo apt update');
      onLog('  sudo apt install -y python3 python3-pip unzip');
    } else if (distro == 'Arch') {
      onLog('');
      onLog('  sudo pacman -S --noconfirm python python-pip unzip');
    } else if (distro == 'Fedora') {
      onLog('');
      onLog('  sudo dnf install -y python3 python3-pip unzip');
    }

    onLog('');
    onLog('Then restart the application.');
    onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  void _printWindowsManualInstructions() {
    onLog('');
    onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    onLog('📝 Windows Setup Instructions:');
    onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    onLog('');
    onLog('1. Download Python 3.12+:');
    onLog('   https://www.python.org/downloads/');
    onLog('');
    onLog('2. During installation, CHECK:');
    onLog('   ✓ Add Python to PATH');
    onLog('   ✓ Install pip');
    onLog('');
    onLog('3. Restart this application');
    onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  void _printMacManualInstructions() {
    onLog('');
    onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    onLog('📝 macOS Setup Instructions:');
    onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    onLog('');
    onLog('Open Terminal and run:');
    onLog('');
    onLog('  brew install python3');
    onLog('');
    onLog('Then restart this application');
    onLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
