###############################################################
# Flutter 기본 보호 규칙
###############################################################

# Flutter 엔진과 플러그인 인터페이스는 반드시 유지
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

###############################################################
# AndroidX, ViewBinding, AppCompat 등 일반 Android 라이브러리
###############################################################
-dontwarn androidx.**
-keep class androidx.** { *; }

###############################################################
# Firebase 관련 클래스 보호
###############################################################
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Firebase Crashlytics가 클래스명을 기록할 수 있도록 추가 정보 유지
-keepattributes SourceFile, LineNumberTable

###############################################################
# Gson / Retrofit / Json 파싱 관련 규칙
###############################################################
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class retrofit2.** { *; }
-dontwarn retrofit2.**

###############################################################
# Kotlin Coroutine 및 Flow 사용 시 필요
###############################################################
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

###############################################################
# Android Jetpack 및 DataBinding 관련
###############################################################
-keep class androidx.lifecycle.** { *; }
-keep class androidx.databinding.** { *; }
-keep class androidx.room.** { *; }

###############################################################
# Flutter Dynamic Delivery 관련 (Split Compatibility 등)
###############################################################
-keep class com.google.android.play.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.**

-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

###############################################################
# R8 최적화 관련
###############################################################

# 리플렉션으로 호출되는 항목 보호 (대표적으로 Activity, Service 등)
-keep class * extends android.app.Activity
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver
-keep class * extends android.content.ContentProvider

# 엔트리 포인트 (메인 액티비티 등) 누락 방지
-keep public class * extends io.flutter.embedding.android.FlutterActivity
-keep public class * extends io.flutter.embedding.android.FlutterFragmentActivity

# View-related XML 참조 보존
-keepclassmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

# Enum 사용 보존 (특정 라이브러리에서 필요)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

###############################################################
# 개발자가 직접 정의한 패키지 (예: com.yplantae.**) 보호
###############################################################
-keep class com.yplantae.** { *; }
-dontwarn com.yplantae.**

###############################################################
# FFmpeg-Kit 라이브러리 보호 (Native RegisterNatives 실패 문제 해결)
# 로그: OnLoad failed to RegisterNatives for class com/antonkarpenko/ffmpegkit/AbiDetect.
###############################################################
-keep class com.arthenica.ffmpegkit.** { *; }
-keep interface com.arthenica.ffmpegkit.** { *; }
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep interface com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**
-dontwarn com.antonkarpenko.ffmpegkit.**

###############################################################
# 기타 권장 설정
###############################################################

# 디버깅용 로그/메시지 제거 (선택)
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# 안전한 기본값
-optimizationpasses 5
-dontoptimize
-dontpreverify
