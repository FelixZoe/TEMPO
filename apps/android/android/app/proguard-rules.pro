# TEMPO Android release rules

# Flutter core
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Keep MainActivity and MethodChannel handlers (required for native channels)
-keep class one.darker.qingxu.MainActivity { *; }
-keep class one.darker.qingxu.BsPatch { *; }

# Apache Commons Compress (used by BsPatch)
-keep class org.apache.commons.compress.** { *; }
-dontwarn org.apache.commons.compress.**

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Kotlin
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontnote kotlin.**

# Android
-keep class androidx.** { *; }
-dontwarn androidx.**

# JSON parsing
-keep class org.json.** { *; }

# ContentProvider (Android file system)
-keep class android.content.ContentProviderClient { *; }

# ═══ Enhanced Obfuscation — Anti-reverse engineering ═══

# Aggressively obfuscate all non-essential classes
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# Obfuscate string constants in Dart-to-native bridge
# (MethodChannel names are kept in Flutter Dart code, not native side)

# Remove debug info
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
}

# Obfuscate class names aggressively for non-kept classes
-repackageclasses ''
-flattenpackagehierarchy ''

# Local notifications plugin
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Crypto
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# File provider
-keep class androidx.core.content.FileProvider { *; }
