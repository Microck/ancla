package dev.micr.ancla.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AndroidNfcAnchorScannerTest {
    @Test
    fun tagFingerprintMatchesStableSha256HexEncoding() {
        val fingerprint = TagFingerprint.hash(byteArrayOf(0x01, 0x23, 0x45, 0x67))

        assertEquals(
            "e314ec0e5963f2f9f74ff4e884cf1f09abaf4fde9024f4cd4a47807f8da9f096",
            fingerprint
        )
    }

    @Test
    fun fromTagIdentifierRejectsMissingOrEmptyIdentifiers() {
        assertNull(TagFingerprint.fromTagIdentifier(null))
        assertNull(TagFingerprint.fromTagIdentifier(byteArrayOf()))
    }
}
