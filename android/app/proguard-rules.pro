# Flutter's own keep rules ship with the Gradle plugin; entries here cover
# plugins that reflect at runtime.

# flutter_secure_storage (Keychain/Keystore-backed Hive AES key)
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Firebase Messaging service entry points are looked up by name.
-keep class io.flutter.plugins.firebase.messaging.** { *; }
