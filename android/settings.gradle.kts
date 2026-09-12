pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Pinned below AGP 9.0: AGP 9+ dropped support for plugins that apply
    // the Kotlin Gradle Plugin the old (imperative) way, which is how
    // file_picker, flutter_web_auth_2 and package_info_plus still do it as
    // of the versions this app depends on - under AGP 9 their native Kotlin
    // sources silently fail to compile ("cannot find symbol FilePickerPlugin"
    // etc). Revert to AGP 9+ once those plugins migrate to built-in Kotlin
    // (https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin).
    // Kotlin is pinned to the current Flutter SDK's floor (2.2.20) rather
    // than the newest release, since Flutter hard-fails below that - see
    // `flutter --version` / the flutter-gradle-plugin's own version check.
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
