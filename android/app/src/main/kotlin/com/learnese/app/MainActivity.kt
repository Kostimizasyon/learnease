package com.learnese.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null

    private var pendingStartResult: MethodChannel.Result? = null
    private var pendingBufferSeconds: Int = 30
    private var pendingOutputDir: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(NotificationFactory.EXTRA_OPEN_ACTIVE_SESSION, false) == true) {
            RecordingSessionBus.markOpenActiveSession()
            intent.removeExtra(NotificationFactory.EXTRA_OPEN_ACTIVE_SESSION)
            methodChannel?.invokeMethod("onOpenActiveSession", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(::onMethodCall)
        }

        eventChannel = EventChannel(messenger, EVENT_CHANNEL).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    RecordingSessionBus.attachSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    RecordingSessionBus.attachSink(null)
                }
            })
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        RecordingSessionBus.attachSink(null)
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startSession" -> handleStartSessionCall(call, result)
            "saveClip" -> handleSaveClipCall(result)
            "stopSession" -> handleStopSessionCall(result)
            "getState" -> result.success(RecordingSessionBus.latestState())
            "consumeOpenActiveSession" -> result.success(
                RecordingSessionBus.consumeOpenActiveSession(),
            )
            "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
            "openOverlayPermissionSettings" -> handleOpenOverlaySettings(result)
            else -> result.notImplemented()
        }
    }

    private fun handleOpenOverlaySettings(result: MethodChannel.Result) {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName"),
        )
        try {
            startActivity(intent)
            result.success(true)
        } catch (_: Throwable) {
            result.success(false)
        }
    }

    private fun handleStartSessionCall(call: MethodCall, result: MethodChannel.Result) {
        val bufferSeconds = call.argument<Int>("bufferSeconds")
        if (bufferSeconds == null ||
            bufferSeconds !in AudioFormatSpec.MIN_BUFFER_SECONDS..AudioFormatSpec.MAX_BUFFER_SECONDS
        ) {
            result.error(
                "invalid_arguments",
                "bufferSeconds must be between ${AudioFormatSpec.MIN_BUFFER_SECONDS} and ${AudioFormatSpec.MAX_BUFFER_SECONDS}.",
                null,
            )
            return
        }

        val hasAudioPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasAudioPermission) {
            result.error(
                "permission_denied",
                "RECORD_AUDIO permission is required for AudioPlaybackCapture.",
                null,
            )
            return
        }

        if (!Settings.canDrawOverlays(this)) {
            result.error(
                "overlay_permission_denied",
                "Display over other apps permission is required for the floating save button.",
                null,
            )
            return
        }

        if (RecordingService.activeInstance != null) {
            result.error(
                "session_already_active",
                "A recording session is already running.",
                null,
            )
            return
        }

        if (pendingStartResult != null) {
            result.error(
                "consent_in_progress",
                "Media projection consent request is already in progress.",
                null,
            )
            return
        }

        val projectionManager = getSystemService(MediaProjectionManager::class.java)
        if (projectionManager == null) {
            result.error(
                "projection_unavailable",
                "MediaProjectionManager is unavailable on this device.",
                null,
            )
            return
        }

        // Android 14+ requires fresh MediaProjection consent for every new session.
        pendingStartResult = result
        pendingBufferSeconds = bufferSeconds
        pendingOutputDir = call.argument<String>("outputDir")

        @Suppress("DEPRECATION")
        startActivityForResult(
            projectionManager.createScreenCaptureIntent(),
            REQUEST_CODE_MEDIA_PROJECTION,
        )
    }

    @Deprecated("Required for FlutterActivity (non-ComponentActivity) projection consent flow.")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_CODE_MEDIA_PROJECTION) return

        val resultCallback = pendingStartResult ?: return
        pendingStartResult = null
        val bufferSeconds = pendingBufferSeconds
        val outputDir = pendingOutputDir
        pendingOutputDir = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            RecordingSessionBus.publish(
                RecordingSessionBus.idlePayload(
                    error = "projection_denied",
                    errorMessage = "Screen capture consent was cancelled or denied.",
                ),
            )
            resultCallback.success(false)
            return
        }

        val serviceIntent = Intent(this, RecordingService::class.java).apply {
            action = RecordingService.ACTION_START_SESSION
            putExtra(RecordingService.EXTRA_RESULT_CODE, resultCode)
            putExtra(RecordingService.EXTRA_RESULT_DATA, data)
            putExtra(RecordingService.EXTRA_BUFFER_SECONDS, bufferSeconds)
            if (!outputDir.isNullOrBlank()) {
                putExtra(RecordingService.EXTRA_OUTPUT_DIR, outputDir)
            }
        }
        ContextCompat.startForegroundService(this, serviceIntent)
        resultCallback.success(true)
    }

    private fun handleSaveClipCall(result: MethodChannel.Result) {
        val service = RecordingService.activeInstance
        if (service == null) {
            result.error("no_active_session", "No active recording session.", null)
            return
        }
        service.saveClip { saveResult ->
            saveResult.onSuccess { info ->
                result.success(
                    mapOf(
                        "filePath" to info.filePath,
                        "durationMs" to info.durationMs,
                        "sizeBytes" to info.sizeBytes,
                    ),
                )
            }.onFailure { err ->
                val code = if (err is InsufficientStorageException) {
                    "storage_error"
                } else {
                    "encoding_failed"
                }
                result.error(code, err.message ?: "Failed to save clip.", null)
            }
        }
    }

    private fun handleStopSessionCall(result: MethodChannel.Result) {
        val service = RecordingService.activeInstance
        if (service == null) {
            RecordingSessionBus.publish(RecordingSessionBus.idlePayload())
            result.success(true)
            return
        }
        service.stopSession {
            result.success(true)
        }
    }

    companion object {
        const val METHOD_CHANNEL = "com.learnese.app/recorder"
        const val EVENT_CHANNEL = "com.learnese.app/recorder_events"
        private const val REQUEST_CODE_MEDIA_PROJECTION = 1001
    }
}
