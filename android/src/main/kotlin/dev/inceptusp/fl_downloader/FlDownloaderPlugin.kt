package dev.inceptusp.fl_downloader

import android.app.DownloadManager
import android.app.DownloadManager.Query
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Environment
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class FlDownloaderPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dev.inceptusp.fl_downloader")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "download") {
      val downloadId = download(call.argument("url"), call.argument("headers"), call.argument("fileName"))
      CoroutineScope(Dispatchers.Default).launch {
        trackProgress(downloadId)
      }
      result.success(downloadId)
    } else if (call.method == "openFile") {
      val downloadId: Int? = call.argument("downloadId")
      openFile(downloadId?.toLong())
      result.success(null)
    } else if (call.method == "cancel") {
      val downloadIds: LongArray = call.argument("downloadIds")!!
      val canceledDownloads = cancelDownload(*downloadIds)
      result.success(canceledDownloads)
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  fun download(url: String?, headers: Map<String, String>?, fileName: String?): Long {
    val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    val uri = Uri.parse(url)
    val request = DownloadManager.Request(uri)
    request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
    request.setDestinationInExternalPublicDir(
        Environment.DIRECTORY_DOWNLOADS,
        fileName ?: "/${uri.lastPathSegment}"
    )
    for (header in headers?.keys ?: emptyList()) {
      request.addRequestHeader(header, headers!![header])
    }
    return manager.enqueue(request)
  }

  fun openFile(downloadId: Long?) {
    val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    val cursor = manager.query(Query().setFilterById(downloadId!!))

    if (cursor.moveToFirst()) {
      val downloadedTo = cursor.getString(cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI))
      val authority = context.applicationContext.packageName + ".flDownloader.provider"
      val fileUri = Uri.parse(downloadedTo)
      val mimeMap = MimeTypeMap.getSingleton()
      val ext = MimeTypeMap.getFileExtensionFromUrl(fileUri.path)
      var type = mimeMap.getMimeTypeFromExtension(ext)
      if (type == null) type = "*/*"
      val uri = FileProvider.getUriForFile(context, authority, File(fileUri.path!!))

      context.startActivity(
          Intent(Intent.ACTION_VIEW)
              .setDataAndType(uri, type)
              .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
              .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      )
    }
    cursor.close()
  }

  fun cancelDownload(vararg downloadIds: Long): Int {
    val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    return manager.remove(*downloadIds)
  }

  suspend fun trackProgress(downloadId: Long?) {
    val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    var finishDownload = false
    var lastProgress = 0
    var progress: Int
    withContext(Dispatchers.Main) {
      channel.invokeMethod("notifyProgress", mapOf("downloadId" to downloadId, "progress" to 0, "status" to 2))
    }
    while (!finishDownload) {
      val cursor: Cursor = manager.query(Query().setFilterById(downloadId!!))
      if (cursor.moveToFirst()) {
        val status = cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_STATUS))
        when (status) {
          DownloadManager.STATUS_FAILED -> {
            finishDownload = true
            withContext(Dispatchers.Main) {
              channel.invokeMethod("notifyProgress", mapOf("downloadId" to downloadId, "progress" to 0, "status" to 4))
            }
          }
          DownloadManager.STATUS_PAUSED -> {
            val total =
                cursor.getLong(cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            if (total >= 0) {
              val downloaded =
                  cursor.getLong(
                      cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                  )
              progress = (downloaded * 100L / total).toInt()
              withContext(Dispatchers.Main) {
                channel.invokeMethod("notifyProgress", mapOf("downloadId" to downloadId, "progress" to progress, "status" to 3))
              }
            }
          }
          DownloadManager.STATUS_PENDING -> {
            withContext(Dispatchers.Main) {
              channel.invokeMethod("notifyProgress", mapOf("downloadId" to downloadId, "progress" to 0, "status" to 2))
            }
          }
          DownloadManager.STATUS_RUNNING -> {
            val total =
                cursor.getLong(cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            if (total >= 0) {
              val downloaded =
                  cursor.getLong(
                      cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                  )
              progress = (downloaded * 100L / total).toInt()
              if(progress != lastProgress) {
                lastProgress = progress
                withContext(Dispatchers.Main) {
                  channel.invokeMethod("notifyProgress", mapOf("downloadId" to downloadId, "progress" to progress, "status" to 1))
                }
              }
            }
          }
          DownloadManager.STATUS_SUCCESSFUL -> {
            progress = 100
            withContext(Dispatchers.Main) {
              channel.invokeMethod("notifyProgress", mapOf("downloadId" to downloadId, "progress" to progress, "status" to 0))
            }
            finishDownload = true
          }
        }
      }
      cursor.close()
    }
  }
}
