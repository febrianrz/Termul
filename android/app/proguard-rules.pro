# Flutter's own engine/embedding and plugin registration classes are
# referenced directly by generated code, but keeping them explicitly is a
# safety net against R8 stripping something it thinks is unused.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google ML Kit barcode scanning (used by mobile_scanner for QR import).
# It's loaded dynamically by Play Services, so keep its public API even
# though nothing in our own code appears to reference it directly.
-keep class com.google.mlkit.vision.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }

# Android Keystore-backed crypto (used by flutter_secure_storage).
-keep class androidx.security.crypto.** { *; }

# Flutter's engine has optional support for Google Play "deferred
# components" (dynamic feature delivery), which references
# com.google.android.play:core classes. This app doesn't depend on that
# library and doesn't use deferred components, so those classes are
# genuinely absent from the build - without this, R8 hard-fails with
# "missing classes" instead of just warning about an unused code path.
-dontwarn com.google.android.play.core.**
