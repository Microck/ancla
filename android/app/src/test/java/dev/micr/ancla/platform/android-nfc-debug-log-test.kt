package dev.micr.ancla.platform

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidNfcDebugLogTest {
    @Test
    fun resetSessionIncludesReasonAndSubsequentEvents() {
        AndroidNfcDebugLog.resetSession("mode=PAIR")
        AndroidNfcDebugLog.append("scanner-enter")

        val snapshot = AndroidNfcDebugLog.snapshot()

        assertTrue(snapshot.contains("session-start"))
        assertTrue(snapshot.contains("mode=PAIR"))
        assertTrue(snapshot.contains("scanner-enter"))
    }

    @Test
    fun snapshotKeepsOnlyRecentEntries() {
        AndroidNfcDebugLog.resetSession("trim-test")
        repeat(120) { index ->
            AndroidNfcDebugLog.append("event-$index")
        }

        val snapshot = AndroidNfcDebugLog.snapshot()

        assertFalse(snapshot.contains("event-0"))
        assertTrue(snapshot.contains("event-119"))
    }
}
