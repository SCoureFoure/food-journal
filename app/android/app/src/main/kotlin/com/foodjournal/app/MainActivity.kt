package com.foodjournal.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "food_journal/watch_folder"
        private const val REQUEST_PICK_FOLDER = 4711
    }

    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFolder" -> pickFolder(result)
                    "stat" -> stat(call, result)
                    "copy" -> copy(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "A folder pick is already pending", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            putExtra(
                DocumentsContract.EXTRA_INITIAL_URI,
                DocumentsContract.buildDocumentUri(
                    "com.android.externalstorage.documents",
                    "primary:Documents/Gadgetbridge"
                )
            )
        }
        pendingPick = result
        startActivityForResult(intent, REQUEST_PICK_FOLDER)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PICK_FOLDER) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val id = DocumentsContract.getTreeDocumentId(uri)
        val label = if (id.startsWith("primary:")) {
            "Internal storage/" + id.removePrefix("primary:")
        } else {
            id
        }
        result.success(mapOf("uri" to uri.toString(), "label" to label))
    }

    /** Document id of the child called [name] under the tree, with its metadata, or null. */
    private fun findChild(treeUri: Uri, name: String): Triple<String, Long, Long>? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri)
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_SIZE
        )
        contentResolver.query(childrenUri, projection, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                if (c.getString(1) == name) {
                    return Triple(c.getString(0), c.getLong(2), c.getLong(3))
                }
            }
        }
        return null
    }

    private fun stat(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = Uri.parse(call.argument<String>("uri"))
        val name = call.argument<String>("name") ?: ""
        try {
            val found = findChild(treeUri, name)
            if (found == null) {
                result.success(null)
            } else {
                result.success(mapOf("lastModified" to found.second, "size" to found.third))
            }
        } catch (e: SecurityException) {
            result.error("no_access", e.message, null)
        }
    }

    private fun copy(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = Uri.parse(call.argument<String>("uri"))
        val name = call.argument<String>("name") ?: ""
        Thread {
            try {
                val found = findChild(treeUri, name)
                if (found == null) {
                    runOnUiThread { result.success(null) }
                    return@Thread
                }
                val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, found.first)
                val out = File(cacheDir, "gadgetbridge_sync.db")
                val input = contentResolver.openInputStream(docUri)
                if (input == null) {
                    runOnUiThread { result.success(null) }
                    return@Thread
                }
                input.use { i -> out.outputStream().use { o -> i.copyTo(o) } }
                runOnUiThread { result.success(out.absolutePath) }
            } catch (e: SecurityException) {
                runOnUiThread { result.error("no_access", e.message, null) }
            } catch (e: Exception) {
                runOnUiThread { result.error("copy_failed", e.message, null) }
            }
        }.start()
    }
}
