package one.darker.qingxu

import java.io.*
import org.apache.commons.compress.compressors.bzip2.BZip2CompressorInputStream

/**
 * BsPatch — bsdiff4 patcher for incremental APK updates.
 * Uses Apache Commons Compress for bzip2 (direct import, NOT reflection).
 */
object BsPatch {

    fun apply(oldPath: String, newPath: String, patchPath: String) {
        val oldBytes = File(oldPath).readBytes()
        val patchBytes = File(patchPath).readBytes()

        if (patchBytes.size < 32) {
            throw IOException("Patch file too small: ${patchBytes.size} bytes")
        }

        // Read header — "BSDIFF40" magic
        val magic = String(patchBytes, 0, 8, Charsets.US_ASCII)
        if (magic != "BSDIFF40") {
            throw IOException("Invalid bsdiff magic: $magic")
        }

        val ctrlLen = offtin(patchBytes, 8)
        val diffLen = offtin(patchBytes, 16)
        val newSize  = offtin(patchBytes, 24)

        if (ctrlLen < 0 || diffLen < 0 || newSize < 0) {
            throw IOException("Corrupt patch header: ctrl=$ctrlLen diff=$diffLen new=$newSize")
        }

        val headerSize = 32
        val ctrlEnd  = headerSize + ctrlLen.toInt()
        val diffEnd  = ctrlEnd + diffLen.toInt()

        if (ctrlEnd > patchBytes.size || diffEnd > patchBytes.size) {
            throw IOException("Patch truncated: size=${patchBytes.size}, need $diffEnd")
        }

        // Decompress bzip2 blocks using Apache Commons Compress (direct import)
        val ctrlBlock  = bz2Decompress(patchBytes, headerSize, ctrlLen.toInt())
        val diffBlock  = bz2Decompress(patchBytes, ctrlEnd, diffLen.toInt())
        val extraBlock = bz2Decompress(patchBytes, diffEnd, patchBytes.size - diffEnd)

        // Apply patch
        val newBytes = ByteArray(newSize.toInt())
        var oldPos = 0
        var newPos = 0
        var ctrlOff = 0
        var diffOff = 0
        var extraOff = 0

        while (newPos < newSize.toInt()) {
            if (ctrlOff + 24 > ctrlBlock.size) {
                throw IOException("Control block exhausted at newPos=$newPos/$newSize")
            }

            val addLen  = offtin(ctrlBlock, ctrlOff);  ctrlOff += 8
            val copyLen = offtin(ctrlBlock, ctrlOff);  ctrlOff += 8
            val seekLen = offtin(ctrlBlock, ctrlOff);  ctrlOff += 8

            if (addLen < 0 || newPos + addLen.toInt() > newSize.toInt()) {
                throw IOException("addLen=$addLen overflow at newPos=$newPos")
            }
            if (diffOff + addLen.toInt() > diffBlock.size) {
                throw IOException("Diff exhausted: need ${diffOff + addLen.toInt()}, have ${diffBlock.size}")
            }

            // Add old data + diff
            for (i in 0 until addLen.toInt()) {
                val oldByte: Int = if (oldPos + i in oldBytes.indices) (oldBytes[oldPos + i].toInt() and 0xFF) else 0
                val diffByte: Int = diffBlock[diffOff + i].toInt() and 0xFF
                newBytes[newPos + i] = ((oldByte + diffByte) and 0xFF).toByte()
            }
            newPos  += addLen.toInt()
            diffOff += addLen.toInt()
            oldPos  += addLen.toInt()

            // Copy extra data
            if (copyLen < 0 || newPos + copyLen.toInt() > newSize.toInt()) {
                throw IOException("copyLen=$copyLen overflow at newPos=$newPos")
            }
            if (extraOff + copyLen.toInt() > extraBlock.size) {
                throw IOException("Extra exhausted: need ${extraOff + copyLen.toInt()}, have ${extraBlock.size}")
            }

            System.arraycopy(extraBlock, extraOff, newBytes, newPos, copyLen.toInt())
            newPos   += copyLen.toInt()
            extraOff += copyLen.toInt()
            oldPos   += seekLen.toInt()
        }

        // Write output
        FileOutputStream(newPath).use { it.write(newBytes) }
    }

    /** Read 64-bit little-endian signed integer (bsdiff format). */
    private fun offtin(buf: ByteArray, offset: Int): Long {
        var y = 0L
        y = y or ((buf[offset + 0].toLong() and 0xFF))
        y = y or ((buf[offset + 1].toLong() and 0xFF) shl 8)
        y = y or ((buf[offset + 2].toLong() and 0xFF) shl 16)
        y = y or ((buf[offset + 3].toLong() and 0xFF) shl 24)
        y = y or ((buf[offset + 4].toLong() and 0xFF) shl 32)
        y = y or ((buf[offset + 5].toLong() and 0xFF) shl 40)
        y = y or ((buf[offset + 6].toLong() and 0xFF) shl 48)
        y = y or ((buf[offset + 7].toLong() and 0x7F) shl 56)
        if ((buf[offset + 7].toInt() and 0x80) != 0) y = -y
        return y
    }

    /** Decompress bzip2 data — direct Apache Commons Compress (no reflection). */
    private fun bz2Decompress(data: ByteArray, offset: Int, length: Int): ByteArray {
        if (length <= 0) return ByteArray(0)
        val input = ByteArrayInputStream(data, offset, length)
        val bz2 = BZip2CompressorInputStream(input)
        val result = bz2.readBytes()
        bz2.close()
        return result
    }
}
