package com.learnese.app

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class AudioRingBufferTest {
    @get:Rule
    val tempFolder = TemporaryFolder()

    @Test
    fun audioFormatSpecComputesCapacityAndDuration() {
        val spec = AudioFormatSpec.DEFAULT
        assertEquals(88_200, spec.bytesPerSecond)
        assertEquals(2_646_000, spec.capacityBytesForSeconds(30))
        assertEquals(15_876_000, spec.capacityBytesForSeconds(180))
        assertEquals(0L, spec.durationMsForBytes(0))
        assertEquals(500L, spec.durationMsForBytes(44_100))
        assertEquals(30_000L, spec.durationMsForBytes(2_646_000))
    }

    @Test(expected = IllegalArgumentException::class)
    fun audioFormatSpecRejectsTooSmallBuffer() {
        AudioFormatSpec.DEFAULT.capacityBytesForSeconds(0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun audioFormatSpecRejectsTooLargeBuffer() {
        AudioFormatSpec.DEFAULT.capacityBytesForSeconds(181)
    }

    @Test
    fun emptyBufferProducesEmptySnapshot() {
        val ring = AudioRingBuffer(capacityBytes = 8)
        assertEquals(0, ring.bufferedBytes())
        assertEquals(0, ring.snapshot().size)
    }

    @Test
    fun partialFillReturnsExactWrittenBytesInOrder() {
        val ring = AudioRingBuffer(capacityBytes = 10)
        ring.write(byteArrayOf(1, 2, 3))
        ring.write(byteArrayOf(4, 5))

        assertEquals(5, ring.bufferedBytes())
        assertArrayEquals(byteArrayOf(1, 2, 3, 4, 5), ring.snapshot())
    }

    @Test
    fun exactFillReturnsFullBufferInOrder() {
        val ring = AudioRingBuffer(capacityBytes = 4)
        ring.write(byteArrayOf(10, 20, 30, 40))

        assertEquals(4, ring.bufferedBytes())
        assertArrayEquals(byteArrayOf(10, 20, 30, 40), ring.snapshot())
    }

    @Test
    fun singleWrapAroundPreservesOldestToNewestOrder() {
        val ring = AudioRingBuffer(capacityBytes = 5)
        ring.write(byteArrayOf(1, 2, 3, 4))
        ring.write(byteArrayOf(5, 6, 7))

        assertEquals(5, ring.bufferedBytes())
        assertArrayEquals(byteArrayOf(3, 4, 5, 6, 7), ring.snapshot())
    }

    @Test
    fun multipleWrapAroundsKeepOnlyLatestBytes() {
        val ring = AudioRingBuffer(capacityBytes = 4)
        for (chunkStart in 0 until 20 step 3) {
            ring.write(
                byteArrayOf(
                    chunkStart.toByte(),
                    (chunkStart + 1).toByte(),
                    (chunkStart + 2).toByte(),
                ),
            )
        }
        // Last written bytes are 17, 18, 19, 20 (loop ends at chunkStart=18 -> writes 18,19,20).
        assertEquals(4, ring.bufferedBytes())
        assertArrayEquals(byteArrayOf(17, 18, 19, 20), ring.snapshot())
    }

    @Test
    fun writeLargerThanCapacityRetainsTrailingCapacityBytes() {
        val ring = AudioRingBuffer(capacityBytes = 4)
        ring.write(byteArrayOf(1, 2))
        ring.write(byteArrayOf(10, 11, 12, 13, 14, 15))

        assertEquals(4, ring.bufferedBytes())
        assertArrayEquals(byteArrayOf(12, 13, 14, 15), ring.snapshot())
    }

    @Test
    fun writeRespectsSliceOffsetAndLength() {
        val ring = AudioRingBuffer(capacityBytes = 6)
        val source = byteArrayOf(99, 1, 2, 3, 99)
        ring.write(source, offset = 1, length = 3)
        ring.write(source, offset = 0, length = 0)

        assertEquals(3, ring.bufferedBytes())
        assertArrayEquals(byteArrayOf(1, 2, 3), ring.snapshot())
    }

    @Test
    fun clearResetsBufferState() {
        val ring = AudioRingBuffer(capacityBytes = 4)
        ring.write(byteArrayOf(7, 8, 9, 10, 11))
        ring.clear()

        assertEquals(0, ring.bufferedBytes())
        assertArrayEquals(ByteArray(0), ring.snapshot())

        ring.write(byteArrayOf(42, 43))
        assertArrayEquals(byteArrayOf(42, 43), ring.snapshot())
    }

    @Test
    fun wavWriterProducesValid44ByteRiffPcmHeaderAndFile() {
        val pcm = byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8)
        val header = WavWriter.buildHeader(pcm.size, AudioFormatSpec.DEFAULT)
        assertEquals(44, header.size)

        val bb = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals("RIFF", String(header, 0, 4, Charsets.US_ASCII))
        assertEquals(36 + pcm.size, bb.getInt(4))
        assertEquals("WAVE", String(header, 8, 4, Charsets.US_ASCII))
        assertEquals("fmt ", String(header, 12, 4, Charsets.US_ASCII))
        assertEquals(16, bb.getInt(16))
        assertEquals(1.toShort(), bb.getShort(20)) // PCM
        assertEquals(1.toShort(), bb.getShort(22)) // Mono
        assertEquals(44_100, bb.getInt(24)) // Sample rate
        assertEquals(88_200, bb.getInt(28)) // Byte rate
        assertEquals(2.toShort(), bb.getShort(32)) // Block align
        assertEquals(16.toShort(), bb.getShort(34)) // Bits per sample
        assertEquals("data", String(header, 36, 4, Charsets.US_ASCII))
        assertEquals(pcm.size, bb.getInt(40))

        val dest = File(tempFolder.root, "session_1/clip_1000.wav")
        val writtenSize = WavWriter.writePcmToWav(pcm, dest, AudioFormatSpec.DEFAULT)
        assertEquals(44L + pcm.size, writtenSize)
        assertTrue(dest.exists())
        assertFalse(File(dest.parentFile, "${dest.name}.tmp").exists())

        val bytes = dest.readBytes()
        assertEquals(44 + pcm.size, bytes.size)
        assertArrayEquals(pcm, bytes.copyOfRange(44, bytes.size))
    }

    @Test
    fun clipFileNamerResolvesTimestampCollisions() {
        assertEquals(
            "clip_1700000000000.wav",
            ClipFileNamer.nextFileName(1700000000000L, emptySet()),
        )
        assertEquals(
            "clip_1700000000000_2.wav",
            ClipFileNamer.nextFileName(
                1700000000000L,
                setOf("clip_1700000000000.wav", "clip_1700000000000_1.wav"),
            ),
        )

        val dir = tempFolder.newFolder("clips")
        val first = ClipFileNamer.nextFile(dir, 5555L)
        assertEquals("clip_5555.wav", first.name)
        first.writeBytes(byteArrayOf(1))

        val second = ClipFileNamer.nextFile(dir, 5555L)
        assertEquals("clip_5555_1.wav", second.name)
    }
}
