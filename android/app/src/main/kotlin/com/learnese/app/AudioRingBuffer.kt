package com.learnese.app

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/**
 * Pure JVM audio format constants and math for Learnese's rolling PCM buffer and WAV output.
 */
data class AudioFormatSpec(
    val sampleRate: Int = 44_100,
    val channels: Int = 1,
    val bitsPerSample: Int = 16,
) {
    init {
        require(sampleRate > 0) { "sampleRate must be positive" }
        require(channels in 1..2) { "channels must be 1 or 2" }
        require(bitsPerSample == 16) { "Only 16-bit PCM is supported" }
    }

    val bytesPerSample: Int = bitsPerSample / 8
    val blockAlign: Int = channels * bytesPerSample
    val bytesPerSecond: Int = sampleRate * blockAlign

    fun capacityBytesForSeconds(seconds: Int): Int {
        require(seconds in MIN_BUFFER_SECONDS..MAX_BUFFER_SECONDS) {
            "bufferSeconds must be in $MIN_BUFFER_SECONDS..$MAX_BUFFER_SECONDS, got $seconds"
        }
        return bytesPerSecond * seconds
    }

    fun durationMsForBytes(byteCount: Long): Long {
        if (byteCount <= 0L) return 0L
        return (byteCount * 1_000L) / bytesPerSecond
    }

    companion object {
        const val MIN_BUFFER_SECONDS = 1
        const val MAX_BUFFER_SECONDS = 180
        val DEFAULT = AudioFormatSpec()
    }
}

/**
 * Thread-safe fixed-size in-memory ring buffer for raw PCM bytes.
 * Oldest audio is overwritten once capacity is reached; unsaved data never touches disk.
 */
class AudioRingBuffer(val capacityBytes: Int) {
    init {
        require(capacityBytes > 0) { "capacityBytes must be positive" }
    }

    private val buffer = ByteArray(capacityBytes)
    private var writePos = 0
    private var filledBytes = 0

    @Synchronized
    fun write(source: ByteArray, offset: Int = 0, length: Int = source.size - offset) {
        require(offset >= 0 && length >= 0 && offset + length <= source.size) {
            "Invalid slice offset=$offset length=$length for size=${source.size}"
        }
        if (length == 0) return

        if (length >= capacityBytes) {
            // Only the trailing capacityBytes survive in the ring buffer.
            System.arraycopy(source, offset + length - capacityBytes, buffer, 0, capacityBytes)
            writePos = 0
            filledBytes = capacityBytes
            return
        }

        val firstChunk = minOf(length, capacityBytes - writePos)
        System.arraycopy(source, offset, buffer, writePos, firstChunk)

        val remaining = length - firstChunk
        if (remaining > 0) {
            System.arraycopy(source, offset + firstChunk, buffer, 0, remaining)
        }

        writePos = (writePos + length) % capacityBytes
        filledBytes = minOf(capacityBytes, filledBytes + length)
    }

    /**
     * Returns a chronological (oldest -> newest) copy of all currently buffered bytes.
     * If less than [capacityBytes] have been written, returns only the filled portion.
     */
    @Synchronized
    fun snapshot(): ByteArray {
        if (filledBytes == 0) return ByteArray(0)
        if (filledBytes < capacityBytes) {
            return buffer.copyOfRange(0, filledBytes)
        }

        val result = ByteArray(capacityBytes)
        val tailLength = capacityBytes - writePos
        System.arraycopy(buffer, writePos, result, 0, tailLength)
        if (writePos > 0) {
            System.arraycopy(buffer, 0, result, tailLength, writePos)
        }
        return result
    }

    @Synchronized
    fun bufferedBytes(): Int = filledBytes

    /**
     * Atomically captures a chronological snapshot and clears the ring buffer so the
     * next recording window starts fresh from 0 bytes with no overlap or lost frames.
     */
    @Synchronized
    fun snapshotAndClear(): ByteArray {
        val data = snapshot()
        if (data.isNotEmpty()) {
            clear()
        }
        return data
    }

    @Synchronized
    fun clear() {
        buffer.fill(0)
        writePos = 0
        filledBytes = 0
    }
}

class InsufficientStorageException(message: String) : IOException(message)

/**
 * Writes standard 44-byte RIFF/WAVE PCM headers and atomically flushes .wav files.
 */
object WavWriter {
    const val HEADER_SIZE_BYTES = 44
    const val DEFAULT_STORAGE_SAFETY_MARGIN_BYTES = 1_048_576L // 1 MiB headroom

    fun hasEnoughStorage(
        usableBytes: Long,
        pcmDataSizeBytes: Int,
        safetyMarginBytes: Long = DEFAULT_STORAGE_SAFETY_MARGIN_BYTES,
    ): Boolean {
        val required = HEADER_SIZE_BYTES.toLong() + pcmDataSizeBytes.toLong() + safetyMarginBytes
        return usableBytes >= required
    }

    fun buildHeader(
        pcmDataSizeBytes: Int,
        format: AudioFormatSpec = AudioFormatSpec.DEFAULT,
    ): ByteArray {
        require(pcmDataSizeBytes >= 0) { "pcmDataSizeBytes must be non-negative" }
        val chunkSize = 36 + pcmDataSizeBytes
        val out = ByteArrayOutputStream(HEADER_SIZE_BYTES)

        fun writeAscii(text: String) {
            for (c in text) out.write(c.code)
        }

        fun writeIntLE(value: Int) {
            out.write(value and 0xFF)
            out.write((value ushr 8) and 0xFF)
            out.write((value ushr 16) and 0xFF)
            out.write((value ushr 24) and 0xFF)
        }

        fun writeShortLE(value: Int) {
            out.write(value and 0xFF)
            out.write((value ushr 8) and 0xFF)
        }

        writeAscii("RIFF")
        writeIntLE(chunkSize)
        writeAscii("WAVE")
        writeAscii("fmt ")
        writeIntLE(16) // PCM fmt subchunk size
        writeShortLE(1) // AudioFormat = 1 (PCM)
        writeShortLE(format.channels)
        writeIntLE(format.sampleRate)
        writeIntLE(format.bytesPerSecond)
        writeShortLE(format.blockAlign)
        writeShortLE(format.bitsPerSample)
        writeAscii("data")
        writeIntLE(pcmDataSizeBytes)

        return out.toByteArray()
    }

    fun writePcmToWav(
        pcmData: ByteArray,
        destination: File,
        format: AudioFormatSpec = AudioFormatSpec.DEFAULT,
    ): Long {
        destination.parentFile?.let { parent ->
            if (!parent.exists() && !parent.mkdirs()) {
                throw IOException("Failed to create clip directory: ${parent.absolutePath}")
            }
            val usable = parent.usableSpace
            if (usable > 0L && !hasEnoughStorage(usable, pcmData.size)) {
                throw InsufficientStorageException(
                    "Not enough free storage space to save clip.",
                )
            }
        }

        val tmpFile = File(destination.parentFile, "${destination.name}.tmp")
        val header = buildHeader(pcmData.size, format)
        try {
            FileOutputStream(tmpFile).use { fos ->
                fos.write(header)
                fos.write(pcmData)
                fos.fd.sync()
            }
            if (destination.exists()) {
                destination.delete()
            }
            if (!tmpFile.renameTo(destination)) {
                tmpFile.copyTo(destination, overwrite = true)
                tmpFile.delete()
            }
        } catch (e: Exception) {
            tmpFile.delete()
            throw e
        }
        return HEADER_SIZE_BYTES.toLong() + pcmData.size.toLong()
    }
}

/**
 * Generates collision-safe .wav filenames matching Dart's StorageService convention.
 */
object ClipFileNamer {
    fun nextFileName(epochMs: Long, existingNames: Set<String>): String {
        val base = "clip_$epochMs.wav"
        if (base !in existingNames) return base
        var suffix = 1
        while (true) {
            val candidate = "clip_${epochMs}_$suffix.wav"
            if (candidate !in existingNames) return candidate
            suffix++
        }
    }

    fun nextFile(directory: File, epochMs: Long): File {
        if (!directory.exists()) {
            directory.mkdirs()
        }
        val existing = directory.list()?.toSet() ?: emptySet()
        return File(directory, nextFileName(epochMs, existing))
    }
}
