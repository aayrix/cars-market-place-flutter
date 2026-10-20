# Flutter and its plugin registrants are reached through generated/reflection
# entry points. Preserve their public bridge classes when shrinking release.
-keep class io.flutter.** { *; }
-keep class io.agora.** { *; }
-keep class io.supabase.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
