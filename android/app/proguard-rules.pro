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
