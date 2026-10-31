import 'dart:async';
import 'package:flutter/material.dart';
import 'app/app_controller.dart';
import 'app/theme.dart';
import 'models/app_settings.dart';
import 'widgets/microfantasy_mark.dart';
import 'repositories/shared_preferences_store.dart';
import 'screens/cut/cut_screen.dart';
import 'screens/calibration/calibration_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'services/fantasy_designer/local_receiver_service.dart';
import 'services/updates/github_update_service.dart';
import 'widgets/app_updates.dart';

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(widget.controller.foreground(state == AppLifecycleState.resumed));
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.controller.flush());
      unawaited(widget.controller.updates.flush());
    } else if (widget.controller.ready) {
      unawaited(widget.controller.updates.check());
    }
  }

  @override
  void dispose() {
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
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    if (!landscape)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          18,
                          compact ? 4 : 10,
                          18,
                          compact ? 4 : 8,
                        ),
                        child: Row(
                          children: [
                            MicroFantasyMark(size: compact ? 32 : 40),
                            const SizedBox(width: 12),
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
                            if (c.ready)
                              Tooltip(
                                message: c.connectionLabel,
                                child: Icon(
                                  c.settings.simulation
                                      ? Icons.science_outlined
                                      : c.actualX != null
                                      ? Icons.wifi
                                      : Icons.wifi_off,
                                  size: 21,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            for (final entry in [
                              'Corte',
                              'Calibración',
                              'Configuración',
                            ].asMap().entries)
                              Expanded(
                                child: Semantics(
                                  selected: _tab == entry.key,
                                  button: true,
                                  child: Material(
                                    color: _tab == entry.key
                                        ? Theme.of(context).colorScheme.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () =>
                                          setState(() => _tab = entry.key),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 2,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            entry.value,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _tab == entry.key
                                                  ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
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
                      ),
                    ),
                    if (c.ready) AppUpdateBanner(controller: c.updates),
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
                              1 => CalibrationScreen(controller: c),
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
