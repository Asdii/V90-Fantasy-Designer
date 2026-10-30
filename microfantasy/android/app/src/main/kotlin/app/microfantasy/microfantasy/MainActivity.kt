package app.microfantasy.microfantasy

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.microfantasy/network")
            .setMethodCallHandler { call, result ->
                if (call.method == "openWifiSettings") {
                    try {
                        startActivity(Intent(android.provider.Settings.ACTION_WIFI_SETTINGS))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("wifi_settings_unavailable", error.message, null)
                    }
                } else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.microfantasy/updates")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "installedApp" -> result.success(installedApp())
                        "openDownload" -> {
                            val uri = Uri.parse(call.argument<String>("url") ?: "")
                            val path = uri.path ?: ""
                            require(uri.scheme == "https" && uri.host == "github.com" &&
                                uri.port == -1 && uri.userInfo == null && uri.query == null && uri.fragment == null &&
                                Regex("^/Asdii/V90-Fantasy-Designer/releases/download/microfantasy-b[0-9]+/microfantasy\\.apk$").matches(path))
                            // The user's browser downloads the APK. Android's installer
                            // handles confirmation and verifies the signing certificate.
                            startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("update_unavailable", error.message, null)
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun installedApp(): Map<String, Any> {
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val info = packageManager.getPackageInfo(packageName, flags)
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        val certificate = requireNotNull(signatures?.singleOrNull()) { "Expected a single app signer" }
        val fingerprint = MessageDigest.getInstance("SHA-256").digest(certificate.toByteArray())
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
        return mapOf(
            "versionName" to (info.versionName ?: ""),
            "versionCode" to (if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()),
            "applicationId" to packageName,
            "certificateSha256" to fingerprint,
        )
    }
}
