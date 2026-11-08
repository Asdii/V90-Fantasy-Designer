import 'package:flutter/material.dart';

/// A connection action independent of the controller and of X calibration.
///
/// [onReconnect] starts a real connection attempt immediately. In simulation,
/// [onUseRealMachine] is called only after the user accepts the dialog. Both
/// callbacks must complete when their attempt finishes; taps are locked meanwhile.
class MachineConnectionButton extends StatefulWidget {
  const MachineConnectionButton({
    super.key,
    required this.connected,
    required this.connecting,
    required this.simulation,
    required this.onReconnect,
    required this.onUseRealMachine,
    this.enabled = true,
    this.connectionLabel,
    this.machineAddress,
  });

  final bool connected;
  final bool connecting;
  final bool simulation;
  final bool enabled;
  final Future<void> Function() onReconnect;
  final Future<void> Function() onUseRealMachine;
  final String? connectionLabel;
  final String? machineAddress;

  @override
  State<MachineConnectionButton> createState() =>
      _MachineConnectionButtonState();
}

class _MachineConnectionButtonState extends State<MachineConnectionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _handlingTap = false;
  bool _requesting = false;
  bool _reduceMotion = false;
  String? _error;

  bool get _busy => widget.connecting || _requesting;
  bool get _enabled => widget.enabled && !_handlingTap && !_busy;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _reduceMotion = media.disableAnimations || media.accessibleNavigation;
    _updatePulse();
  }

  @override
  void didUpdateWidget(covariant MachineConnectionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connected || widget.simulation != oldWidget.simulation) {
      _error = null;
    }
    _updatePulse();
  }

  void _updatePulse() {
    final invite =
        !widget.simulation && !widget.connected && _enabled && !_reduceMotion;
    if (invite) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  Future<void> _activate() async {
    if (!_enabled) return;
    final simulation = widget.simulation;
    setState(() {
      _handlingTap = true;
      _requesting = !simulation;
      _error = null;
    });
    _updatePulse();
    try {
      if (simulation) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('Modo simulación'),
            content: const Text(
              'Estás usando lecturas de prueba. Para leer la máquina real, '
              'conecta el teléfono a la misma red Wi-Fi que la máquina '
              'y confirma el cambio de modo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Seguir simulando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Conectar máquina real'),
              ),
            ],
          ),
        );
        if (!mounted ||
            accepted != true ||
            widget.connecting ||
            !widget.enabled) {
          return;
        }
        setState(() => _requesting = true);
        await widget.onUseRealMachine();
      } else {
        await widget.onReconnect();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo conectar. Toca para reintentar.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _handlingTap = false;
          _requesting = false;
        });
        _updatePulse();
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = _busy
        ? 'Buscando…'
        : widget.simulation
        ? 'Simulación'
        : widget.connected
        ? 'Conectada'
        : _error != null
        ? 'Reintentar'
        : 'Conectar';
    final status = _busy
        ? 'Buscando máquina'
        : widget.simulation
        ? 'Modo simulación. Elegir conexión real'
        : widget.connected
        ? 'Máquina conectada. Reintentar conexión'
        : 'Máquina desconectada. Conectar ahora';
    final tooltip = [
      _error ?? status,
      if (widget.connectionLabel case final String detail) detail,
      if (!widget.simulation && widget.machineAddress != null)
        widget.machineAddress!,
    ].join('\n');

    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: _enabled,
        liveRegion: true,
        label: status,
        value: _error,
        onTap: _enabled ? _activate : null,
        excludeSemantics: true,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => TextButton(
            key: const ValueKey('machine-connection-action'),
            onPressed: _enabled ? _activate : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.padded,
              visualDensity: VisualDensity.standard,
              foregroundColor: colors.primary,
              disabledForegroundColor: colors.onSurfaceVariant,
              backgroundColor: Color.alphaBlend(
                colors.primary.withValues(alpha: .06 + .06 * _pulse.value),
                colors.surface,
              ),
              side: BorderSide(
                color: colors.primary.withValues(
                  alpha: .18 + .16 * _pulse.value,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: _reduceMotion ? .75 : null,
                    ),
                  )
                else
                  Icon(
                    widget.simulation
                        ? Icons.science_outlined
                        : widget.connected
                        ? Icons.wifi
                        : Icons.wifi_find,
                    size: 18,
                  ),
                const SizedBox(width: 7),
                Flexible(child: Text(label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
