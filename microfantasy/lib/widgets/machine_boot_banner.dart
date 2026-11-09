import 'package:flutter/material.dart';

class MachineBootBanner extends StatelessWidget {
  const MachineBootBanner({
    super.key,
    required this.hasCalibration,
    required this.onCalibrate,
    required this.onDismiss,
  });
  final bool hasCalibration;
  final VoidCallback onCalibrate, onDismiss;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('machine-boot-notice'),
        margin: const EdgeInsets.fromLTRB(10, 6, 10, 2),
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          border: Border(left: BorderSide(color: colors.primary, width: 3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'La máquina se encendió o reinició',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontSize: 12.5,
                          height: 1.2,
                        ),
                      ),
                      if (constraints.maxWidth >= 480)
                        Text(
                          hasCalibration
                              ? 'Confirma un tope para recuperar X.'
                              : 'Define el centro del eje X.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: onCalibrate,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(80, 48),
                  textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 12),
                ),
                child: const Text('Calibrar X'),
              ),
              IconButton(
                onPressed: onDismiss,
                tooltip: 'Cerrar aviso de reinicio',
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
