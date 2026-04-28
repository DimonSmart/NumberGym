import 'package:flutter/material.dart';

class TrainingEndButton extends StatelessWidget {
  const TrainingEndButton({
    super.key,
    required this.onPressed,
    this.expand = false,
  });

  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
      ),
      icon: const Icon(Icons.flag_outlined),
      label: const Text('End training'),
    );

    return SizedBox(
      width: expand ? double.infinity : 200,
      height: 48,
      child: button,
    );
  }
}
