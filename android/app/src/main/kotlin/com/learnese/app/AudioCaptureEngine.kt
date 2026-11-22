package com.learnese.app

import android.annotation.SuppressLint
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.os.Process
import android.os.SystemClock
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

data class SavedClipInfo(
    val filePath: String,
    val durationMs: Long,
    val sizeBytes: Long,
)

/**
 * Captures internal playback audio via AudioPlaybackCapture into an in-memory [AudioRingBuffer]
 * and asynchronously flushes snapshots to 44.1 kHz 16-bit mono .wav files.
 * Never opens or records from the device microphone.
 */
class AudioCaptureEngine(
    private val format: AudioFormatSpec = AudioFormatSpec.DEFAULT,
) {
    private val isCapturing = AtomicBoolean(false)
    private val isStopping = AtomicBoolean(false)

    private var ringBuffer: AudioRingBuffer? = null
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private var outputDirectory: File? = null
    private var saveExecutor: ExecutorService? = null
    private var bufferedUpdateCallback: ((bufferedMs: Long) -> Unit)? = null

    @SuppressLint("MissingPermission")
    fun start(
        mediaProjection: MediaProjection,
        bufferSeconds: Int,
        outputDir: File,
        onBufferedUpdate: (bufferedMs: Long) -> Unit,
        onFatalError: (errorCode: String, message: String) -> Unit,
    ) {
        val capacityBytes = format.capacityBytesForSeconds(bufferSeconds)
        val buffer = try {
            AudioRingBuffer(capacityBytes)
        } catch (oom: OutOfMemoryError) {
            throw IllegalStateException(
                "Not enough memory to allocate a ${bufferSeconds}s buffer. Try a shorter buffer length.",
                oom,
            )
        }

        // Capture internal playback audio only; microphone input is never requested.
        val captureConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()

        val channelMask = if (format.channels == 1) {
            AudioFormat.CHANNEL_IN_MONO
        } else {
            AudioFormat.CHANNEL_IN_STEREO
        }

        val audioFormat = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(format.sampleRate)
            .setChannelMask(channelMask)
            .build()

        val minBufSize = AudioRecord.getMinBufferSize(
            format.sampleRate,
            channelMask,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBufSize == AudioRecord.ERROR || minBufSize == AudioRecord.ERROR_BAD_VALUE) {
            throw IllegalStateException("Device rejected AudioRecord buffer parameters ($minBufSize).")
        }
        val recordBufferBytes = maxOf(minBufSize * 2, READ_CHUNK_BYTES * 2)

        val recorder = AudioRecord.Builder()
            .setAudioFormat(audioFormat)
            .setBufferSizeInBytes(recordBufferBytes)
            .setAudioPlaybackCaptureConfig(captureConfig)
            .build()

        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            throw IllegalStateException("AudioRecord failed to initialize for playback capture.")
        }

        ringBuffer = buffer
        audioRecord = recorder
        outputDirectory = outputDir
        bufferedUpdateCallback = onBufferedUpdate
        saveExecutor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "LearneseWavWriter").apply { isDaemon = true }
        }
        isStopping.set(false)
        isCapturing.set(true)

        recorder.startRecording()

        val thread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
            val readChunk = ByteArray(READ_CHUNK_BYTES)
            var lastEmitMs = SystemClock.elapsedRealtime()

            try {
                while (isCapturing.get()) {
                    val read = recorder.read(
                        readChunk,
                        0,
                        readChunk.size,
                        AudioRecord.READ_BLOCKING,
                    )
                    if (read > 0) {
                        buffer.write(readChunk, 0, read)
                        val now = SystemClock.elapsedRealtime()
                        if (now - lastEmitMs >= PROGRESS_EMIT_INTERVAL_MS) {
                            lastEmitMs = now
                            onBufferedUpdate(format.durationMsForBytes(buffer.bufferedBytes().toLong()))
                        }
                    } else if (read < 0 && isCapturing.get()) {
                        onFatalError(
                            "audio_init_failed",
                            "AudioRecord read failed with code $read.",
                        )
                        break
                    }
                }
            } catch (t: Throwable) {
                if (isCapturing.get()) {
                    onFatalError(
                        "unknown",
                        t.message ?: "Unexpected capture thread failure.",
                    )
                }
            }
        }, "LearneseAudioCapture").apply {
            isDaemon = true
        }
        captureThread = thread
        thread.start()
    }

    fun currentBufferedMs(): Long {
        val bytes = ringBuffer?.bufferedBytes()?.toLong() ?: 0L
        return format.durationMsForBytes(bytes)
    }

    /**
     * Snapshots the rolling buffer synchronously and writes a .wav file on the background
     * writer thread so ongoing capture never glitches.
     */
    fun saveClip(onComplete: (Result<SavedClipInfo>) -> Unit) {
        val buffer = ringBuffer
        val dir = outputDirectory
        val executor = saveExecutor

        if (!isCapturing.get() || isStopping.get() || buffer == null || dir == null || executor == null) {
            onComplete(Result.failure(IllegalStateException("No active recording session.")))
            return
        }

        val pcmSnapshot = try {
            buffer.snapshotAndClear()
        } catch (oom: OutOfMemoryError) {
            onComplete(
                Result.failure(
                    IllegalStateException(
                        "Low memory while snapshotting buffer. Try a shorter buffer length.",
                        oom,
                    ),
                ),
            )
            return
        }
        if (pcmSnapshot.isEmpty()) {
            onComplete(Result.failure(IllegalStateException("No audio buffered yet.")))
            return
        }

        // Immediately reflect the cleared buffer (0ms) so UI resets while WAV writes asynchronously.
        bufferedUpdateCallback?.invoke(0L)

        val durationMs = format.durationMsForBytes(pcmSnapshot.size.toLong())
        val saveTimestampMs = System.currentTimeMillis()

        try {
            executor.execute {
                try {
                    val targetFile = ClipFileNamer.nextFile(dir, saveTimestampMs)
                    val sizeBytes = WavWriter.writePcmToWav(pcmSnapshot, targetFile, format)
                    onComplete(
                        Result.success(
                            SavedClipInfo(
                                filePath = targetFile.absolutePath,
                                durationMs = durationMs,
                                sizeBytes = sizeBytes,
                            ),
                        ),
                    )
                } catch (t: Throwable) {
                    onComplete(Result.failure(t))
                }
            }
        } catch (e: RejectedExecutionException) {
            onComplete(Result.failure(IllegalStateException("Recording session is stopping.", e)))
        }
    }

    /**
     * Stops capture immediately, wipes unsaved RAM buffer, and waits on a background thread
     * for any already-queued .wav saves to finish flushing before invoking [onStopped].
     */
    fun stopAndFlush(onStopped: () -> Unit) {
        if (!isStopping.compareAndSet(false, true)) {
            onStopped()
            return
        }

        isCapturing.set(false)

        val recorder = audioRecord
        audioRecord = null
        if (recorder != null) {
            try {
                if (recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    recorder.stop()
                }
            } catch (_: IllegalStateException) {
                // Recorder was already stopped.
            }
            recorder.release()
        }

        val thread = captureThread
        captureThread = null
        if (thread != null && thread !== Thread.currentThread()) {
            try {
                thread.join(CAPTURE_JOIN_TIMEOUT_MS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }

        ringBuffer?.clear()
        ringBuffer = null
        bufferedUpdateCallback = null

        val executor = saveExecutor
        saveExecutor = null
        if (executor == null) {
            onStopped()
            return
        }

        executor.shutdown()
        Thread({
            try {
                executor.awaitTermination(SAVE_FLUSH_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            } finally {
                onStopped()
            }
        }, "LearneseStopFlusher").apply {
            isDaemon = true
        }.start()
    }

    companion object {
        private const val READ_CHUNK_BYTES = 4096
        private const val PROGRESS_EMIT_INTERVAL_MS = 500L
        private const val CAPTURE_JOIN_TIMEOUT_MS = 1_500L
        private const val SAVE_FLUSH_TIMEOUT_SECONDS = 10L
    }
}
