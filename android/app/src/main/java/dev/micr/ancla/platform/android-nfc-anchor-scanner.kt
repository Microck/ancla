package dev.micr.ancla.platform

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.nfc.Tag
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

interface AnchorScanner {
    fun isAvailable(): Boolean

    suspend fun scanAnchor(): String
}

sealed class AnchorScanException(message: String) : IllegalStateException(message) {
    data object Unavailable : AnchorScanException("NFC is unavailable on this device.")

    data object UnsupportedTag : AnchorScanException("This NFC anchor could not be read.")
}

object TagFingerprint {
    fun hash(identifier: ByteArray): String =
        MessageDigest.getInstance("SHA-256")
            .digest(identifier)
            .joinToString(separator = "") { byte -> "%02x".format(byte) }

    fun fromTagIdentifier(identifier: ByteArray?): String? =
        identifier
            ?.takeUnless { it.isEmpty() }
            ?.let(::hash)
}

class AndroidNfcAnchorScanner(
    private val activity: Activity
) : AnchorScanner {
    companion object {
        private const val TAG_REDISPATCH_DEBOUNCE_MS = 1500
        private const val READER_PRESENCE_CHECK_DELAY_MS = 250
    }

    private val scanMutex = Mutex()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun isAvailable(): Boolean {
        val adapter = NfcAdapter.getDefaultAdapter(activity) ?: return false
        return adapter.isEnabled
    }

    override suspend fun scanAnchor(): String =
        scanMutex.withLock {
            AndroidNfcDebugLog.append("scanner-enter")
            val adapter = NfcAdapter.getDefaultAdapter(activity)
                ?: run {
                    AndroidNfcDebugLog.append("scanner-no-adapter")
                    throw AnchorScanException.Unavailable
                }
            if (!adapter.isEnabled) {
                AndroidNfcDebugLog.append("scanner-adapter-disabled")
                throw AnchorScanException.Unavailable
            }
            AndroidNfcDebugLog.append("scanner-adapter-ready", "enabled=true")

            suspendCancellableCoroutine { continuation ->
                val finished = AtomicBoolean(false)

                fun finishWith(result: Result<String>, tagToIgnore: Tag? = null) {
                    if (!finished.compareAndSet(false, true)) {
                        AndroidNfcDebugLog.append("scanner-finish-ignored")
                        return
                    }
                    activity.runOnUiThread {
                        AndroidNfcDebugLog.append(
                            "scanner-finish",
                            buildString {
                                append(
                                    if (result.isSuccess) "success"
                                    else "failure=" + (result.exceptionOrNull()?.message ?: "unknown")
                                )
                                append(" ignoreTag=")
                                append(tagToIgnore != null)
                            }
                        )
                        // Ignore the just-read tag briefly so Android does not immediately
                        // redispatch the same blank/raw tag back to the system chooser/UI
                        // as we tear reader mode down.
                        tagToIgnore?.let { tag ->
                            adapter.ignore(
                                tag,
                                TAG_REDISPATCH_DEBOUNCE_MS,
                                NfcAdapter.OnTagRemovedListener {},
                                mainHandler
                            )
                        }
                        adapter.disableReaderMode(activity)
                        result.fold(
                            onSuccess = continuation::resume,
                            onFailure = continuation::resumeWithException
                        )
                    }
                }

                val flags =
                    NfcAdapter.FLAG_READER_NFC_A or
                        NfcAdapter.FLAG_READER_NFC_B or
                        NfcAdapter.FLAG_READER_NFC_F or
                        NfcAdapter.FLAG_READER_NFC_V or
                        NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS or
                        NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK
                val extras =
                    Bundle().apply {
                        putInt(
                            NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY,
                            READER_PRESENCE_CHECK_DELAY_MS
                        )
                    }
                AndroidNfcDebugLog.append(
                    "scanner-enable-reader-mode",
                    "flags=$flags presenceDelayMs=$READER_PRESENCE_CHECK_DELAY_MS"
                )

                // Keep the active scan flow on reader mode only.
                // Combining reader mode with foreground dispatch can hand blank/raw
                // tags back to the system Tags app on some OEM Android builds.
                fun finishFromTag(tag: Tag) {
                    AndroidNfcDebugLog.append("scanner-tag-discovered", tag.debugSummary())
                    val fingerprint = TagFingerprint.fromTagIdentifier(tag.id)
                    if (fingerprint == null) {
                        AndroidNfcDebugLog.append("scanner-tag-unsupported")
                        finishWith(Result.failure(AnchorScanException.UnsupportedTag))
                    } else {
                        AndroidNfcDebugLog.append("scanner-tag-fingerprint", fingerprint)
                        finishWith(Result.success(fingerprint), tag)
                    }
                }

                activity.runOnUiThread {
                    adapter.enableReaderMode(
                        activity,
                        NfcAdapter.ReaderCallback(::finishFromTag),
                        flags,
                        extras
                    )
                }

                continuation.invokeOnCancellation {
                    if (finished.compareAndSet(false, true)) {
                        activity.runOnUiThread {
                            AndroidNfcDebugLog.append("scanner-cancelled")
                            adapter.disableReaderMode(activity)
                        }
                    }
                }
            }
        }
}

private fun Tag.debugSummary(): String {
    val ndef = Ndef.get(this)
    val cachedRecordCount = ndef?.cachedNdefMessage?.records?.size ?: 0
    return buildString {
        append("id=")
        append(id.toHexString())
        append(" techs=")
        append(techList.joinToString(separator = ","))
        append(" ndefType=")
        append(ndef?.type ?: "none")
        append(" cachedRecords=")
        append(cachedRecordCount)
        append(" writable=")
        append(ndef?.isWritable ?: false)
        append(" formattable=")
        append(NdefFormatable.get(this@debugSummary) != null)
    }
}

private fun ByteArray?.toHexString(): String =
    this?.joinToString(separator = "") { byte -> "%02x".format(byte) } ?: "null"
