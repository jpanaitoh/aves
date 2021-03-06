package deckers.thibault.aves

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import app.loup.streams_channel.StreamsChannel
import deckers.thibault.aves.channel.calls.*
import deckers.thibault.aves.channel.streams.*
import deckers.thibault.aves.utils.LogUtils
import deckers.thibault.aves.utils.PermissionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private val LOG_TAG = LogUtils.createTag(MainActivity::class.java)
        const val INTENT_CHANNEL = "deckers.thibault/aves/intent"
        const val VIEWER_CHANNEL = "deckers.thibault/aves/viewer"
    }

    private val intentStreamHandler = IntentStreamHandler()
    private lateinit var intentDataMap: MutableMap<String, Any?>

    override fun onCreate(savedInstanceState: Bundle?) {
        Log.i(LOG_TAG, "onCreate intent=$intent")
        super.onCreate(savedInstanceState)

        intentDataMap = extractIntentData(intent)

        val messenger = flutterEngine!!.dartExecutor.binaryMessenger

        MethodChannel(messenger, AppAdapterHandler.CHANNEL).setMethodCallHandler(AppAdapterHandler(this))
        MethodChannel(messenger, AppShortcutHandler.CHANNEL).setMethodCallHandler(AppShortcutHandler(this))
        MethodChannel(messenger, ImageFileHandler.CHANNEL).setMethodCallHandler(ImageFileHandler(this))
        MethodChannel(messenger, MetadataHandler.CHANNEL).setMethodCallHandler(MetadataHandler(this))
        MethodChannel(messenger, StorageHandler.CHANNEL).setMethodCallHandler(StorageHandler(this))

        StreamsChannel(messenger, ImageByteStreamHandler.CHANNEL).setStreamHandlerFactory { args -> ImageByteStreamHandler(this, args) }
        StreamsChannel(messenger, ImageOpStreamHandler.CHANNEL).setStreamHandlerFactory { args -> ImageOpStreamHandler(this, args) }
        StreamsChannel(messenger, MediaStoreStreamHandler.CHANNEL).setStreamHandlerFactory { args -> MediaStoreStreamHandler(this, args) }
        StreamsChannel(messenger, StorageAccessStreamHandler.CHANNEL).setStreamHandlerFactory { args -> StorageAccessStreamHandler(this, args) }

        MethodChannel(messenger, VIEWER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getIntentData" -> {
                    result.success(intentDataMap)
                    intentDataMap.clear()
                }
                "pick" -> {
                    val pickedUri = call.argument<String>("uri")
                    if (pickedUri != null) {
                        val intent = Intent().apply {
                            data = Uri.parse(pickedUri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        setResult(RESULT_OK, intent)
                    } else {
                        setResult(RESULT_CANCELED)
                    }
                    finish()
                }

            }
        }
        EventChannel(messenger, INTENT_CHANNEL).setStreamHandler(intentStreamHandler)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            setupShortcuts()
        }
    }

    @RequiresApi(Build.VERSION_CODES.N_MR1)
    private fun setupShortcuts() {
        // do not use 'route' as extra key, as the Flutter framework acts on it

        val search = ShortcutInfoCompat.Builder(this, "search")
            .setShortLabel(getString(R.string.search_shortcut_short_label))
            .setIcon(IconCompat.createWithResource(this, R.mipmap.ic_shortcut_search))
            .setIntent(
                Intent(Intent.ACTION_MAIN, null, this, MainActivity::class.java)
                    .putExtra("page", "/search")
            )
            .build()

        val videos = ShortcutInfoCompat.Builder(this, "videos")
            .setShortLabel(getString(R.string.videos_shortcut_short_label))
            .setIcon(IconCompat.createWithResource(this, R.mipmap.ic_shortcut_movie))
            .setIntent(
                Intent(Intent.ACTION_MAIN, null, this, MainActivity::class.java)
                    .putExtra("page", "/collection")
                    .putExtra("filters", arrayOf("{\"type\":\"mime\",\"mime\":\"video/*\"}"))
            )
            .build()

        ShortcutManagerCompat.setDynamicShortcuts(this, listOf(videos, search))
    }

    override fun onNewIntent(intent: Intent) {
        Log.i(LOG_TAG, "onNewIntent intent=$intent")
        super.onNewIntent(intent)
        intentStreamHandler.notifyNewIntent(extractIntentData(intent))
    }

    private fun extractIntentData(intent: Intent?): MutableMap<String, Any?> {
        when (intent?.action) {
            Intent.ACTION_MAIN -> {
                intent.getStringExtra("page")?.let { page ->
                    return hashMapOf(
                        "page" to page,
                        "filters" to intent.getStringArrayExtra("filters")?.toList(),
                    )
                }
            }
            Intent.ACTION_VIEW -> {
                intent.data?.let { uri ->
                    return hashMapOf(
                        "action" to "view",
                        "uri" to uri.toString(),
                        "mimeType" to intent.type, // MIME type is optional
                    )
                }
            }
            Intent.ACTION_GET_CONTENT, Intent.ACTION_PICK -> {
                return hashMapOf(
                    "action" to "pick",
                    "mimeType" to intent.type,
                )
            }
        }
        return HashMap()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == PermissionManager.VOLUME_ACCESS_REQUEST_CODE) {
            val treeUri = data?.data
            if (resultCode != RESULT_OK || treeUri == null) {
                PermissionManager.onPermissionResult(requestCode, null)
                return
            }

            // save access permissions across reboots
            val takeFlags = (data.flags
                    and (Intent.FLAG_GRANT_READ_URI_PERMISSION
                    or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
            contentResolver.takePersistableUriPermission(treeUri, takeFlags)

            // resume pending action
            PermissionManager.onPermissionResult(requestCode, treeUri)
        }
    }
}