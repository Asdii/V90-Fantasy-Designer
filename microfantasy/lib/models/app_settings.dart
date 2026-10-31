import 'validation.dart';

enum LengthUnit {
  mm,
  cm;

  /// Display units never change stored job/calibration coordinates in mm.
  double fromMillimetres(double value) {
    finiteNumber(value, 'length');
    return this == LengthUnit.cm ? value / 10 : value;
  }

  double toMillimetres(double value) {
    finiteNumber(value, 'length');
    return finiteNumber(this == LengthUnit.cm ? value * 10 : value, 'length');
  }
}

enum SmoothingLevel { off, light, medium }

enum AppearanceTheme { atelier, lagoon, porcelain, amethyst }

/// Immutable settings; validation also runs outside debug builds.
class AppSettings {
  factory AppSettings({
    bool simulation = true,
    String host = 'fantasy-machine.local',
    int port = 81,
    int timeoutSeconds = 5,
    LengthUnit units = LengthUnit.mm,
    bool invertX = false,
    double tolerance = 0.05,
    SmoothingLevel smoothing = SmoothingLevel.off,
    int angleInterval = 30,
    String? activeProfileId,
    bool haptics = true,
    bool autoAdvance = false,
    AppearanceTheme appearance = AppearanceTheme.atelier,
  }) {
    nonEmptyString(host, 'host');
    final Uri? hostUri = Uri.tryParse('http://$host');
    if (RegExp(r'[\s/?#@]').hasMatch(host) ||
        hostUri == null ||
        hostUri.host.isEmpty ||
        hostUri.hasPort ||
        hostUri.path.isNotEmpty ||
        hostUri.userInfo.isNotEmpty) {
      throw const FormatException(
        'host must be a hostname or IP, without a URL or port.',
      );
    }
    integer(port, 'port', min: 1, max: 65535);
    integer(timeoutSeconds, 'timeoutSeconds', min: 1, max: 86400);
    nonNegativeNumber(tolerance, 'tolerance');
    integer(angleInterval, 'angleInterval', min: 1, max: 360);
    if (activeProfileId != null) {
      nonEmptyString(activeProfileId, 'activeProfileId');
    }
    return AppSettings._(
      simulation: simulation,
      host: host,
      port: port,
      timeoutSeconds: timeoutSeconds,
      units: units,
      invertX: invertX,
      tolerance: tolerance,
      smoothing: smoothing,
      angleInterval: angleInterval,
      activeProfileId: activeProfileId,
      haptics: haptics,
      autoAdvance: autoAdvance,
      appearance: appearance,
    );
  }

  const AppSettings._({
    required this.simulation,
    required this.host,
    required this.port,
    required this.timeoutSeconds,
    required this.units,
    required this.invertX,
    required this.tolerance,
    required this.smoothing,
    required this.angleInterval,
    required this.activeProfileId,
    required this.haptics,
    required this.autoAdvance,
    required this.appearance,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      simulation: boolean(
        valueOrDefault(json, 'simulation', true),
        'simulation',
      ),
      host: nonEmptyString(
        valueOrDefault(json, 'host', 'fantasy-machine.local'),
        'host',
      ),
      port: integer(valueOrDefault(json, 'port', 81), 'port'),
      timeoutSeconds: integer(
        valueOrDefault(json, 'timeoutSeconds', 5),
        'timeoutSeconds',
      ),
      units: enumValue(
        valueOrDefault(json, 'units', 'mm'),
        LengthUnit.values,
        'units',
      ),
      invertX: boolean(valueOrDefault(json, 'invertX', false), 'invertX'),
      tolerance: finiteNumber(
        valueOrDefault(json, 'tolerance', 0.05),
        'tolerance',
      ),
      smoothing: enumValue(
        valueOrDefault(json, 'smoothing', 'off'),
        SmoothingLevel.values,
        'smoothing',
      ),
      angleInterval: integer(
        valueOrDefault(json, 'angleInterval', 30),
        'angleInterval',
      ),
      activeProfileId: json['activeProfileId'] == null
          ? null
          : nonEmptyString(json['activeProfileId'], 'activeProfileId'),
      haptics: boolean(valueOrDefault(json, 'haptics', true), 'haptics'),
      autoAdvance: boolean(
        valueOrDefault(json, 'autoAdvance', false),
        'autoAdvance',
      ),
      appearance: enumValue(
        valueOrDefault(json, 'appearance', 'atelier'),
        AppearanceTheme.values,
        'appearance',
      ),
    );
  }

  final bool simulation;
  final String host;
  final int port;
  final int timeoutSeconds;
  final LengthUnit units;
  final bool invertX;

  /// Arrival tolerance in millimetres, independent of display [units].
  final double tolerance;
  final SmoothingLevel smoothing;
  final int angleInterval;
  final String? activeProfileId;
  final bool haptics;
  final bool autoAdvance;
  final AppearanceTheme appearance;

  Duration get timeout => Duration(seconds: timeoutSeconds);

  AppSettings copyWith({
    bool? simulation,
    String? host,
    int? port,
    int? timeoutSeconds,
    LengthUnit? units,
    bool? invertX,
    double? tolerance,
    SmoothingLevel? smoothing,
    int? angleInterval,
    String? activeProfileId,
    bool clearActiveProfileId = false,
    bool? haptics,
    bool? autoAdvance,
    AppearanceTheme? appearance,
  }) {
    return AppSettings(
      simulation: simulation ?? this.simulation,
      host: host ?? this.host,
      port: port ?? this.port,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      units: units ?? this.units,
      invertX: invertX ?? this.invertX,
      tolerance: tolerance ?? this.tolerance,
      smoothing: smoothing ?? this.smoothing,
      angleInterval: angleInterval ?? this.angleInterval,
      activeProfileId: clearActiveProfileId
          ? null
          : activeProfileId ?? this.activeProfileId,
      haptics: haptics ?? this.haptics,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      appearance: appearance ?? this.appearance,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'simulation': simulation,
    'host': host,
    'port': port,
    'timeoutSeconds': timeoutSeconds,
    'units': units.name,
    'invertX': invertX,
    'tolerance': tolerance,
    'smoothing': smoothing.name,
    'angleInterval': angleInterval,
    'activeProfileId': activeProfileId,
    'haptics': haptics,
    'autoAdvance': autoAdvance,
    'appearance': appearance.name,
  };
}
