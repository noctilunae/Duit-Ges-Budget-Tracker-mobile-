# ML Kit Text Recognition: kita cuma bundel model Latin.
# Plugin-nya refer ke recognizer aksara lain (China/Jepang/Korea/
# Devanagari) yang sengaja ga dibundel biar APK ga bengkak +16MB —
# suruh R8 santai aja soal class-class itu (jalurnya ga pernah kepanggil).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# JANGAN biarin R8 nyopot/ngerename class ML Kit + pipeline internalnya —
# banyak yang dipanggil lewat reflection/JNI, jadi R8 ngira ga kepake
# padahal kepake. Tanpa ini OCR jalan di debug tapi mati di release.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.odml.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.vision.** { *; }
