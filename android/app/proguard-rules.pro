# --- Fix for Mapbox (Legacy) ---
# Mapbox references classes that might not exist in the specific module implementation
-dontwarn com.mapbox.**
-keep class com.mapbox.** { *; }

# --- Fix for OkHttp (Networking) ---
# OkHttp checks for these security libraries. If they aren't there, it falls back to defaults.
# R8 sees the check and panics. These rules tell R8 it's okay if they are missing.
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn okhttp3.internal.platform.**