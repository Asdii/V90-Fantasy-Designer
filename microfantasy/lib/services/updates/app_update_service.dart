/// Update transport is independent of the cutting session and widgets.
abstract interface class AppUpdateService {
  bool get supported;
  Future<InstalledApp> installedApp();
  Future<AppRelease?> latestRelease();
  Future<void> openDownload(AppRelease release);
}

class InstalledApp {
  const InstalledApp(
    this.versionName,
    this.versionCode,
    this.applicationId,
    this.certificateSha256,
  );
  final String versionName, applicationId, certificateSha256;
  final int versionCode;
}

class AppRelease {
  const AppRelease({
    required this.versionName,
    required this.versionCode,
    required this.applicationId,
    required this.apkUrl,
    required this.certificateSha256,
    required this.sha256,
    required this.notes,
  });
  static const repository = 'Asdii/V90-Fantasy-Designer';
  static final manifestUri = Uri.parse(
    'https://github.com/$repository/releases/latest/download/microfantasy-update.json',
  );
  final String versionName, applicationId, certificateSha256, sha256, notes;
  final int versionCode;
  final Uri apkUrl;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final version = json['versionName'], code = json['versionCode'];
    final url = Uri.tryParse(json['apkUrl'] is String ? json['apkUrl'] : '');
    final certificate = json['certificateSha256'], hash = json['sha256'];
    final notes = json['notes'] ?? '';
    if (json['schemaVersion'] != 1 ||
        version is! String ||
        version.isEmpty ||
        version.length > 80 ||
        code is! int ||
        code <= 0 ||
        code > 2100000000 ||
        json['applicationId'] != 'app.microfantasy.microfantasy' ||
        url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        url.hasPort ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        !RegExp(
          r'^/Asdii/V90-Fantasy-Designer/releases/download/microfantasy-b[0-9]+/microfantasy\.apk$',
        ).hasMatch(url.path) ||
        certificate is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(certificate) ||
        hash is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash) ||
        notes is! String ||
        notes.length > 2000) {
      throw const FormatException('Invalid MicroFantasy release manifest');
    }
    return AppRelease(
      versionName: version,
      versionCode: code,
      applicationId: json['applicationId'],
      apkUrl: url,
      certificateSha256: certificate.toLowerCase(),
      sha256: hash.toLowerCase(),
      notes: notes,
    );
  }

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'versionName': versionName,
    'versionCode': versionCode,
    'applicationId': applicationId,
    'apkUrl': apkUrl.toString(),
    'certificateSha256': certificateSha256,
    'sha256': sha256,
    'notes': notes,
  };
}

class UnsupportedUpdateService implements AppUpdateService {
  const UnsupportedUpdateService();
  @override
  bool get supported => false;
  @override
  Future<InstalledApp> installedApp() =>
      Future.error(UnsupportedError('Android only'));
  @override
  Future<AppRelease?> latestRelease() async => null;
  @override
  Future<void> openDownload(AppRelease release) =>
      Future.error(UnsupportedError('Android only'));
}
