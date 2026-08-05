package com.noctilune.duitges

import android.net.Uri
import android.view.WindowManager
import androidx.annotation.OptIn
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AppActivity : FlutterActivity() {
    private var transformer: Transformer? = null

    @OptIn(UnstableApi::class)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "duit_ges/privacy")
            .setMethodCallHandler { call, result ->
                if (call.method != "setSecure") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val enabled = call.argument<Boolean>("enabled") == true
                if (enabled) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "duit_ges/video_compressor")
            .setMethodCallHandler { call, result ->
                if (call.method == "cancel") {
                    transformer?.cancel()
                    transformer = null
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method != "compress" || transformer != null) {
                    result.error("BUSY", "Kompresi lain sedang berjalan", null)
                    return@setMethodCallHandler
                }
                val input = call.argument<String>("input")
                val output = call.argument<String>("output")
                val height = call.argument<Int>("height") ?: 720
                if (input == null || output == null) {
                    result.error("ARGUMENT", "Path video tidak valid", null)
                    return@setMethodCallHandler
                }
                File(output).delete()
                val edited = EditedMediaItem.Builder(
                    MediaItem.fromUri(Uri.fromFile(File(input))),
                )
                    .setRemoveAudio(true)
                    .setEffects(
                        Effects(
                            emptyList(),
                            listOf<Effect>(Presentation.createForHeight(height)),
                        ),
                    )
                    .build()
                transformer = Transformer.Builder(this)
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .addListener(
                        object : Transformer.Listener {
                            override fun onCompleted(
                                composition: androidx.media3.transformer.Composition,
                                exportResult: ExportResult,
                            ) {
                                transformer = null
                                result.success(output)
                            }

                            override fun onError(
                                composition: androidx.media3.transformer.Composition,
                                exportResult: ExportResult,
                                exportException: ExportException,
                            ) {
                                transformer = null
                                File(output).delete()
                                result.error(
                                    "COMPRESS",
                                    exportException.message,
                                    null,
                                )
                            }
                        },
                    )
                    .build()
                transformer!!.start(edited, output)
            }
    }
}
