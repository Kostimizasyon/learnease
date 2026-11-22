import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data_models/recording_session.dart';

class BufferLengthChip extends StatelessWidget {
  const BufferLengthChip.preset({
    super.key,
    required int seconds,
    required this.selected,
    required this.onSelected,
  }) : label = '${seconds}s',
       _isCustom = false;

  const BufferLengthChip.custom({
    super.key,
    int? activeCustomSeconds,
    required this.selected,
    required this.onSelected,
  }) : label = activeCustomSeconds != null
           ? 'Custom (${activeCustomSeconds}s)'
           : 'Custom',
       _isCustom = true;

  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final bool _isCustom;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      avatar: _isCustom
          ? Icon(
              Icons.tune_rounded,
              size: 16,
              color: selected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            )
          : null,
      selected: selected,
      onSelected: onSelected == null ? null : (_) => onSelected!(),
      selectedColor: colorScheme.primaryContainer,
      backgroundColor: colorScheme.surfaceContainer,
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outlineVariant,
      ),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}

/// Lets the user choose the fixed rolling buffer length X (1–180 seconds) before a session.
class BufferLengthPicker extends StatelessWidget {
  const BufferLengthPicker({
    super.key,
    required this.selectedSeconds,
    required this.onChanged,
    this.enabled = true,
  });

  final int selectedSeconds;
  final ValueChanged<int> onChanged;
  final bool enabled;

  bool get _isPreset =>
      RecordingSession.presetBufferSeconds.contains(selectedSeconds);

  Future<void> _showCustomDialog(BuildContext context) async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (BuildContext _) =>
          _CustomBufferDialog(initialSeconds: selectedSeconds),
    );
    if (chosen != null) {
      onChanged(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final approxMb = (selectedSeconds * 88200 / (1024 * 1024)).toStringAsFixed(
      1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Replay Window',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '~$approxMb MB RAM',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final preset in RecordingSession.presetBufferSeconds)
              BufferLengthChip.preset(
                seconds: preset,
                selected: selectedSeconds == preset,
                onSelected: enabled ? () => onChanged(preset) : null,
              ),
            BufferLengthChip.custom(
              activeCustomSeconds: _isPreset ? null : selectedSeconds,
              selected: !_isPreset,
              onSelected: enabled ? () => _showCustomDialog(context) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _CustomBufferDialog extends StatefulWidget {
  const _CustomBufferDialog({required this.initialSeconds});

  final int initialSeconds;

  @override
  State<_CustomBufferDialog> createState() => _CustomBufferDialogState();
}

class _CustomBufferDialogState extends State<_CustomBufferDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialSeconds.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null ||
        parsed < RecordingSession.minBufferSeconds ||
        parsed > RecordingSession.maxBufferSeconds) {
      setState(() {
        _errorText =
            'Enter a number between ${RecordingSession.minBufferSeconds} and ${RecordingSession.maxBufferSeconds} seconds.';
      });
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.tune_rounded,
          color: colors.onPrimaryContainer,
          size: 26,
        ),
      ),
      title: const Text('Custom Buffer Length', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Keep the last X seconds in memory (max ${RecordingSession.maxBufferSeconds}s).',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: 'Seconds',
              suffixText: 's',
              errorText: _errorText,
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      actions: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: _submit, child: const Text('Set')),
            ),
          ],
        ),
      ],
    );
  }
}
