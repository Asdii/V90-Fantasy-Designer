import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'app_update_service.dart';

class GithubUpdateService implements AppUpdateService {
  static const _channel = MethodChannel('app.microfantasy/updates');
  @override
  bool get supported => Platform.isAndroid;

  @override
  Future<InstalledApp> installedApp() async {
    final data = await _channel.invokeMapMethod<String, dynamic>(
      'installedApp',
    );
    if (data == null) {
      throw const FormatException('Installed version unavailable');
    }
    return InstalledApp(
      data['versionName'] as String,
      data['versionCode'] as int,
      data['applicationId'] as String,
      data['certificateSha256'] as String,
    );
  }

  @override
  Future<AppRelease?> latestRelease() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      return await _fetch(client).timeout(const Duration(seconds: 15));
    } finally {
      client.close(force: true);
    }
  }

  Future<AppRelease?> _fetch(HttpClient client) async {
    // A release asset avoids API rate limits. Redirects may only reach GitHub's
    // HTTPS asset hosts; neither user tokens nor local device data are sent.
    var uri = AppRelease.manifestUri.replace(
      queryParameters: {'check': '${DateTime.now().millisecondsSinceEpoch}'},
    );
    for (var redirects = 0; redirects < 5; redirects++) {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close();
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) throw const FormatException('Missing redirect');
        final next = uri.resolve(location);
        if (next.scheme != 'https' ||
            next.userInfo.isNotEmpty ||
            !(next.host == 'github.com' ||
                next.host == 'release-assets.githubusercontent.com' ||
                next.host == 'objects.githubusercontent.com')) {
          throw const FormatException('Unexpected update host');
        }
        uri = next;
        continue;
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw HttpException('Update check failed: ${response.statusCode}');
      }
      const limit = 32768;
      if (response.contentLength > limit) {
        throw const FormatException('Manifest too large');
      }
      final bytes = <int>[];
      await for (final part in response) {
        bytes.addAll(part);
        if (bytes.length > limit) {
          throw const FormatException('Manifest too large');
        }
      }
      return AppRelease.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    }
    throw const FormatException('Too many update redirects');
  }

  @override
  Future<void> openDownload(AppRelease release) async {
    await _channel.invokeMethod<void>('openDownload', {
      'url': release.apkUrl.toString(),
    });
  }
}
