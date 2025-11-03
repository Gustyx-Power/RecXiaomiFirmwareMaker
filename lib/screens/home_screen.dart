import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/firmware_mode.dart';
import '../models/extraction_state.dart';
import '../services/firmware_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/file_selector_card.dart';
import '../widgets/mode_selector_card.dart';
import '../widgets/process_log_card.dart';
import '../widgets/action_buttons_card.dart';
import '../widgets/info_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedFilePath;
  FirmwareMode selectedMode = FirmwareMode.normal;
  List<String> logs = [];
  ExtractionState state = ExtractionState.idle;
  String? outputPath;

  final ScrollController _scrollController = ScrollController();

  void _addLog(String message) {
    setState(() {
      logs.add(message);
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _processRom() async {
    if (selectedFilePath == null || !File(selectedFilePath!).existsSync()) {
      _showSnackBar('Please select a valid ROM file', Colors.red);
      return;
    }

    setState(() {
      state = ExtractionState.extracting;
      logs.clear();
      outputPath = null;
    });

    try {
      final service = FirmwareService(onLog: _addLog);

      final result = await service.createFirmware(
        inputRomPath: selectedFilePath!,
        mode: selectedMode,
      ).timeout(
        AppConstants.processTimeout,
        onTimeout: () {
          throw TimeoutException('Process timeout after ${AppConstants.processTimeout.inMinutes} minutes');
        },
      );

      setState(() {
        outputPath = result;
        state = ExtractionState.completed;
      });

      _showSnackBar('Firmware created successfully!', Colors.green);

    } on TimeoutException catch (e) {
      setState(() {
        state = ExtractionState.error;
      });
      _addLog('❌ Timeout: ${e.message}');
      _showSnackBar('Process timeout: ${e.message}', Colors.orange);
    } catch (e) {
      setState(() {
        state = ExtractionState.error;
      });
      _addLog('❌ Error: $e');
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openOutputFolder() {
    if (outputPath != null) {
      final dir = Directory(outputPath!).parent.path;

      if (Platform.isLinux) {
        Process.run('xdg-open', [dir]);
      } else if (Platform.isWindows) {
        Process.run('explorer', [dir]);
      } else if (Platform.isMacOS) {
        Process.run('open', [dir]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'RecXiaomiFirmwareMaker',
        subtitle: 'v1.0',
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 800,
          ),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Banner
                InfoBanner(
                  title: 'Supported Devices',
                  message: 'Xiaomi legacy to modern with Payload.bin support',
                  icon: Icons.info,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  borderColor: Colors.blue,
                ),
                const SizedBox(height: 20),

                // File Selector
                FileSelectorCard(
                  onFileSelected: (path) {
                    setState(() {
                      selectedFilePath = path;
                    });
                  },
                  isEnabled: !state.isProcessing,
                ),
                const SizedBox(height: 20),

                // Mode Selector
                ModeSelectorCard(
                  onModeSelected: (mode) {
                    setState(() {
                      selectedMode = mode;
                    });
                  },
                  isEnabled: !state.isProcessing,
                ),
                const SizedBox(height: 20),

                // Process Log
                ProcessLogCard(
                  logs: logs,
                  scrollController: _scrollController,
                  isProcessing: state.isProcessing,
                ),
                const SizedBox(height: 20),

                // Action Buttons
                ActionButtonsCard(
                  onProcess: _processRom,
                  onOpenFolder: outputPath != null ? _openOutputFolder : null,
                  state: state,
                  outputPath: outputPath,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
