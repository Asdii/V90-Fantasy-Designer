import 'dart:async';
import 'package:flutter/material.dart';
import 'app/app_controller.dart';
import 'app/theme.dart';
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
        designer: LocalReceiverService(allowBrowserPairing: true),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onChange);
    if (!widget.controller.ready) unawaited(widget.controller.initialize());
  }

  void _onChange() {
    final c = widget.controller;
    if (c.noticeId != _lastNotice && c.notice != null) {
      _lastNotice = c.noticeId;
      final text = c.notice!;
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
    theme: microTheme(),
    scaffoldMessengerKey: _messenger,
    home: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xffe0f2fa),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.diamond_outlined,
                              color: blue,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'MicroFantasy',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
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
                                color: blue,
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
                          color: const Color(0xffe8eff4),
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
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () =>
                                          setState(() => _tab = entry.key),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                          horizontal: 2,
                                        ),
                                        child: Text(
                                          entry.value,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _tab == entry.key
                                                ? blue
                                                : ink,
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
                          color: const Color(0xffe1f3fb),
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
