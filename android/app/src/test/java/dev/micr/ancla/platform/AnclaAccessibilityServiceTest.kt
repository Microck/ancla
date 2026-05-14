package dev.micr.ancla.platform

import dev.micr.ancla.model.ActiveSession
import dev.micr.ancla.model.AccessibilityBlockingSnapshotPayload
import dev.micr.ancla.model.AppSetupState
import dev.micr.ancla.model.AppState
import dev.micr.ancla.model.BlockMode
import dev.micr.ancla.model.BlockingInterception
import dev.micr.ancla.model.BlockingTarget
import dev.micr.ancla.model.FakeAppStateStorage
import dev.micr.ancla.model.PairedAnchor
import dev.micr.ancla.model.PersistentAppRepository
import dev.micr.ancla.model.SessionState
import dev.micr.ancla.model.TargetKind
import java.time.Instant
import kotlinx.collections.immutable.persistentListOf
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import kotlinx.coroutines.runBlocking
import org.junit.Test

class AnclaAccessibilityServiceTest {
    @Test
    fun snapshotReportsBlockingOnlyForSelectedTargetsWhileSessionIsActive() {
        val mode =
            BlockMode(
                name = "Work",
                isDefault = true,
                targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
            )
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val state =
            AppState(
                blockingAuthorized = true,
                setup = AppSetupState(blockingToolsAcknowledged = true),
                anchors = persistentListOf(anchor),
                modes = persistentListOf(mode),
                selectedModeId = mode.id,
                activeSession = ActiveSession(
                    modeId = mode.id,
                    anchorId = anchor.id,
                    state = SessionState.ARMED,
                    resolvedTargets = mode.targets,
                    armedAt = Instant.parse("2026-04-12T10:00:00Z")
                )
            )
        val snapshot = AccessibilityBlockingSnapshot(state) { Instant.parse("2026-04-12T10:01:00Z") }

        assertTrue(snapshot.isBlocking)
        assertEquals("Slack", snapshot.interceptionFor("com.slack")?.targetLabel)
        assertEquals(null, snapshot.interceptionFor("com.discord"))
    }

    @Test
    fun payloadCarriesOnlySelectedTargetsForBlockingSession() {
        val mode =
            BlockMode(
                name = "Work",
                isDefault = true,
                targets = persistentListOf(
                    BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"),
                    BlockingTarget("chrome", "Chrome", TargetKind.BROWSER, "com.android.chrome")
                )
            )
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val state =
            AppState(
                blockingAuthorized = true,
                setup = AppSetupState(blockingToolsAcknowledged = true),
                anchors = persistentListOf(anchor),
                modes = persistentListOf(mode),
                selectedModeId = mode.id,
                activeSession = ActiveSession(
                    modeId = mode.id,
                    anchorId = anchor.id,
                    state = SessionState.WRONG_ANCHOR,
                    resolvedTargets = mode.targets,
                    armedAt = Instant.parse("2026-04-12T10:00:00Z")
                )
            )

        val payload = AccessibilityBlockingSnapshotPayload.fromState(state)

        assertTrue(payload.isBlocking)
        assertEquals("Work", payload.modeName)
        assertEquals("Desk anchor", payload.anchorName)
        assertEquals("Slack", payload.interceptionFor("com.slack")?.targetLabel)
        assertEquals("Chrome", payload.interceptionFor("com.android.chrome")?.targetLabel)
        assertNull(payload.interceptionFor("com.discord"))
    }

    @Test
    fun payloadStopsInterceptingDuringTemporaryUnlockAndAfterRelease() {
        val mode =
            BlockMode(
                name = "Work",
                isDefault = true,
                targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
            )
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val session = ActiveSession(
            modeId = mode.id,
            anchorId = anchor.id,
            state = SessionState.ARMED,
            resolvedTargets = mode.targets,
            armedAt = Instant.parse("2026-04-12T10:00:00Z")
        )

        val unlockedPayload =
            AccessibilityBlockingSnapshotPayload.fromState(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true),
                    anchors = persistentListOf(anchor),
                    modes = persistentListOf(mode),
                    selectedModeId = mode.id,
                    activeSession = session,
                    temporaryUnlock = dev.micr.ancla.model.TemporaryUnlockState(
                        reason = "Check 2FA",
                        startedAt = Instant.now(),
                        expiresAt = Instant.now().plusSeconds(60)
                    )
                )
            )
        val releasedPayload =
            AccessibilityBlockingSnapshotPayload.fromState(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true),
                    anchors = persistentListOf(anchor),
                    modes = persistentListOf(mode),
                    selectedModeId = mode.id,
                    activeSession = null
                )
            )

        assertFalse(unlockedPayload.isBlocking)
        assertNull(unlockedPayload.interceptionFor("com.slack"))
        assertFalse(releasedPayload.isBlocking)
        assertNull(releasedPayload.interceptionFor("com.slack"))
    }

    @Test
    fun serviceLoadsPersistedBlockingSnapshotWithoutMainActivityPublication() {
        val sessionId = java.util.UUID.fromString("77777777-7777-7777-7777-777777777777")
        val service =
            RecordingAccessibilityService(
                snapshot = AccessibilityBlockingSnapshotPayload.empty()
            )

        service.snapshot =
            AccessibilityBlockingSnapshotPayload(
                isBlocking = true,
                sessionId = sessionId,
                sessionState = SessionState.WRONG_ANCHOR,
                sessionStartedAt = Instant.parse("2026-04-12T10:00:00Z"),
                modeName = "Work",
                anchorName = "Desk anchor",
                targets = persistentListOf(
                    BlockingTarget("chrome", "Chrome", TargetKind.BROWSER, "com.android.chrome")
                )
            )

        service.dispatchPackageEvent("com.android.chrome", eventType = 32, windowId = 51)

        assertEquals(1, service.startedInterceptions.size)
        assertEquals(SessionState.WRONG_ANCHOR, service.startedInterceptions.single().sessionState)
        assertEquals("Desk anchor", service.startedInterceptions.single().anchorName)
    }

    @Test
    fun serviceStopsInterceptingAfterPersistedCleanupClearsSnapshot() {
        val sessionId = java.util.UUID.fromString("88888888-8888-8888-8888-888888888888")
        val service =
            RecordingAccessibilityService(
                snapshot = AccessibilityBlockingSnapshotPayload(
                    isBlocking = true,
                    sessionId = sessionId,
                    sessionState = SessionState.ARMED,
                    sessionStartedAt = Instant.parse("2026-04-12T10:00:00Z"),
                    modeName = "Work",
                    anchorName = "Desk anchor",
                    targets = persistentListOf(
                        BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack")
                    )
                )
            )

        service.dispatchPackageEvent("com.slack", eventType = 32, windowId = 61)
        service.snapshot = AccessibilityBlockingSnapshotPayload.empty()
        service.dispatchPackageEvent("dev.micr.ancla", eventType = 32, windowId = 62)
        service.dispatchPackageEvent("com.slack", eventType = 32, windowId = 63)

        assertEquals(1, service.startedInterceptions.size)
    }

    @Test
    fun persistentStorageRestoresWrongAnchorStateForIndependentServiceReads() = runBlocking {
        val storage = FakeAppStateStorage()
        val repository = PersistentAppRepository.create(storage)

        repository.setBlockingAuthorization(true)
        repository.acknowledgeBlockingSetup()
        repository.pairAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        repository.saveMode(
            dev.micr.ancla.model.ModeDraft(
                name = "Work",
                selectedTargetIds = setOf("com.slack", "com.android.chrome"),
                isDefault = true
            )
        )
        repository.armSession("anchor-alpha")
        repository.releaseSession("wrong-anchor")

        val payload = storage.loadBlockingSnapshot()

        assertTrue(payload.isBlocking)
        assertEquals(SessionState.WRONG_ANCHOR, payload.sessionState)
        assertEquals("Work", payload.modeName)
        assertEquals("Desk anchor", payload.anchorName)
        assertEquals("Slack", payload.interceptionFor("com.slack")?.targetLabel)
        assertEquals("Chrome", payload.interceptionFor("com.android.chrome")?.targetLabel)
    }

    @Test
    fun persistentStorageSuppressesBlockingDuringTemporaryUnlockAndClearsAfterForcedCleanup() = runBlocking {
        val storage = FakeAppStateStorage()
        val repository = PersistentAppRepository.create(storage)

        repository.setBlockingAuthorization(true)
        repository.acknowledgeBlockingSetup()
        repository.pairAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        repository.saveMode(
            dev.micr.ancla.model.ModeDraft(
                name = "Work",
                selectedTargetIds = setOf("com.slack"),
                isDefault = true
            )
        )
        repository.armSession("anchor-alpha")
        repository.activateTemporaryUnlock(reason = "Check 2FA", durationSeconds = 60)

        val unlockedPayload = storage.loadBlockingSnapshot()
        assertFalse(unlockedPayload.isBlocking)
        assertNull(unlockedPayload.interceptionFor("com.slack"))

        val activeAnchorId = requireNotNull(repository.state.value.anchors.firstOrNull()).id
        repository.removeAnchor(activeAnchorId)

        val cleanedPayload = storage.loadBlockingSnapshot()
        assertFalse(cleanedPayload.isBlocking)
        assertNull(cleanedPayload.sessionId)
        assertNull(cleanedPayload.interceptionFor("com.slack"))
    }

    @Test
    fun payloadKeepsEverySelectedTargetAvailableForServiceMatching() {
        val mode =
            BlockMode(
                name = "Deep work",
                isDefault = true,
                targets = persistentListOf(
                    BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"),
                    BlockingTarget("firefox", "Firefox", TargetKind.BROWSER, "org.mozilla.firefox"),
                    BlockingTarget("youtube", "YouTube", TargetKind.APP, "com.google.android.youtube")
                )
            )
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val payload =
            AccessibilityBlockingSnapshotPayload.fromState(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true),
                    anchors = persistentListOf(anchor),
                    modes = persistentListOf(mode),
                    selectedModeId = mode.id,
                    activeSession = ActiveSession(
                        modeId = mode.id,
                        anchorId = anchor.id,
                        state = SessionState.ARMED,
                        resolvedTargets = mode.targets,
                        armedAt = Instant.parse("2026-04-12T10:00:00Z")
                    )
                )
            )

        assertEquals(
            listOf("com.slack", "org.mozilla.firefox", "com.google.android.youtube"),
            payload.targets.map { it.packageName }
        )
        assertEquals("Firefox", payload.interceptionFor("org.mozilla.firefox")?.targetLabel)
        assertEquals("YouTube", payload.interceptionFor("com.google.android.youtube")?.targetLabel)
    }

    @Test
    fun serviceStartsLockSurfaceForSelectedPackageAndSuppressesDuplicatesUntilStateChanges() {
        val interception =
            BlockingInterception(
                packageName = "com.slack",
                targetId = "slack",
                targetLabel = "Slack",
                targetKind = TargetKind.APP,
                modeName = "Work",
                anchorName = "Desk anchor",
                sessionId = java.util.UUID.fromString("11111111-1111-1111-1111-111111111111"),
                sessionState = SessionState.ARMED,
                sessionStartedAt = Instant.parse("2026-04-12T10:00:00Z")
            )
        val service =
            RecordingAccessibilityService(
                snapshot = AccessibilityBlockingSnapshotPayload(
                    isBlocking = true,
                    sessionId = interception.sessionId,
                    sessionState = interception.sessionState,
                    sessionStartedAt = interception.sessionStartedAt,
                    modeName = interception.modeName,
                    anchorName = interception.anchorName,
                    targets = persistentListOf(
                        BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack")
                    )
                )
            )

        service.dispatchPackageEvent("com.slack", eventType = 32)
        service.dispatchPackageEvent("dev.micr.ancla", eventType = 32)
        service.dispatchPackageEvent("com.slack", eventType = 32)

        assertEquals(
            listOf(interception),
            service.startedInterceptions
        )
        assertEquals(emptyList<String>(), service.redirectedPackages)

        service.snapshot = service.snapshot.copy(sessionState = SessionState.WRONG_ANCHOR)
        service.dispatchPackageEvent("com.slack", eventType = 32)

        assertEquals(
            listOf(interception, interception.copy(sessionState = SessionState.WRONG_ANCHOR)),
            service.startedInterceptions
        )
        assertEquals(emptyList<String>(), service.redirectedPackages)
    }

    @Test
    fun productionServicePathMovesBlockedAppAwayBeforeShowingLockSurface() {
        val interception =
            BlockingInterception(
                packageName = "com.slack",
                targetId = "slack",
                targetLabel = "Slack",
                targetKind = TargetKind.APP,
                modeName = "Work",
                anchorName = "Desk anchor",
                sessionId = java.util.UUID.fromString("12121212-1212-1212-1212-121212121212"),
                sessionState = SessionState.ARMED,
                sessionStartedAt = Instant.parse("2026-04-12T10:00:00Z")
            )
        val service = ProductionPathRecordingAccessibilityService()

        service.start(interception)

        assertEquals(listOf("home"), service.safetyActions)
        assertEquals(listOf(interception), service.overlayInterceptions)
        assertEquals(1, service.lockSurfaceIntents.size)
        assertEquals(listOf("home", "overlay", "activity"), service.operations)
    }

    @Test
    fun serviceIgnoresOwnPackageAndResetsDuplicateSuppressionWhenTargetStopsBlocking() {
        val sessionId = java.util.UUID.fromString("22222222-2222-2222-2222-222222222222")
        val service =
            RecordingAccessibilityService(
                snapshot = AccessibilityBlockingSnapshotPayload(
                    isBlocking = true,
                    sessionId = sessionId,
                    sessionState = SessionState.ARMED,
                    sessionStartedAt = Instant.parse("2026-04-12T10:00:00Z"),
                    modeName = "Work",
                    anchorName = "Desk anchor",
                    targets = persistentListOf(
                        BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack")
                    )
                )
            )

        service.dispatchPackageEvent("dev.micr.ancla", eventType = 32)
        service.dispatchPackageEvent("com.slack", eventType = 32)
        service.snapshot = AccessibilityBlockingSnapshotPayload.empty()
        service.dispatchPackageEvent("com.slack", eventType = 32)
        service.snapshot = service.snapshot.copy(
            isBlocking = true,
            sessionId = sessionId,
            sessionState = SessionState.ARMED,
            sessionStartedAt = Instant.parse("2026-04-12T10:00:00Z"),
            modeName = "Work",
            anchorName = "Desk anchor",
            targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
        )
        service.dispatchPackageEvent("com.slack", eventType = 32)

        assertEquals(2, service.startedInterceptions.size)
        assertTrue(service.startedInterceptions.all { it.packageName == "com.slack" })
    }

    @Test
    fun serviceKeepsInterceptingRepeatedBlockedLaunchesAfterReturningFromLockSurface() {
        val sessionId = java.util.UUID.fromString("33333333-3333-3333-3333-333333333333")
        val service =
            RecordingAccessibilityService(
                snapshot = AccessibilityBlockingSnapshotPayload(
                    isBlocking = true,
                    sessionId = sessionId,
                    sessionState = SessionState.ARMED,
                    sessionStartedAt = Instant.parse("2026-04-12T10:00:00Z"),
                    modeName = "Work",
                    anchorName = "Desk anchor",
                    targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
                )
            )

        service.dispatchPackageEvent("com.slack", eventType = 32, windowId = 11)
        service.dispatchPackageEvent("dev.micr.ancla", eventType = 32, windowId = 12)
        service.dispatchPackageEvent("com.slack", eventType = 32, windowId = 13)

        assertEquals(2, service.startedInterceptions.size)
        assertTrue(service.startedInterceptions.all { it.packageName == "com.slack" })
    }

    @Test
    fun duplicateSuppressionOnlyAppliesToTheSameWindowWhileLockSurfaceOwnsForeground() {
        val sessionId = java.util.UUID.fromString("66666666-6666-6666-6666-666666666666")
        val service =
            RecordingAccessibilityService(
                snapshot = AccessibilityBlockingSnapshotPayload(
                    isBlocking = true,
                    sessionId = sessionId,
                    sessionState = SessionState.ARMED,
                    sessionStartedAt = Instant.parse("2026-04-12T10:00:00Z"),
                    modeName = "Work",
                    anchorName = "Desk anchor",
                    targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
                )
            )

        service.dispatchPackageEvent("com.slack", eventType = 32, windowId = 41)
        service.dispatchPackageEvent("dev.micr.ancla", eventType = 32, windowId = 41)
        service.dispatchPackageEvent("com.slack", eventType = 32, windowId = 41)
        service.dispatchPackageEvent("com.slack", eventType = 32, windowId = 43)

        assertEquals(2, service.startedInterceptions.size)
        assertEquals(41, service.startedWindowIds.first())
        assertEquals(43, service.startedWindowIds.last())
    }

    @Test
    fun duplicateBlockedWindowEventsStaySuppressedOnRealServicePathWhileLockSurfaceRemainsForeground() {
        val sessionId = java.util.UUID.fromString("99999999-9999-9999-9999-999999999999")
        val service =
            RecordingAccessibilityService(
                snapshot = AccessibilityBlockingSnapshotPayload(
                    isBlocking = true,
                    sessionId = sessionId,
                    sessionState = SessionState.ARMED,
                    sessionStartedAt = Instant.parse("2026-04-12T10:00:00Z"),
                    modeName = "Work",
                    anchorName = "Desk anchor",
                    targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
                )
            )

        service.dispatchPackageEvent("com.slack", eventType = 32, windowId = 71)
        service.dispatchPackageEvent("dev.micr.ancla", eventType = 32, windowId = 72)
        service.dispatchPackageEvent("com.slack", eventType = 32, windowId = 71)
        service.dispatchPackageEvent("dev.micr.ancla", eventType = 32, windowId = 72)
        service.dispatchPackageEvent("com.slack", eventType = 32, windowId = 71)

        assertEquals(1, service.startedInterceptions.size)
        assertEquals(listOf(71), service.startedWindowIds)
    }

    @Test
    fun serviceAllowsAnotherSelectedTargetToInterceptDuringSameSession() {
        val sessionId = java.util.UUID.fromString("55555555-5555-5555-5555-555555555555")
        val service =
            RecordingAccessibilityService(
                snapshot = AccessibilityBlockingSnapshotPayload(
                    isBlocking = true,
                    sessionId = sessionId,
                    sessionState = SessionState.WRONG_ANCHOR,
                    sessionStartedAt = Instant.parse("2026-04-12T10:00:00Z"),
                    modeName = "Work",
                    anchorName = "Desk anchor",
                    targets = persistentListOf(
                        BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"),
                        BlockingTarget("chrome", "Chrome", TargetKind.BROWSER, "com.android.chrome")
                    )
                )
            )

        service.dispatchPackageEvent("com.slack", eventType = 32, windowId = 21)
        service.dispatchPackageEvent("dev.micr.ancla", eventType = 32, windowId = 22)
        service.dispatchPackageEvent("com.android.chrome", eventType = 32, windowId = 23)

        assertEquals(listOf("com.slack", "com.android.chrome"), service.startedInterceptions.map { it.packageName })
        assertTrue(service.startedInterceptions.all { it.sessionState == SessionState.WRONG_ANCHOR })
    }

    private class RecordingAccessibilityService(
        var snapshot: AccessibilityBlockingSnapshotPayload
    ) : AnclaAccessibilityService() {
        val startedInterceptions = mutableListOf<BlockingInterception>()
        val startedWindowIds = mutableListOf<Int>()
        val redirectedPackages = mutableListOf<String>()
        private var currentForegroundPackage: String? = null
        private var lastInterceptedPackage: String? = null
        private var lastInterceptedSessionId: java.util.UUID? = null
        private var lastInterceptedSessionState: SessionState? = null
        private var lastInterceptedWindowId: Int? = null
        private var lastInterceptedEventType: Int? = null
        private var lastLockSurfacePackage: String? = null
        private var lastLockSurfaceSessionId: java.util.UUID? = null
        private var lastLockSurfaceSessionState: SessionState? = null
        private var lastLockSurfaceWindowId: Int? = null
        private var lastLockSurfaceEventType: Int? = null

        fun dispatchPackageEvent(
            packageName: String,
            eventType: Int,
            windowId: Int = 1
        ) {
            val previousForegroundPackage = currentForegroundPackage
            currentForegroundPackage = packageName
            if (packageName == "dev.micr.ancla") {
                return
            }
            val interception = snapshot.interceptionFor(packageName) ?: run {
                clearInterception(packageName)
                return
            }
            val duplicate =
                lastInterceptedPackage == interception.packageName &&
                    lastInterceptedSessionId == interception.sessionId &&
                    lastInterceptedSessionState == interception.sessionState &&
                    lastInterceptedWindowId == windowId &&
                    lastInterceptedEventType == eventType &&
                    previousForegroundPackage == "dev.micr.ancla" &&
                    lastLockSurfacePackage == interception.packageName &&
                    lastLockSurfaceSessionId == interception.sessionId &&
                    lastLockSurfaceSessionState == interception.sessionState &&
                    lastLockSurfaceWindowId == windowId &&
                    lastLockSurfaceEventType == eventType
            if (duplicate) return

            lastInterceptedPackage = interception.packageName
            lastInterceptedSessionId = interception.sessionId
            lastInterceptedSessionState = interception.sessionState
            lastInterceptedWindowId = windowId
            lastInterceptedEventType = eventType
            startLockSurface(interception)
        }

        override fun loadBlockingSnapshot(): AccessibilityBlockingSnapshotPayload = snapshot

        override fun redirectBlockedAppToSafety() {
            redirectedPackages += requireNotNull(lastInterceptedPackage)
        }

        override fun startLockSurface(interception: BlockingInterception) {
            startedInterceptions += interception
            startedWindowIds += requireNotNull(lastInterceptedWindowId)
            lastLockSurfacePackage = interception.packageName
            lastLockSurfaceSessionId = interception.sessionId
            lastLockSurfaceSessionState = interception.sessionState
            lastLockSurfaceWindowId = lastInterceptedWindowId
            lastLockSurfaceEventType = lastInterceptedEventType
        }

        private fun clearInterception(packageName: String) {
            if (lastInterceptedPackage == packageName || packageName == "dev.micr.ancla") {
                lastInterceptedPackage = null
                lastInterceptedSessionId = null
                lastInterceptedSessionState = null
                lastInterceptedWindowId = null
                lastInterceptedEventType = null
            }
            if (lastLockSurfacePackage == packageName) {
                lastLockSurfacePackage = null
                lastLockSurfaceSessionId = null
                lastLockSurfaceSessionState = null
                lastLockSurfaceWindowId = null
                lastLockSurfaceEventType = null
            }
        }
    }

    private class ProductionPathRecordingAccessibilityService : AnclaAccessibilityService() {
        val operations = mutableListOf<String>()
        val safetyActions = mutableListOf<String>()
        val overlayInterceptions = mutableListOf<BlockingInterception>()
        val lockSurfaceIntents = mutableListOf<android.content.Intent>()

        fun start(interception: BlockingInterception) {
            startLockSurface(interception)
        }

        override fun redirectBlockedAppToSafety() {
            operations += "home"
            safetyActions += "home"
        }

        override fun showAccessibilityLockOverlay(interception: BlockingInterception) {
            operations += "overlay"
            overlayInterceptions += interception
        }

        override fun createLockSurfaceIntent(interception: BlockingInterception): android.content.Intent =
            android.content.Intent()

        override fun scheduleLockSurfaceLaunch(intent: android.content.Intent) {
            showLockSurface(intent)
        }

        override fun showLockSurface(intent: android.content.Intent) {
            operations += "activity"
            lockSurfaceIntents += intent
        }
    }
}
