# ==========================================
# REGRAS DO ML KIT (Evitar crash no R8)
# ==========================================
# Ignorar classes de idiomas que não estamos usando no ML Kit
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**

# Manter as classes do ML Kit que são necessárias
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }

# ==========================================
# REGRAS DO uCROP / OKHTTP (Evitar crash no R8)
# ==========================================
-dontwarn com.yalantis.ucrop.**
-keep class com.yalantis.ucrop.** { *; }

-dontwarn okhttp3.**
-keep class okhttp3.** { *; }

-dontwarn okio.**
-keep class okio.** { *; }