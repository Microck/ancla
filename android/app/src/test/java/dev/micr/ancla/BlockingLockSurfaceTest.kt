package dev.micr.ancla

import dev.micr.ancla.model.ActiveSession
import dev.micr.ancla.model.AppSetupState
import dev.micr.ancla.model.AppState
import dev.micr.ancla.model.BlockMode
import dev.micr.ancla.model.BlockingTarget
import dev.micr.ancla.model.InMemoryAppRepository
import dev.micr.ancla.model.PairedAnchor
import dev.micr.ancla.model.SessionState
import dev.micr.ancla.model.TargetKind
import dev.micr.ancla.model.TemporaryUnlockState
import dev.micr.ancla.model.browserstackScheduleSeededAppState
import dev.micr.ancla.model.blockedPresentationIsActive
import dev.micr.ancla.model.blockingInterceptionForPackage
import dev.micr.ancla.model.nextScheduleTransitionAt
import dev.micr.ancla.model.shouldInterceptPackage
import dev.micr.ancla.model.temporaryUnlockIsActive
import java.util.UUID
import java.time.Instant
import kotlinx.collections.immutable.persistentListOf
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BlockingLockSurfaceTest {
    @Test
    fun blockedPresentationOnlyAppliesToSelectedTargetsAndSuppressesDuringTemporaryUnlock() {
        val mode =
            BlockMode(
                name = "Work",
                isDefault = true,
                targets =
                    persistentListOf(
                        BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"),
                        BlockingTarget("chrome", "Chrome", TargetKind.BROWSER, "com.android.chrome")
                    )
            )
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val session =
            ActiveSession(
                modeId = mode.id,
                anchorId = anchor.id,
                state = SessionState.ARMED,
                resolvedTargets = mode.targets,
                armedAt = Instant.parse("2026-04-12T10:00:00Z")
            )
        val state =
            AppState(
                blockingAuthorized = true,
                setup = AppSetupState(blockingToolsAcknowledged = true),
                anchors = persistentListOf(anchor),
                modes = persistentListOf(mode),
                selectedModeId = mode.id,
                activeSession = session
            )
        val now = Instant.parse("2026-04-12T10:01:00Z")

        assertTrue(blockedPresentationIsActive(state, now))
        assertTrue(mode.targets.any { it.id == "slack" })
        assertTrue(mode.targets.any { it.id == "chrome" })
        assertFalse(mode.targets.any { it.id == "discord" })

        val temporaryUnlockState =
            state.copy(
                temporaryUnlock =
                    TemporaryUnlockState(
                        reason = "Check 2FA",
                        startedAt = now.minusSeconds(5),
                        expiresAt = now.plusSeconds(55)
                    )
            )
        assertTrue(temporaryUnlockIsActive(temporaryUnlockState, now))
        assertFalse(blockedPresentationIsActive(temporaryUnlockState, now))
    }

    @Test
    fun temporaryUnlockExpiryAndOwningResourceCleanupClearBlockedSuppression() {
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val mode =
            BlockMode(
                name = "Work",
                isDefault = true,
                targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
            )
        val repository =
            InMemoryAppRepository(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true),
                    anchors = persistentListOf(anchor),
                    modes = persistentListOf(mode),
                    selectedModeId = mode.id,
                    activeSession = ActiveSession(modeId = mode.id, anchorId = anchor.id, state = SessionState.ARMED)
                )
            )

        repository.activateTemporaryUnlock("Check 2FA", 1)
        assertNotNull(repository.state.value.temporaryUnlock)

        repository.expireTemporaryUnlock(Instant.now().plusSeconds(2))
        assertEquals(null, repository.state.value.temporaryUnlock)
        assertTrue(blockedPresentationIsActive(repository.state.value))

        repository.activateTemporaryUnlock("Check 2FA", 60)
        repository.removeAnchor(anchor.id)
        assertEquals(null, repository.state.value.activeSession)
        assertEquals(null, repository.state.value.temporaryUnlock)
        assertFalse(blockedPresentationIsActive(repository.state.value))
    }

    @Test
    fun interceptionOnlyTargetsSelectedPackagesAndStopsAfterRelease() {
        val mode =
            BlockMode(
                name = "Work",
                isDefault = true,
                targets =
                    persistentListOf(
                        BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"),
                        BlockingTarget("chrome", "Chrome", TargetKind.BROWSER, "com.android.chrome")
                    )
            )
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val repository =
            InMemoryAppRepository(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true),
                    anchors = persistentListOf(anchor),
                    modes = persistentListOf(mode),
                    selectedModeId = mode.id,
                    activeSession = ActiveSession(modeId = mode.id, anchorId = anchor.id, state = SessionState.ARMED)
                )
            )

        val blockedSlack = blockingInterceptionForPackage(repository.state.value, "com.slack")
        assertNotNull(blockedSlack)
        assertEquals("Slack", blockedSlack?.targetLabel)
        assertEquals("Work", blockedSlack?.modeName)
        assertEquals(sessionId(repository.state.value), blockedSlack?.sessionId)
        assertEquals(armedAt(repository.state.value), blockedSlack?.sessionStartedAt)
        assertTrue(shouldInterceptPackage(repository.state.value, "com.android.chrome"))
        assertFalse(shouldInterceptPackage(repository.state.value, "com.discord"))

        val wrongAnchorResult = repository.releaseSession("wrong-anchor")
        assertTrue(wrongAnchorResult is dev.micr.ancla.model.SessionActionResult.ValidationError)
        assertTrue(shouldInterceptPackage(repository.state.value, "com.slack"))

        val released = repository.releaseSession("anchor-alpha")
        assertTrue(released is dev.micr.ancla.model.SessionActionResult.Released)
        assertFalse(shouldInterceptPackage(repository.state.value, "com.slack"))
        assertFalse(shouldInterceptPackage(repository.state.value, "com.android.chrome"))
    }

    @Test
    fun temporaryUnlockSuppressesInterceptionOnlyInsideActiveWindow() {
        val now = Instant.parse("2026-04-12T10:01:00Z")
        val mode =
            BlockMode(
                name = "Work",
                isDefault = true,
                targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
            )
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val session =
            ActiveSession(
                modeId = mode.id,
                anchorId = anchor.id,
                state = SessionState.WRONG_ANCHOR,
                resolvedTargets = mode.targets,
                armedAt = Instant.parse("2026-04-12T10:00:00Z")
            )
        val state =
            AppState(
                blockingAuthorized = true,
                setup = AppSetupState(blockingToolsAcknowledged = true),
                anchors = persistentListOf(anchor),
                modes = persistentListOf(mode),
                selectedModeId = mode.id,
                activeSession = session,
                temporaryUnlock = TemporaryUnlockState(
                    reason = "Check 2FA",
                    startedAt = now.minusSeconds(5),
                    expiresAt = now.plusSeconds(55)
                )
            )

        assertFalse(shouldInterceptPackage(state, "com.slack", now))
        assertTrue(shouldInterceptPackage(state.copy(temporaryUnlock = null), "com.slack", now))
        assertTrue(shouldInterceptPackage(state, "com.slack", now.plusSeconds(56)))
    }

    @Test
    fun snapshotPayloadPreservesSessionStartForServiceRestoration() {
        val armedAt = Instant.parse("2026-04-12T10:00:00Z")
        val mode =
            BlockMode(
                name = "Work",
                isDefault = true,
                targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
            )
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val sessionId = UUID.fromString("44444444-4444-4444-4444-444444444444")
        val state =
            AppState(
                blockingAuthorized = true,
                setup = AppSetupState(blockingToolsAcknowledged = true),
                anchors = persistentListOf(anchor),
                modes = persistentListOf(mode),
                selectedModeId = mode.id,
                activeSession = ActiveSession(
                    id = sessionId,
                    modeId = mode.id,
                    anchorId = anchor.id,
                    state = SessionState.ARMED,
                    resolvedTargets = mode.targets,
                    armedAt = armedAt
                )
            )

        val payload = dev.micr.ancla.model.AccessibilityBlockingSnapshotPayload.fromState(state)

        assertEquals(sessionId, payload.sessionId)
        assertEquals(armedAt, payload.sessionStartedAt)
        assertEquals(armedAt, payload.interceptionFor("com.slack")?.sessionStartedAt)
    }

    @Test
    fun unlockPresetActivationExpiryAndScheduleEvaluationPreserveSameSession() {
        val now = Instant.parse("2026-04-14T10:00:00Z")
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val mode =
            BlockMode(
                name = "Focus",
                isDefault = true,
                targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
            )
        val schedule =
            dev.micr.ancla.model.ScheduledSessionPlan(
                modeId = mode.id,
                anchorId = anchor.id,
                weekdayNumbers = persistentListOf(3),
                startMinuteOfDay = 9 * 60,
                endMinuteOfDay = 11 * 60,
                isEnabled = true
            )
        val preset = dev.micr.ancla.model.UnlockPreset(title = "Check 2FA", detail = "Open Messages.", durationSeconds = 60)
        val repository =
            InMemoryAppRepository(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true),
                    anchors = persistentListOf(anchor),
                    modes = persistentListOf(mode),
                    selectedModeId = mode.id,
                    scheduledPlans = persistentListOf(schedule),
                    unlockPresets = persistentListOf(preset)
                )
            )

        repository.evaluateSchedules(now)
        val startedSession = requireNotNull(repository.state.value.activeSession)
        assertEquals(schedule.id, startedSession.scheduleId)
        assertTrue(blockedPresentationIsActive(repository.state.value, now))

        val activated = repository.activateUnlockPreset(preset.id, now.plusSeconds(5))
        assertTrue(activated is dev.micr.ancla.model.UnlockPresetActivationResult.Activated)
        assertFalse(blockedPresentationIsActive(repository.state.value, now.plusSeconds(10)))
        assertEquals(startedSession.id, repository.state.value.activeSession?.id)
        assertEquals(startedSession.anchorId, repository.state.value.activeSession?.anchorId)
        assertEquals(startedSession.modeId, repository.state.value.activeSession?.modeId)

        repository.expireTemporaryUnlock(now.plusSeconds(70))
        assertTrue(blockedPresentationIsActive(repository.state.value, now.plusSeconds(70)))
        assertEquals(startedSession.id, repository.state.value.activeSession?.id)

        repository.evaluateSchedules(now.plusSeconds(2 * 60 * 60))
        assertEquals(null, repository.state.value.activeSession)
        assertEquals(dev.micr.ancla.model.ReleaseMethod.SCHEDULE, repository.state.value.sessionHistory.single().releaseMethod)
        assertEquals(startedSession.id, repository.state.value.sessionHistory.single().sessionId)
    }

    @Test
    fun deletingActivePresetClearsTemporaryUnlockButKeepsLiveSessionBlocking() {
        val now = Instant.parse("2026-04-14T10:00:00Z")
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val mode =
            BlockMode(
                name = "Focus",
                isDefault = true,
                targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
            )
        val preset = dev.micr.ancla.model.UnlockPreset(title = "Check 2FA", detail = "Open Messages.", durationSeconds = 60)
        val repository =
            InMemoryAppRepository(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true),
                    anchors = persistentListOf(anchor),
                    modes = persistentListOf(mode),
                    selectedModeId = mode.id,
                    unlockPresets = persistentListOf(preset),
                    activeSession = ActiveSession(modeId = mode.id, anchorId = anchor.id, state = SessionState.WRONG_ANCHOR)
                )
            )

        repository.activateUnlockPreset(preset.id, now)
        assertFalse(blockedPresentationIsActive(repository.state.value, now.plusSeconds(1)))

        repository.deleteUnlockPreset(preset.id)

        assertEquals(null, repository.state.value.temporaryUnlock)
        assertNotNull(repository.state.value.activeSession)
        assertTrue(blockedPresentationIsActive(repository.state.value, now.plusSeconds(2)))
        assertTrue(repository.state.value.sessionHistory.isEmpty())
    }

    @Test
    fun nextScheduleTransitionTracksUpcomingStartThenActiveEnd() {
        val now = Instant.parse("2026-04-13T10:00:30Z")
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val mode =
            BlockMode(
                name = "Focus",
                isDefault = true,
                targets = persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
            )
        val schedule =
            dev.micr.ancla.model.ScheduledSessionPlan(
                modeId = mode.id,
                anchorId = anchor.id,
                weekdayNumbers = persistentListOf(2),
                startMinuteOfDay = 10 * 60 + 1,
                endMinuteOfDay = 10 * 60 + 3,
                isEnabled = true
            )
        val baseState =
            AppState(
                blockingAuthorized = true,
                setup = AppSetupState(blockingToolsAcknowledged = true),
                anchors = persistentListOf(anchor),
                modes = persistentListOf(mode),
                selectedModeId = mode.id,
                scheduledPlans = persistentListOf(schedule)
            )

        assertEquals(
            Instant.parse("2026-04-13T10:01:00Z"),
            nextScheduleTransitionAt(baseState, now)
        )

        val activeState =
            baseState.copy(
                activeSession = ActiveSession(
                    modeId = mode.id,
                    anchorId = anchor.id,
                    state = SessionState.ARMED,
                    armedAt = Instant.parse("2026-04-13T10:01:00Z"),
                    scheduleId = schedule.id
                )
            )

        assertEquals(
            Instant.parse("2026-04-13T10:03:00Z"),
            nextScheduleTransitionAt(activeState, Instant.parse("2026-04-13T10:01:30Z"))
        )
    }

    @Test
    fun browserstackScheduleSeededStateWrapsLateNightRunsIntoNextDay() {
        val lateNight = Instant.parse("2026-04-17T23:58:30Z")

        val state = browserstackScheduleSeededAppState(lateNight)

        assertEquals(null, state.activeSession)
        assertEquals(1, state.scheduledPlans.size)
        assertEquals(
            Instant.parse("2026-04-18T00:00:00Z"),
            nextScheduleTransitionAt(state, lateNight)
        )
    }

    private fun sessionId(state: AppState) = requireNotNull(state.activeSession).id

    private fun armedAt(state: AppState) = requireNotNull(state.activeSession).armedAt

}
