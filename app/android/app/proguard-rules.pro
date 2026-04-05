# Flutter / Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# audio_service — keep the background audio handler
-keep class com.ryanheise.audioservice.** { *; }

# just_audio
-keep class com.google.android.exoplayer2.** { *; }

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# flutter_tts
-keep class com.tundralabs.fluttertts.** { *; }

# Prevent R8 from stripping interface information used by Gson/JSON serialisation
-keepattributes Signature
-keepattributes *Annotation*
