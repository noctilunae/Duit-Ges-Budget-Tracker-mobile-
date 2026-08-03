package com.noctilune.duitges

import android.net.Uri
import android.content.Context
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

object FullReceiptOcr {
    @JvmStatic
    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "duit_ges/receipt_ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "scan") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("ARGUMENT", "Path struk tidak valid", null)
                    return@setMethodCallHandler
                }
                val recognizer = TextRecognition.getClient(
                    TextRecognizerOptions.DEFAULT_OPTIONS,
                )
                val input = InputImage.fromFilePath(
                    context,
                    Uri.fromFile(File(path)),
                )
                recognizer.process(input)
                    .addOnSuccessListener { text ->
                        result.success(
                            text.textBlocks.flatMap { block ->
                                block.lines.map { line ->
                                    val box = line.boundingBox
                                    mapOf(
                                        "text" to line.text,
                                        "left" to (box?.left ?: 0),
                                        "top" to (box?.top ?: 0),
                                        "width" to (box?.width() ?: 0),
                                        "height" to (box?.height() ?: 0),
                                    )
                                }
                            },
                        )
                    }
                    .addOnFailureListener { error ->
                        result.error("OCR", error.message, null)
                    }
                    .addOnCompleteListener { recognizer.close() }
            }
    }
}
