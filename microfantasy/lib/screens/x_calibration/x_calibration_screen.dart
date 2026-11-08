import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/x_axis_calibration.dart';
import '../../widgets/x_travel_view.dart';

class XCalibrationScreen extends StatefulWidget {
  const XCalibrationScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<XCalibrationScreen> createState() => _XCalibrationScreenState();
}

class _XCalibrationScreenState extends State<XCalibrationScreen> {
  XTravelSelection? _selection;
  bool _working = false;
  String? _localError;

  bool get _busy => _working || widget.controller.xCalibrationBusy;

  bool _canRead(AppController c) =>
      c.machineConnected &&
      !c.machineConnecting &&
      c.xReferenceSupported &&
      c.sensorX != null &&
      c.sensorX!.isFinite;

  XTravelSelection _nextReference(AxisCalibration? axis) {
    if (axis == null) return XTravelSelection.center;
    if (!widget.controller.xAxisReady &&
        axis.negativeMm == null &&
        axis.positiveMm == null) {
      return XTravelSelection.center;
    }
    if (axis.negativeMm == null) return XTravelSelection.negative;
    return XTravelSelection.positive;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || widget.controller.machineConnecting) return;
    setState(() {
      _working = true;
      _localError = null;
    });
    try {
      await action();
    } catch (_) {
      // The controller normally catches errors and supplies the inline message.
      if (mounted) {
        setState(() {
          _localError = 'No se pudo confirmar: vuelve a intentarlo.';
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _captureCenter() => _run(() async {
    final c = widget.controller;
    if (c.xCalibration != null) {
      final accepted = await _confirm(
        '¿Rehacer el centro de X?',
        'El nuevo centro reemplazará la referencia y descartará los topes '
            'guardados. Lleva primero la perilla al centro físico de la mesa.',
        'Rehacer centro',
      );
      if (!mounted || widget.controller != c || !accepted) return;
    }
    if (!_canRead(c) || c.xCalibrationBusy) return;
    // Do not reset first: the controller persists and acknowledges the new frame.
    await c.captureXCenter();
    if (mounted) setState(() => _selection = null);
  });

  Future<void> _captureStop(bool positive) => _run(() async {
    final c = widget.controller;
    if (!_canRead(c) || !c.xAxisReady) return;
    if (positive) {
      await c.captureXPositive();
    } else {
      await c.captureXNegative();
    }
    if (mounted) setState(() => _selection = null);
  });

  Future<void> _restore(bool positive) => _run(() async {
    final c = widget.controller;
    if (!_canRead(c)) return;
    await c.referenceXAtStop(positive: positive);
    if (mounted) setState(() => _selection = null);
  });

  Future<void> _reset() => _run(() async {
    final c = widget.controller;
    final accepted = await _confirm(
      '¿Borrar la calibración X?',
      'Se borrarán el centro y los dos topes guardados. '
          'Después tendrás que medirlos de nuevo a mano.',
      'Borrar calibración',
    );
    if (!mounted || widget.controller != c || !accepted) return;
    await c.resetXCalibration();
    if (mounted) setState(() => _selection = null);
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final axis = c.xCalibration;
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final ready = c.xAxisReady;
      final selection = _selection ?? _nextReference(axis);
      final canCapture = !_busy && _canRead(c);
      final needsReference = axis != null && (c.xNeedsReference || !ready);
      final message = _localError ?? c.xCalibrationMessage;
      final failed = message?.startsWith('No se pudo confirmar:') ?? false;
      final count = axis == null
          ? 0
          : 1 +
                (axis.negativeMm == null ? 0 : 1) +
                (axis.positiveMm == null ? 0 : 1);

      return SingleChildScrollView(
        key: const PageStorageKey('x-calibration-scroll'),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Calibración X', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Define el centro y los topes de la mesa. '
              'Todos los movimientos se hacen a mano con la perilla.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (c.settings.simulation)
              _notice(
                context,
                'Simulación · las lecturas y capturas son de prueba.',
              ),
            if (c.machineConnecting)
              _notice(context, 'Buscando máquina… Espera una lectura reciente.')
            else if (!c.machineConnected)
              _notice(
                context,
                'Conecta la máquina con el botón superior para guardar referencias.',
              )
            else if (!c.xReferenceSupported)
              _notice(
                context,
                'Actualiza el firmware de la máquina para guardar y recuperar '
                'la referencia X. Esta versión no admite la calibración del recorrido.',
              ),
            Text(
              axis?.isComplete == true
                  ? '3 de 3 referencias guardadas · recorrido completo'
                  : '$count de 3 referencias guardadas',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 10),
            XTravelView(
              axisReady: ready,
              hasCenter: axis != null,
              negativeMm: axis?.negativeMm,
              positiveMm: axis?.positiveMm,
              // sensorX may be fresh after reboot without belonging to this frame.
              // Never display it as a centered position until the frame is ready.
              positionMm: ready ? c.sensorX : null,
              selected: selection,
              onSelected: _busy
                  ? null
                  : (value) => setState(() => _selection = value),
              formatLength: (mm) => c.length(mm, signed: true),
            ),
            const SizedBox(height: 14),
            if (needsReference) ...[
              _panel(context, 'Recupera la referencia', [
                Text(
                  axis.negativeMm == null && axis.positiveMm == null
                      ? 'Este borrador solo tiene el centro. Aún no hay un tope '
                            'guardado para recuperar la referencia. Lleva la '
                            'perilla al centro y vuelve a guardarlo.'
                      : 'Lleva la perilla suavemente hasta un tope guardado, '
                            'a mano y sin forzar. Confirma solo cuando estés allí. '
                            'La máquina no busca el centro automáticamente.',
                ),
                if (axis.negativeMm != null) ...[
                  const SizedBox(height: 12),
                  _button(
                    key: 'x-reference-negative',
                    label: 'Estoy en el tope −',
                    onPressed: canCapture ? () => _restore(false) : null,
                  ),
                ],
                if (axis.positiveMm != null) ...[
                  const SizedBox(height: 8),
                  _button(
                    key: 'x-reference-positive',
                    label: 'Estoy en el tope +',
                    onPressed: canCapture ? () => _restore(true) : null,
                  ),
                ],
              ]),
              const SizedBox(height: 14),
            ],
            _referencePanel(context, axis, selection, canCapture, ready),
            if (_busy) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: const Text('Confirmando referencia…'),
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Container(
                  key: const ValueKey('x-calibration-feedback'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: failed
                        ? colors.errorContainer
                        : colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: failed
                          ? colors.onErrorContainer
                          : colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ],
            if (axis != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                key: const ValueKey('x-reset-calibration'),
                onPressed: _busy || c.machineConnecting ? null : _reset,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Borrar calibración X'),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _referencePanel(
    BuildContext context,
    AxisCalibration? axis,
    XTravelSelection selection,
    bool canCapture,
    bool ready,
  ) {
    if (selection == XTravelSelection.center) {
      final retry =
          axis != null &&
          !ready &&
          axis.negativeMm == null &&
          axis.positiveMm == null;
      return _panel(context, '1 · Define el centro', [
        const Text(
          'Lleva la perilla al centro físico de la mesa. '
          'Cuando esté alineada, guarda esta posición como 0.',
        ),
        if (axis != null) ...[
          const SizedBox(height: 8),
          const Text('Rehacer el centro descarta los topes anteriores.'),
        ],
        const SizedBox(height: 12),
        _button(
          key: 'x-capture-center',
          label: axis == null
              ? 'Guardar centro (0)'
              : retry
              ? 'Reintentar centro'
              : 'Rehacer centro',
          onPressed: canCapture ? _captureCenter : null,
          primary: axis == null || retry,
        ),
      ]);
    }

    final positive = selection == XTravelSelection.positive;
    final value = positive ? axis?.positiveMm : axis?.negativeMm;
    final sign = positive ? '+' : '−';
    final ordered = !positive || axis?.negativeMm != null || value != null;
    return _panel(
      context,
      '${positive ? 3 : 2} · ${value == null ? 'Guarda' : 'Revisa'} el tope $sign',
      [
        Text(
          'Gira la perilla a mano hacia el lado $sign hasta llegar suavemente '
          'al tope, sin forzar. Guarda la lectura solo cuando estés allí.',
        ),
        if (value != null) ...[
          const SizedBox(height: 8),
          Text(
            'Posición guardada: ${widget.controller.length(value, signed: true)}',
          ),
        ],
        if (!ready) ...[
          const SizedBox(height: 8),
          Text(
            axis == null
                ? 'Primero guarda el centro.'
                : 'Recupera la referencia o rehace el centro antes de medir.',
          ),
        ] else if (!ordered) ...[
          const SizedBox(height: 8),
          const Text('Guarda primero el tope − para seguir la guía.'),
        ],
        const SizedBox(height: 12),
        _button(
          key: positive ? 'x-capture-positive' : 'x-capture-negative',
          label: value == null
              ? 'Guardar tope $sign'
              : 'Volver a guardar tope $sign',
          onPressed: canCapture && ready && ordered
              ? () => _captureStop(positive)
              : null,
          primary: value == null,
        ),
      ],
    );
  }

  Widget _button({
    required String key,
    required String label,
    required VoidCallback? onPressed,
    bool primary = true,
  }) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
    final child = Text(label, textAlign: TextAlign.center);
    return primary
        ? FilledButton(
            key: ValueKey(key),
            onPressed: onPressed,
            style: style,
            child: child,
          )
        : OutlinedButton(
            key: ValueKey(key),
            onPressed: onPressed,
            style: style,
            child: child,
          );
  }

  Widget _notice(BuildContext context, String message) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(message, style: Theme.of(context).textTheme.bodySmall),
  );

  Widget _panel(BuildContext context, String title, List<Widget> children) =>
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
}
