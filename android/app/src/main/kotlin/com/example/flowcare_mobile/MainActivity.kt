package com.example.flowcare_mobile

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private data class PendingSave(val bytes: ByteArray, val result: MethodChannel.Result)

    private var pendingSave: PendingSave? = null
    private val saveDocumentRequest = 7801

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flowcare/result_files")
            .setMethodCallHandler { call, result ->
                if (call.method != "save") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName")
                val contentType = call.argument<String>("contentType")
                if (bytes == null || bytes.isEmpty() || fileName.isNullOrBlank() || contentType.isNullOrBlank()) {
                    result.error("INVALID_FILE", "No result file to save.", null)
                    return@setMethodCallHandler
                }
                if (pendingSave != null) {
                    result.error("SAVE_IN_PROGRESS", "A file is already being saved.", null)
                    return@setMethodCallHandler
                }
                pendingSave = PendingSave(bytes, result)
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = contentType
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    }
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, saveDocumentRequest)
                } catch (failure: Exception) {
                    pendingSave = null
                    result.error("SAVE_UNAVAILABLE", "Could not open the document picker.", null)
                }
            }
    }

    @Deprecated("Activity result forwarded by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveDocumentRequest) return
        val save = pendingSave ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pendingSave = null
            save.result.success(false)
            return
        }

        Thread {
            val saved = runCatching {
                val output = checkNotNull(contentResolver.openOutputStream(uri, "wt"))
                output.use { it.write(save.bytes) }
            }.isSuccess
            runOnUiThread {
                pendingSave = null
                if (saved) save.result.success(true)
                else save.result.error("SAVE_FAILED", "Could not write the document.", null)
            }
        }.start()
    }
}
