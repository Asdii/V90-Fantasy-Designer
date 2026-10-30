plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingStore = System.getenv("MICROFANTASY_KEYSTORE")
val signingPassword = System.getenv("MICROFANTASY_STORE_PASSWORD")
val signingKeyPassword = System.getenv("MICROFANTASY_KEY_PASSWORD")
val signingAlias = System.getenv("MICROFANTASY_KEY_ALIAS")
val hasReleaseSigning = listOf(signingStore, signingPassword, signingKeyPassword, signingAlias).all { !it.isNullOrBlank() }
require(System.getenv("CI") != "true" || hasReleaseSigning) {
    "MicroFantasy CI needs its permanent signing secrets; refusing a randomly signed update."
}

android {
    namespace = "app.microfantasy.microfantasy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Keep this ID stable: changing it would create a different installation.
        applicationId = "app.microfantasy.microfantasy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("microfantasyRelease") {
                storeFile = file(signingStore!!)
                storePassword = signingPassword
                keyAlias = signingAlias
                keyPassword = signingKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Existing local APKs use this computer's development key. The setup
            // script can preserve that exact key in GitHub Actions secrets.
            signingConfig = signingConfigs.getByName(if (hasReleaseSigning) "microfantasyRelease" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
