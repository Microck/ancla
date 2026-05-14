package dev.micr.ancla

import dev.micr.ancla.model.AppSetupState
import dev.micr.ancla.model.AppState
import dev.micr.ancla.model.BlockMode
import dev.micr.ancla.model.BlockingTarget
import dev.micr.ancla.model.InMemoryAppRepository
import dev.micr.ancla.model.ModeDraft
import dev.micr.ancla.model.PairedAnchor
import dev.micr.ancla.model.ScheduleDraft
import dev.micr.ancla.model.SessionActionResult
import dev.micr.ancla.model.TargetKind
import dev.micr.ancla.model.UnlockPresetDraft
import dev.micr.ancla.model.modeSummary
import dev.micr.ancla.model.readinessState
import dev.micr.ancla.model.startGateState
import java.io.File
import java.time.Instant
import kotlinx.collections.immutable.persistentListOf
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FinalUserSurfaceEvidenceTest {
    @Test
    fun foundationArtifactMatchesCurrentSetupAndModeSurface() {
        val artifact = readArtifact("foundation-setup-modes-user-testing.json")
        val readyState = readyFoundationState()
        val missingAnchorState = readyState.copy(anchors = persistentListOf())
        val missingModeState = readyState.copy(modes = persistentListOf(), selectedModeId = null)
        val nfcUnavailableState = readyState.copy(nfcAvailable = false)

        assertTrue(artifact.contains("\"featureId\": \"capture-foundation-setup-modes-user-testing-evidence\""))
        assertTrue(artifact.contains("\"VAL-SETUP-001\""))
        assertTrue(artifact.contains("\"VAL-MODES-015\""))
        assertTrue(artifact.contains("\"VAL-CROSS-001\""))
        assertTrue(artifact.contains("Finish Android setup"))
        assertTrue(artifact.contains("No Screen Time or Shortcuts are involved on Android."))
        assertTrue(artifact.contains(readinessState(readyState).headline))
        assertTrue(artifact.contains(readinessState(nfcUnavailableState).headline))
        assertTrue(artifact.contains(startGateState(missingAnchorState).reason))
        assertTrue(artifact.contains(startGateState(missingModeState).reason))
        assertTrue(artifact.contains(modeSummary(requireNotNull(readyState.modes.firstOrNull()))))
        assertTrue(artifact.contains("Selected mode: Focus"))
        assertTrue(artifact.contains("Active mode: Focus"))
    }

    @Test
    fun nfcArtifactMatchesCurrentAnchorBindingAndReleaseBehavior() {
        val artifact = readArtifact("nfc-anchor-session-user-testing.json")
        val repository =
            InMemoryAppRepository(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true)
                )
            )

        repository.pairAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        repository.pairAnchor(uid = "anchor-bravo", displayName = "Door anchor")
        val modeId =
            (repository.saveMode(
                ModeDraft(
                    name = "Focus",
                    selectedTargetIds = setOf("com.slack", "com.android.chrome"),
                    isDefault = true
                )
            ) as dev.micr.ancla.model.ModeDraftResult.Saved).modeId
        repository.selectMode(modeId)

        assertEquals(SessionActionResult.Started, repository.armSession("anchor-bravo"))
        val wrongAnchor = repository.releaseSession("anchor-alpha")
        val correctAnchor = repository.releaseSession("anchor-bravo")

        assertTrue(artifact.contains("\"featureId\": \"capture-nfc-anchor-session-user-testing-evidence\""))
        assertTrue(artifact.contains("\"VAL-ANCHOR-001\""))
        assertTrue(artifact.contains("\"VAL-MODES-012\""))
        assertTrue(artifact.contains("\"VAL-CROSS-004\""))
        assertTrue(artifact.contains("Desk anchor"))
        assertTrue(artifact.contains("Door anchor"))
        assertTrue(artifact.contains("That NFC anchor is not paired."))
        assertTrue(artifact.contains("Wrong anchor scanned. The same session is still blocking and can be retried"))
        assertTrue(artifact.contains("Released via Door anchor"))
        assertTrue(artifact.contains("Reason: Anchor"))
        assertTrue(wrongAnchor is SessionActionResult.ValidationError)
        assertTrue(correctAnchor is SessionActionResult.Released)
    }

    @Test
    fun schedulesUnlocksArtifactMatchesCurrentUnlockAndHistorySurface() {
        val artifact = readArtifact("schedules-unlocks-history-user-testing.json")
        val repository =
            InMemoryAppRepository(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true)
                )
            )

        repository.pairAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        repository.pairAnchor(uid = "anchor-bravo", displayName = "Door anchor")
        val focusModeId =
            (repository.saveMode(
                ModeDraft(
                    name = "Focus",
                    selectedTargetIds = setOf("com.slack", "com.android.chrome"),
                    isDefault = true
                )
            ) as dev.micr.ancla.model.ModeDraftResult.Saved).modeId
        repository.selectMode(focusModeId)
        val presetId =
            (repository.saveUnlockPreset(
                UnlockPresetDraft(
                    title = "Check 2FA",
                    detail = "Open Messages long enough to read a code.",
                    durationSeconds = 60
                )
            ) as dev.micr.ancla.model.UnlockPresetDraftResult.Saved).presetId
        repository.saveSchedule(
            ScheduleDraft(
                modeId = focusModeId,
                anchorId = repository.state.value.anchors.first().id,
                weekdayNumbers = setOf(2, 3, 4, 5, 6),
                startMinuteOfDay = 9 * 60,
                endMinuteOfDay = 17 * 60
            )
        )

        val mondayMorning = Instant.parse("2026-04-13T09:15:00Z")
        repository.evaluateSchedules(mondayMorning)
        repository.activateUnlockPreset(presetId, mondayMorning.plusSeconds(5))
        repository.expireTemporaryUnlock(mondayMorning.plusSeconds(70))
        repository.releaseSession("anchor-alpha")

        repository.armSession("anchor-alpha")
        repository.useEmergencyUnbrick(mondayMorning.plusSeconds(90))

        repeat(4) { index ->
            repository.armSession("anchor-alpha")
            repository.useEmergencyUnbrick(mondayMorning.plusSeconds(100L + index))
        }
        repository.armSession("anchor-alpha")
        val failedChallenge = repository.submitParagraphChallenge("wrong", mondayMorning.plusSeconds(200))
        val passage = repository.state.value.paragraphChallenges.first().passage
        val successfulChallenge = repository.submitParagraphChallenge(passage, mondayMorning.plusSeconds(210))

        assertTrue(artifact.contains("\"featureId\": \"capture-schedules-unlocks-history-user-testing-evidence\""))
        assertTrue(artifact.contains("\"VAL-BLOCK-008\""))
        assertTrue(artifact.contains("\"VAL-BLOCK-009\""))
        assertTrue(artifact.contains("\"VAL-SCHEDULE-008\""))
        assertTrue(artifact.contains("\"VAL-UNLOCK-012\""))
        assertTrue(artifact.contains("\"VAL-CROSS-008\""))
        assertTrue(artifact.contains("Unlock options"))
        assertTrue(artifact.contains("Temporary unlock active for 60s more. The same session will re-block when this ends."))
        assertTrue(artifact.contains("Use emergency unbrick (4 left)"))
        assertTrue(artifact.contains("Type the failsafe passage"))
        assertTrue(artifact.contains("Reason: Schedule"))
        assertTrue(artifact.contains("Reason: Emergency unbrick"))
        assertTrue(artifact.contains("Reason: Paragraph challenge"))
        assertTrue(failedChallenge is SessionActionResult.ValidationError)
        assertTrue(successfulChallenge is SessionActionResult.Released)
    }

    private fun readyFoundationState(): AppState {
        val mode =
            BlockMode(
                name = "Focus",
                isDefault = true,
                targets =
                    persistentListOf(
                        BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"),
                        BlockingTarget("chrome", "Chrome", TargetKind.BROWSER, "com.android.chrome")
                    )
            )
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        return AppState(
            blockingAuthorized = true,
            setup = AppSetupState(blockingToolsAcknowledged = true),
            anchors = persistentListOf(anchor),
            modes = persistentListOf(mode),
            selectedModeId = mode.id
        )
    }

    private fun readArtifact(name: String): String =
        File("../../.factory/validation/final-user-testing/user-testing/flows/$name").readText()
}
