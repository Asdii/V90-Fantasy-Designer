import 'dart:async';
import 'package:flutter/material.dart';
import 'app/app_controller.dart';
import 'app/theme.dart';
import 'models/app_settings.dart';
import 'widgets/microfantasy_mark.dart';
import 'repositories/shared_preferences_store.dart';
import 'screens/cut/cut_screen.dart';
import 'screens/calibration/calibration_screen.dart';
import 'screens/x_calibration/x_calibration_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'services/fantasy_designer/local_receiver_service.dart';
import 'services/updates/github_update_service.dart';
import 'widgets/app_updates.dart';
import 'widgets/machine_connection_indicator.dart';
import 'widgets/machine_boot_banner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MicroFantasyApp(
      controller: AppController(
        store: SharedPreferencesStore(),
        designer: LocalReceiverService(allowBrowserAccess: true),
        updateService: GithubUpdateService(),
      ),
    ),
  );
}

class MicroFantasyApp extends StatefulWidget {
  const MicroFantasyApp({super.key, required this.controller});
  final AppController controller;
  @override
  State<MicroFantasyApp> createState() => _MicroFantasyAppState();
}

class _MicroFantasyAppState extends State<MicroFantasyApp>
    with WidgetsBindingObserver {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  int _tab = 0;
  int _lastNotice = 0;
  AppearanceTheme? _appearance;
  Timer? _backgroundTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onChange);
    if (!widget.controller.ready) unawaited(widget.controller.initialize());
  }

  void _onChange() {
    final c = widget.controller;
    if (_appearance != c.settings.appearance) {
      setState(() => _appearance = c.settings.appearance);
    }
    if (c.noticeId != _lastNotice && c.notice != null) {
      _lastNotice = c.noticeId;
      final text = c.notice!;
      // X capture feedback belongs next to its controls, never over the ruler.
      if (_tab == 1 || _tab == 2) return;
      // The incoming-job card already announces the design and offers actions.
      // Do not also cover the cutting controls with a duplicate toast.
      if (c.pendingJob != null && text.startsWith('Nuevo patrón recibido')) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _messenger.currentState?.hideCurrentSnackBar();
        _messenger.currentState?.showSnackBar(
          SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
        );
      });
    }
  }

  void _selectTab(int tab) {
    if (tab == 1 || tab == 2) _messenger.currentState?.hideCurrentSnackBar();
    setState(() => _tab = tab);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A notification shade, permission dialog or focus change can make the app
    // inactive while it is still visible. Keep the measurement socket alive.
    // Brief background transitions also keep their connection; a real pause
    // releases networking after a grace period, then rediscovers on return.
    switch (state) {
      case AppLifecycleState.resumed:
        _backgroundTimer?.cancel();
        _backgroundTimer = null;
        unawaited(widget.controller.foreground(true));
      case AppLifecycleState.inactive:
        _backgroundTimer?.cancel();
        _backgroundTimer = null;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _backgroundTimer ??= Timer(const Duration(seconds: 3), () {
          _backgroundTimer = null;
          if (mounted) unawaited(widget.controller.foreground(false));
        });
      case AppLifecycleState.detached:
        _backgroundTimer?.cancel();
        _backgroundTimer = null;
        unawaited(widget.controller.foreground(false));
    }
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.controller.flush());
      unawaited(widget.controller.updates.flush());
    } else if (widget.controller.ready) {
      unawaited(widget.controller.updates.check());
    }
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onChange);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MicroFantasy',
    debugShowCheckedModeBanner: false,
    theme: microTheme(widget.controller.settings.appearance),
    scaffoldMessengerKey: _messenger,
    home: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final compact = MediaQuery.sizeOf(context).height < 740;
        final landscape = MediaQuery.sizeOf(context).aspectRatio > 1.4;
        final tabs = _AppTabs(selected: _tab, onSelected: _selectTab);
        final connection = c.ready
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: MachineConnectionIndicator(
                  connected: c.machineConnected,
                  simulation: c.settings.simulation,
                  connectionLabel: c.connectionLabel,
                  machineAddress: c.machineAddress,
                ),
              )
            : const SizedBox(width: 48, height: 48);
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    if (landscape)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
                        child: Row(
                          children: [
                            Expanded(child: tabs),
                            const SizedBox(width: 8),
                            connection,
                          ],
                        ),
                      )
                    else ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          compact ? 4 : 10,
                          14,
                          compact ? 4 : 8,
                        ),
                        child: Row(
                          children: [
                            MicroFantasyMark(size: compact ? 28 : 40),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MicroFantasy',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -.6,
                                        ),
                                  ),
                                  if (!compact)
                                    Text(
                                      'Guía de corte manual',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            connection,
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: tabs,
                      ),
                    ],
                    if (c.ready) AppUpdateBanner(controller: c.updates),
                    if (c.ready && c.pendingBootNotice != null)
                      MachineBootBanner(
                        hasCalibration: c.xCalibration != null,
                        onCalibrate: () {
                          _selectTab(1);
                          unawaited(c.dismissBootNotice());
                        },
                        onDismiss: () => unawaited(c.dismissBootNotice()),
                      ),
                    if (c.ready && c.pendingJob != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nuevo patrón recibido desde V90 Fantasy Designer',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${c.pendingJob!.name} · ${c.pendingJob!.steps.length} pasos',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    c.acceptPending();
                                    setState(() => _tab = 0);
                                  },
                                  child: const Text('Abrir'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    c.acceptPending(replace: true);
                                    setState(() => _tab = 0);
                                  },
                                  child: const Text(
                                    'Reemplazar trabajo actual',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: !c.ready
                          ? const Center(child: CircularProgressIndicator())
                          : switch (_tab) {
                              0 => CutScreen(controller: c),
                              1 => XCalibrationScreen(controller: c),
                              2 => CalibrationScreen(controller: c),
                              _ => SettingsScreen(controller: c),
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _AppTabs extends StatelessWidget {
  const _AppTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _labels = [
    'Corte',
    'Calibración X',
    'Calibración R',
    'Configuración',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const style = TextStyle(
      fontSize: 13,
      height: 1.15,
      fontWeight: FontWeight.w600,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth / 4 - 4;
            bool fits(String label) {
              final painter = TextPainter(
                text: TextSpan(
                  text: label,
                  style: DefaultTextStyle.of(context).style.merge(style),
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final fits = painter.width <= available;
              painter.dispose();
              return fits;
            }

            String label(int index) {
              if (fits(_labels[index])) return _labels[index];
              if (index == 3) return 'Configu-\nración';
              if (index == 1 || index == 2) {
                final axis = index == 1 ? 'X' : 'R';
                return fits('Calibración')
                    ? 'Calibración\n$axis'
                    : 'Calibra-\nción $axis';
              }
              return _labels[index];
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected == i,
                        label: _labels[i],
                        excludeSemantics: true,
                        onTap: () => onSelected(i),
                        child: Material(
                          color: selected == i
                              ? colors.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            key: ValueKey('app-tab-$i'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onSelected(i),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 6,
                                ),
                                child: Center(
                                  child: Text(
                                    label(i),
                                    textAlign: TextAlign.center,
                                    style: style.copyWith(
                                      color: selected == i
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
