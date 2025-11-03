import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/extraction_state.dart';

class ActionButtonsCard extends StatelessWidget {
  final VoidCallback onProcess;
  final VoidCallback? onOpenFolder;
  final ExtractionState state;
  final String? outputPath;

  const ActionButtonsCard({
    super.key,
    required this.onProcess,
    this.onOpenFolder,
    this.state = ExtractionState.idle,
    this.outputPath,
  });

  @override
  Widget build(BuildContext context) {
    final isProcessing = state.isProcessing;
    final isCompleted = state == ExtractionState.completed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isCompleted && outputPath != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Firmware created successfully!',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (state == ExtractionState.error)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'An error occurred during processing',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (isCompleted && outputPath != null) const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : onProcess,
                icon: isProcessing
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                )
                    : const Icon(Icons.build, size: 20),
                label: Text(
                  isProcessing ? 'Processing...' : 'Create Firmware',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (isCompleted && outputPath != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: onOpenFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open Output Folder'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
