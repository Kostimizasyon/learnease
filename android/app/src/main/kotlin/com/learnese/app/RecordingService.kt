package com.learnese.app

import android.app.Activity
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.ServiceCompat
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * In-process state bus bridging [RecordingService] and [MainActivity]'s EventChannel.
 */
object RecordingSessionBus {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val latestStateRef = AtomicReference<Map<String, Any?>>(idlePayload())
    private val openActiveSessionPending = AtomicBoolean(false)

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    fun attachSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink != null) {
            val current = latestStateRef.get()
            mainHandler.post { eventSink?.success(current) }
        }
    }

    fun publish(payload: Map<String, Any?>) {
        // Store state without transient one-shot clip/error fields only when overwritten later.
        latestStateRef.set(payload)
        mainHandler.post { eventSink?.success(payload) }
    }

    fun latestState(): Map<String, Any?> = latestStateRef.get()

    fun markOpenActiveSession() {
        openActiveSessionPending.set(true)
    }

    fun consumeOpenActiveSession(): Boolean = openActiveSessionPending.getAndSet(false)

    fun idlePayload(
        error: String = "none",
        errorMessage: String? = null,
    ): Map<String, Any?> = buildMap {
        put("sessionState", "idle")
        put("bufferedMs", 0L)
        put("bufferSeconds", 0)
        put("error", error)
        if (errorMessage != null) put("errorMessage", errorMessage)
    }

    fun activePayload(
        bufferedMs: Long,
        bufferSeconds: Int,
        lastSavedClip: SavedClipInfo? = null,
        error: String = "none",
        errorMessage: String? = null,
    ): Map<String, Any?> = buildMap {
        put("sessionState", "active")
        put("bufferedMs", bufferedMs)
        put("bufferSeconds", bufferSeconds)
        if (lastSavedClip != null) {
            put("lastSavedClipPath", lastSavedClip.filePath)
            put("lastSavedClipDurationMs", lastSavedClip.durationMs)
            put("lastSavedClipSizeBytes", lastSavedClip.sizeBytes)
        }
        put("error", error)
        if (errorMessage != null) put("errorMessage", errorMessage)
    }
}

/**
 * Foreground service owning the [MediaProjection], [AudioCaptureEngine], notification,
 * and (in Chunk 4) the floating overlay button.
 */
class RecordingService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val stopping = AtomicBoolean(false)

    private var mediaProjection: MediaProjection? = null
    private var projectionCallback: MediaProjection.Callback? = null
    private var captureEngine: AudioCaptureEngine? = null
    private var bufferSeconds: Int = 30
    private var savedClipCount: Int = 0
    private var isSessionActive: Boolean = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_SESSION -> handleStartSession(intent)
            ACTION_SAVE_CLIP -> saveClip(onComplete = null)
            ACTION_STOP_SESSION -> stopSessionInternal()
            else -> {
                if (!isSessionActive) {
                    stopSelf()
                }
            }
        }
        return START_NOT_STICKY
    }

    private fun handleStartSession(intent: Intent) {
        if (isSessionActive) return

        val requestedSeconds = intent.getIntExtra(EXTRA_BUFFER_SECONDS, 30)
        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
        val resultData = extractResultData(intent)
        val outputDirPath = intent.getStringExtra(EXTRA_OUTPUT_DIR)

        if (resultCode != Activity.RESULT_OK || resultData == null) {
            RecordingSessionBus.publish(
                RecordingSessionBus.idlePayload(
                    error = "projection_denied",
                    errorMessage = "Media projection consent was missing or denied.",
                ),
            )
            stopSelf()
            return
        }

        if (requestedSeconds !in AudioFormatSpec.MIN_BUFFER_SECONDS..AudioFormatSpec.MAX_BUFFER_SECONDS) {
            RecordingSessionBus.publish(
                RecordingSessionBus.idlePayload(
                    error = "unknown",
                    errorMessage = "Invalid buffer length: $requestedSeconds",
                ),
            )
            stopSelf()
            return
        }

        bufferSeconds = requestedSeconds
        savedClipCount = 0
        stopping.set(false)

        // Android 14+ requires startForeground(MEDIA_PROJECTION) BEFORE getMediaProjection().
        NotificationFactory.ensureChannel(this)
        val notification = NotificationFactory.buildRecordingNotification(
            context = this,
            bufferSeconds = bufferSeconds,
            savedClipCount = savedClipCount,
        )
        ServiceCompat.startForeground(
            this,
            NotificationFactory.NOTIFICATION_ID,
            notification,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
        )

        val projectionManager = getSystemService(MediaProjectionManager::class.java)
        val projection = try {
            projectionManager?.getMediaProjection(resultCode, resultData)
        } catch (t: Throwable) {
            failStartup("projection_denied", t.message ?: "Failed to obtain MediaProjection.")
            return
        }

        if (projection == null) {
            failStartup("projection_denied", "MediaProjectionManager returned null.")
            return
        }

        val callback = object : MediaProjection.Callback() {
            override fun onStop() {
                if (!stopping.get()) {
                    stopSessionInternal(
                        error = "projection_revoked",
                        errorMessage = "Screen capture permission was revoked.",
                    )
                }
            }
        }
        // Android 14+ requires registering a MediaProjection.Callback before starting capture.
        projection.registerCallback(callback, mainHandler)
        mediaProjection = projection
        projectionCallback = callback

        val outputDir = if (!outputDirPath.isNullOrBlank()) {
            File(outputDirPath)
        } else {
            File(filesDir, "clips")
        }

        val engine = AudioCaptureEngine()
        try {
            engine.start(
                mediaProjection = projection,
                bufferSeconds = bufferSeconds,
                outputDir = outputDir,
                onBufferedUpdate = { bufferedMs ->
                    if (isSessionActive && !stopping.get()) {
                        RecordingSessionBus.publish(
                            RecordingSessionBus.activePayload(
                                bufferedMs = bufferedMs,
                                bufferSeconds = bufferSeconds,
                            ),
                        )
                    }
                },
                onFatalError = { errorCode, message ->
                    stopSessionInternal(error = errorCode, errorMessage = message)
                },
            )
        } catch (t: Throwable) {
            failStartup("audio_init_failed", t.message ?: "Failed to start audio playback capture.")
            return
        }

        captureEngine = engine
        isSessionActive = true
        activeInstance = this

        // TODO(chunk-4): Attach OverlayController here when session starts and detach on stop.

        RecordingSessionBus.publish(
            RecordingSessionBus.activePayload(
                bufferedMs = 0L,
                bufferSeconds = bufferSeconds,
            ),
        )
    }

    private fun failStartup(errorCode: String, message: String) {
        releaseProjection()
        isSessionActive = false
        if (activeInstance === this) activeInstance = null
        RecordingSessionBus.publish(
            RecordingSessionBus.idlePayload(error = errorCode, errorMessage = message),
        )
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    fun saveClip(onComplete: ((Result<SavedClipInfo>) -> Unit)?) {
        val engine = captureEngine
        if (!isSessionActive || stopping.get() || engine == null) {
            mainHandler.post {
                onComplete?.invoke(Result.failure(IllegalStateException("No active recording session.")))
            }
            return
        }

        engine.saveClip { result ->
            mainHandler.post {
                result.onSuccess { info ->
                    savedClipCount += 1
                    updateNotification()
                    RecordingSessionBus.publish(
                        RecordingSessionBus.activePayload(
                            bufferedMs = engine.currentBufferedMs(),
                            bufferSeconds = bufferSeconds,
                            lastSavedClip = info,
                        ),
                    )
                }.onFailure { err ->
                    RecordingSessionBus.publish(
                        RecordingSessionBus.activePayload(
                            bufferedMs = engine.currentBufferedMs(),
                            bufferSeconds = bufferSeconds,
                            error = "encoding_failed",
                            errorMessage = err.message ?: "Failed to write WAV clip.",
                        ),
                    )
                }
                onComplete?.invoke(result)
            }
        }
    }

    fun stopSession(onComplete: (() -> Unit)? = null) {
        stopSessionInternal(onComplete = onComplete)
    }

    private fun stopSessionInternal(
        error: String = "none",
        errorMessage: String? = null,
        onComplete: (() -> Unit)? = null,
    ) {
        if (!stopping.compareAndSet(false, true)) {
            mainHandler.post { onComplete?.invoke() }
            return
        }

        isSessionActive = false
        val engine = captureEngine
        captureEngine = null

        val finalizeStop: () -> Unit = {
            mainHandler.post {
                releaseProjection()
                if (activeInstance === this) {
                    activeInstance = null
                }
                RecordingSessionBus.publish(
                    RecordingSessionBus.idlePayload(
                        error = error,
                        errorMessage = errorMessage,
                    ),
                )
                ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
                stopSelf()
                onComplete?.invoke()
            }
        }

        if (engine != null) {
            engine.stopAndFlush(finalizeStop)
        } else {
            finalizeStop()
        }
    }

    private fun updateNotification() {
        if (!isSessionActive || stopping.get()) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val notification = NotificationFactory.buildRecordingNotification(
            context = this,
            bufferSeconds = bufferSeconds,
            savedClipCount = savedClipCount,
        )
        manager.notify(NotificationFactory.NOTIFICATION_ID, notification)
    }

    private fun releaseProjection() {
        val projection = mediaProjection
        val callback = projectionCallback
        mediaProjection = null
        projectionCallback = null

        if (projection != null) {
            if (callback != null) {
                try {
                    projection.unregisterCallback(callback)
                } catch (_: IllegalArgumentException) {
                    // Already unregistered.
                }
            }
            try {
                projection.stop()
            } catch (_: Throwable) {
                // Projection already stopped by OS.
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun extractResultData(intent: Intent): Intent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        } else {
            intent.getParcelableExtra(EXTRA_RESULT_DATA)
        }
    }

    override fun onDestroy() {
        if (!stopping.get()) {
            stopSessionInternal()
        }
        super.onDestroy()
    }

    companion object {
        const val ACTION_START_SESSION = "com.learnese.app.action.START_SESSION"
        const val ACTION_SAVE_CLIP = "com.learnese.app.action.SAVE_CLIP"
        const val ACTION_STOP_SESSION = "com.learnese.app.action.STOP_SESSION"

        const val EXTRA_RESULT_CODE = "extra_result_code"
        const val EXTRA_RESULT_DATA = "extra_result_data"
        const val EXTRA_BUFFER_SECONDS = "extra_buffer_seconds"
        const val EXTRA_OUTPUT_DIR = "extra_output_dir"

        @Volatile
        var activeInstance: RecordingService? = null
            private set
    }
}
