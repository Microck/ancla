package dev.micr.ancla.platform

import android.os.Build
import java.time.Instant

object AndroidNfcDebugLog {
    private const val MAX_ENTRIES = 80

    private val entries = ArrayDeque<String>()

    @Synchronized
    fun resetSession(reason: String) {
        entries.clear()
        append(
            event = "session-start",
            detail =
                buildString {
                    append(reason)
                    append(" manufacturer=")
                    append(Build.MANUFACTURER)
                    append(" model=")
                    append(Build.MODEL)
                    append(" sdk=")
                    append(Build.VERSION.SDK_INT)
                }
        )
    }

    @Synchronized
    fun append(event: String, detail: String? = null) {
        val line =
            buildString {
                append(Instant.now().toString())
                append(" | ")
                append(event)
                if (!detail.isNullOrBlank()) {
                    append(" | ")
                    append(detail)
                }
            }
        if (entries.size == MAX_ENTRIES) {
            entries.removeFirst()
        }
        entries.addLast(line)
    }

    @Synchronized
    fun snapshot(): String =
        if (entries.isEmpty()) {
            "No NFC debug logs captured."
        } else {
            entries.joinToString(separator = "\n")
        }
}
