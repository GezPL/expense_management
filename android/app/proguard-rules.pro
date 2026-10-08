# Suppress warnings for optional language packages in ML Kit Text Recognition
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google_mlkit_text_recognition.**
-dontwarn com.google_mlkit_barcode_scanning.**

# Keep ML Kit core, text recognition and barcode scanning classes
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
