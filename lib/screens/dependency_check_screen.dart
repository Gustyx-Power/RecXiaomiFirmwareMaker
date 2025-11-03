import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/dependency_service.dart';
import '../utils/logger.dart';

class DependencyCheckScreen extends StatefulWidget {
  final VoidCallback onDependenciesReady;

  const DependencyCheckScreen({
    super.key,
    required this.onDependenciesReady,
  });

  @override
  State<DependencyCheckScreen> createState() => _DependencyCheckScreenState();
}

class _DependencyCheckScreenState extends State<DependencyCheckScreen> {
  late DependencyService _dependencyService;
  Map<String, bool> _dependencyStatus = {};
  bool _isChecking = true;
  bool _isInstalling = false;
  List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _dependencyService = DependencyService(onLog: _addLog);
    _checkDependencies();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
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

  Future<void> _checkDependencies() async {
    try {
      _addLog('🔍 Scanning system dependencies...');
      _addLog('');

      final status = await _dependencyService.checkAllDependencies();

      setState(() {
        _dependencyStatus = status;
        _isChecking = false;
      });

      _addLog('');
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _addLog('📊 Dependency Status:');
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      for (final entry in status.entries) {
        final statusIcon = entry.value ? '✅' : '❌';
        _addLog('$statusIcon ${entry.key}');
      }

      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _addLog('');

      final missingCount = status.values.where((v) => !v).length;

      if (missingCount == 0) {
        _addLog('✨ All dependencies are ready!');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          widget.onDependenciesReady();
        }
      } else {
        _addLog('⚠️  $missingCount missing dependencies detected');
        _addLog('🔧 Click "Install Now" to auto-install or skip for manual setup');
      }
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _installDependencies() async {
    setState(() {
      _isInstalling = true;
    });

    try {
      _addLog('');
      _addLog('⏳ Starting installation...');
      _addLog('');

      await _dependencyService.installMissingDependencies(_dependencyStatus);

      _addLog('');
      _addLog('✅ Installation process completed!');
      _addLog('⏳ Retesting dependencies in 3 seconds...');

      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        _logs.clear();
        await _checkDependencies();
      }
    } catch (e) {
      _addLog('❌ Installation error: $e');
      _addLog('');
      _addLog('⚠️  Please try manual installation');
    } finally {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
      }
    }
  }

  bool _allDependenciesReady() {
    return !_dependencyStatus.values.contains(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dependency Check'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isChecking
                                ? Colors.blue.withOpacity(0.1)
                                : _allDependenciesReady()
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isChecking
                                ? Icons.hourglass_empty
                                : _allDependenciesReady()
                                ? Icons.check_circle
                                : Icons.warning,
                            size: 48,
                            color: _isChecking
                                ? Colors.blue
                                : _allDependenciesReady()
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isChecking
                              ? 'Checking Dependencies'
                              : _allDependenciesReady()
                              ? 'Ready to Use'
                              : 'Missing Dependencies',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Log Display
                  Container(
                    height: 300,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _logs[index],
                            style: GoogleFonts.robotoMono(
                              fontSize: 12,
                              color: Colors.greenAccent,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isInstalling
                        ? null
                        : () {
                      if (_allDependenciesReady()) {
                        widget.onDependenciesReady();
                      }
                    },
                    child: const Text('Skip / Continue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isInstalling || _allDependenciesReady()
                        ? null
                        : _installDependencies,
                    icon: _isInstalling
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                        : const Icon(Icons.download),
                    label: Text(
                      _isInstalling ? 'Installing...' : 'Install Now',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
