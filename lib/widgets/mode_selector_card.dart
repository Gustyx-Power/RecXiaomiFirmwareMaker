import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/firmware_mode.dart';

class ModeSelectorCard extends StatefulWidget {
  final Function(FirmwareMode) onModeSelected;
  final bool isEnabled;

  const ModeSelectorCard({
    super.key,
    required this.onModeSelected,
    this.isEnabled = true,
  });

  @override
  State<ModeSelectorCard> createState() => _ModeSelectorCardState();
}

class _ModeSelectorCardState extends State<ModeSelectorCard> {
  FirmwareMode selectedMode = FirmwareMode.normal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.tune,
                    size: 24,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Extraction Mode',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...FirmwareMode.values.map((mode) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ModeRadioTile(
                mode: mode,
                isSelected: selectedMode == mode,
                isEnabled: widget.isEnabled,
                onChanged: widget.isEnabled
                    ? (value) {
                  if (value != null) {
                    setState(() {
                      selectedMode = value;
                    });
                    widget.onModeSelected(value);
                  }
                }
                    : null,
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _ModeRadioTile extends StatelessWidget {
  final FirmwareMode mode;
  final bool isSelected;
  final bool isEnabled;
  final Function(FirmwareMode?)? onChanged;

  const _ModeRadioTile({
    required this.mode,
    required this.isSelected,
    required this.isEnabled,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        enabled: isEnabled,
        leading: Radio<FirmwareMode>(
          value: mode,
          groupValue: isSelected ? mode : null,
          onChanged: onChanged,
        ),
        title: Text(
          mode.label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          mode.description,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(mode.icon, size: 20),
      ),
    );
  }
}
