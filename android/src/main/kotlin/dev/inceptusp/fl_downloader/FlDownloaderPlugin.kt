package dev.inceptusp.fl_downloader

import android.Manifest.permission.READ_EXTERNAL_STORAGE
import android.Manifest.permission.WRITE_EXTERNAL_STORAGE
import android.app.Activity
import android.app.DownloadManager
import android.app.DownloadManager.Query
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Build.VERSION.SDK_INT
import android.os.Environment
import android.os.SystemClock
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.database.getIntOrNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import kotlinx.coroutines.*
import java.io.File

class FlDownloaderPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, RequestPermissionsResultListener {
  private lateinit var channel: MethodChannel
  private lateinit var activityBindings: ActivityPluginBinding
  private lateinit var context: Context
  private lateinit var activity: Activity
  private val permissionRequestCode = 353696

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "dev.inceptusp.fl_downloader")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBindings = binding
    binding.addRequestPermissionsResultListener(this)
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {}

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
        "checkStoragePermission" -> {
          val permissionStatus = checkPermissionStatus()
          result.success(permissionStatus)
        }
        "requestStoragePermission" -> {
          requestPermission()
          result.success(null)
        }
        "download" -> {
          val downloadId = download(call.argument("url"), call.argument("headers"), call.argument("fileName"))
          CoroutineScope(Dispatchers.Default).launch {
            trackProgress(downloadId)
          }
          result.success(downloadId)
        }
        "attachDownloadTracker" -> {
          val downloadId : Long = call.argument("downloadId")!!
          CoroutineScope(Dispatchers.Default).launch {
            trackProgress(downloadId)
          }
        }
        "openFile" -> {
          val downloadId: Int? = call.argument("downloadId")
          val filePath: String? = call.argument("filePath")
          openFile(downloadId?.toLong(), filePath)
          result.success(null)
        }
        "cancel" -> {
          val downloadIds: LongArray = call.argument("downloadIds")!!
          val canceledDownloads = cancelDownload(*downloadIds)
          result.success(canceledDownloads)
        }
        else -> {
          result.notImplemented()
        }
    }
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    when (requestCode) {
      permissionRequestCode -> if (grantResults.isNotEmpty()) {
        val writePermissionStorage = grantResults[0] == PackageManager.PERMISSION_GRANTED
        val readExternalStorage = grantResults[1] == PackageManager.PERMISSION_GRANTED
        if (readExternalStorage && writePermissionStorage) {
          channel.invokeMethod("onRequestPermissionResult", true)
        } else {
          channel.invokeMethod("onRequestPermissionResult", false)
        }
      }
    }
    return true
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onDetachedFromActivity() {
    activityBindings.removeRequestPermissionsResultListener(this)
  }

  private fun checkPermissionStatus(): Boolean {
    val permissionStatus: Boolean = if (SDK_INT >= Build.VERSION_CODES.R) {
      true
    } else {
      val resultRead = ContextCompat.checkSelfPermission(context, READ_EXTERNAL_STORAGE)
      val resultWrite = ContextCompat.checkSelfPermission(context, WRITE_EXTERNAL_STORAGE)
      resultRead == PackageManager.PERMISSION_GRANTED && resultWrite == PackageManager.PERMISSION_GRANTED
    }
    return permissionStatus
  }

  private fun requestPermission() {
    ActivityCompat.requestPermissions(
      activity,
      arrayOf(WRITE_EXTERNAL_STORAGE, READ_EXTERNAL_STORAGE),
      permissionRequestCode
    )
  }

  private fun download(url: String?, headers: Map<String, String>?, fileName: String?): Long {
    val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    val uri = Uri.parse(url)
    val request = DownloadManager.Request(uri)
    request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
    request.setDestinationInExternalPublicDir(
        Environment.DIRECTORY_DOWNLOADS,
        fileName ?: uri.lastPathSegment?.replace(
          Regex("[#%&{}\\\\<>*?/\$!'\":@+`|=]"), "-"
        ) ?: "unknown"
    )
    for (header in headers?.keys ?: emptyList()) {
      request.addRequestHeader(header, headers!![header])
    }
    return manager.enqueue(request)
  }

  private fun openFile(downloadId: Long?, filePath: String?) {
    val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    var downloadedTo : String? = filePath

    if(filePath == null) {
      val cursor = manager.query(Query().setFilterById(downloadId!!))
      if (cursor.moveToFirst()) {
        downloadedTo = cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
      }
      cursor.close()
    }

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

  private fun cancelDownload(vararg downloadIds: Long): Int {
    val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    return manager.remove(*downloadIds)
  }

  private suspend fun trackProgress(downloadId: Long?) {
    val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    var finishDownload = false
    var lastProgress = -1
    var progress = 0
    withContext(Dispatchers.Main) {
      channel.invokeMethod("notifyProgress", mapOf("downloadId" to downloadId, "progress" to progress, "status" to 2))
    }
    val timerCoroutine = CoroutineScope(Dispatchers.Default).launch {
      SystemClock.sleep(15000)
      if (isActive) {
        finishDownload = true
        withContext(Dispatchers.Main) {
          channel.invokeMethod(
            "notifyProgress",
            mapOf("downloadId" to downloadId, "progress" to 0, "status" to 4)
          )
        }
        manager.remove(downloadId!!)
      }
    }
    while (!finishDownload) {
      val cursor: Cursor = manager.query(Query().setFilterById(downloadId!!))
      if (cursor.moveToFirst()) {
        when (cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))) {
          DownloadManager.STATUS_FAILED -> {
            finishDownload = true
            if (timerCoroutine.isActive) timerCoroutine.cancel()
            val reason = cursor.getIntOrNull(cursor.getColumnIndex(DownloadManager.COLUMN_REASON))
            val convertedReason = convertReasonString(reason)
            Log.d("fl_downloader", "$convertedReason")
            withContext(Dispatchers.Main) {
              channel.invokeMethod("notifyProgress",
                      mapOf("downloadId" to downloadId,
                              "progress" to 0,
                              "status" to 4,
                              "reason" to convertedReason)
              )
            }
          }
          DownloadManager.STATUS_PAUSED -> {
            finishDownload = true
            if (timerCoroutine.isActive) timerCoroutine.cancel()
            val reason = cursor.getIntOrNull(cursor.getColumnIndex(DownloadManager.COLUMN_REASON))
            val convertedReason = convertReasonString(reason)
            Log.d("fl_downloader", "$convertedReason")
            val total =
                    cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            if (total >= 0) {
              val downloaded =
                      cursor.getLong(
                              cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                      )
              progress = (downloaded * 100L / total).toInt()
              withContext(Dispatchers.Main) {
                channel.invokeMethod("notifyProgress",
                        mapOf("downloadId" to downloadId,
                                "progress" to progress,
                                "status" to 3,
                                "reason" to convertedReason)
                )
              }
            } else {
              withContext(Dispatchers.Main) {
                channel.invokeMethod("notifyProgress",
                        mapOf("downloadId" to downloadId,
                                "progress" to progress,
                                "status" to 3,
                                "reason" to convertedReason)
                )
              }
            }
          }
          DownloadManager.STATUS_PENDING -> {
            withContext(Dispatchers.Main) {
              channel.invokeMethod("notifyProgress", mapOf("downloadId" to downloadId, "progress" to 0, "status" to 2))
            }
            SystemClock.sleep(250)
          }
          DownloadManager.STATUS_RUNNING -> {
            val total =
                    cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            if (total >= 0) {
              if (timerCoroutine.isActive) timerCoroutine.cancel()
              val downloaded =
                      cursor.getLong(
                              cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                      )
              if (total != 0L) {
                progress = (downloaded * 100L / total).toInt()
              }
              if (progress != lastProgress) {
                lastProgress = progress
                withContext(Dispatchers.Main) {
                  channel.invokeMethod("notifyProgress", mapOf("downloadId" to downloadId, "progress" to progress, "status" to 1))
                }
              }
            }
          }
          DownloadManager.STATUS_SUCCESSFUL -> {
            val filePath = cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
            progress = 100
            finishDownload = true
            if (timerCoroutine.isActive) timerCoroutine.cancel()
            withContext(Dispatchers.Main) {
              channel.invokeMethod("notifyProgress", mapOf("downloadId" to downloadId, "progress" to progress, "status" to 0, "filePath" to filePath))
            }
          }
        }
      }
      cursor.close()
    }
    return
  }

  private fun convertReasonString(reason: Int?) :String? {
    return when (reason) {
      DownloadManager.ERROR_CANNOT_RESUME -> "ANDROID_ERROR(0x000003f0): Some, possibly, transient error occurred but we can't resume the download."
      DownloadManager.ERROR_DEVICE_NOT_FOUND -> "ANDROID_ERROR(0x000003ef): No external storage device was found."
      DownloadManager.ERROR_FILE_ALREADY_EXISTS -> "ANDROID_ERROR(0x000003f1): The requested destination file already exists."
      DownloadManager.ERROR_FILE_ERROR -> "ANDROID_ERROR(0x000003e9): A storage issue arises which doesn't fit under any other error code."
      DownloadManager.ERROR_HTTP_DATA_ERROR -> "ANDROID_ERROR(0x000003ec): An error receiving or processing data occurred at the HTTP level"
      DownloadManager.ERROR_INSUFFICIENT_SPACE -> "ANDROID_ERROR(0x000003ee): There was insufficient storage space."
      DownloadManager.ERROR_TOO_MANY_REDIRECTS -> "ANDROID_ERROR(0x000003ed): There were too many redirects."
      DownloadManager.ERROR_UNHANDLED_HTTP_CODE -> "ANDROID_ERROR(0x000003ea): An HTTP code was received that download manager can't handle."
      DownloadManager.ERROR_UNKNOWN -> "ANDROID_ERROR(0x000003e8): When the download has completed with an error that doesn't fit under any other error code."
      DownloadManager.PAUSED_QUEUED_FOR_WIFI -> "ANDROID(0x00000003): The download exceeds a size limit for downloads over the mobile network and the download manager is waiting for a Wi-Fi connection to proceed."
      DownloadManager.PAUSED_UNKNOWN -> "ANDROID(0x00000004): The download is paused for some other reason."
      DownloadManager.PAUSED_WAITING_FOR_NETWORK -> "ANDROID(0x00000002): The download is waiting for network connectivity to proceed."
      DownloadManager.PAUSED_WAITING_TO_RETRY -> "ANDROID(0x00000001): The download is paused because some network error occurred and the download manager is waiting before retrying the request."
      null -> null
      else -> "HTTP_ERROR($reason)"
    }
  }
}
