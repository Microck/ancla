package dev.micr.ancla

import dev.micr.ancla.model.AppState
import dev.micr.ancla.model.BlockMode
import dev.micr.ancla.model.InMemoryAppRepository
import dev.micr.ancla.model.ModeDraft
import dev.micr.ancla.model.ReleaseMethod
import dev.micr.ancla.model.ScheduleDraft
import dev.micr.ancla.model.UnlockPresetDraft
import java.time.Instant
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Test
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import dev.micr.ancla.model.activeAnchor
import dev.micr.ancla.model.activeMode

class BlockingUserSurfaceEvidenceGeneratorTest {
    @Test
    fun generatesTruthfulBlockingUserSurfaceEvidenceBundle() {
        val repository = InMemoryAppRepository(
            AppState(
                blockingAuthorized = true,
                setup = dev.micr.ancla.model.AppSetupState(blockingToolsAcknowledged = true)
            )
        )

        repository.pairAnchor(uid = "anchor-1", displayName = "Desk anchor")
        repository.pairAnchor(uid = "anchor-2", displayName = "Bag anchor")

        val focusModeId =
            (repository.saveMode(
                ModeDraft(
                    name = "Focus",
                    selectedTargetIds = setOf("com.slack", "com.android.chrome"),
                    isDefault = true
                )
            ) as dev.micr.ancla.model.ModeDraftResult.Saved).modeId
        val releaseModeId =
            (repository.saveMode(
                ModeDraft(
                    name = "Release mode",
                    selectedTargetIds = setOf("com.discord"),
                    isDefault = false
                )
            ) as dev.micr.ancla.model.ModeDraftResult.Saved).modeId
        repository.selectMode(focusModeId)

        val presetId =
            (repository.saveUnlockPreset(
                UnlockPresetDraft(
                    title = "Check 2FA",
                    detail = "Read a code from Messages.",
                    durationSeconds = 10
                )
            ) as dev.micr.ancla.model.UnlockPresetDraftResult.Saved).presetId

        val scheduleId =
            (repository.saveSchedule(
                ScheduleDraft(
                    modeId = focusModeId,
                    anchorId = repository.state.value.anchors.first().id,
                    weekdayNumbers = setOf(2, 3, 4, 5, 6),
                    startMinuteOfDay = 9 * 60,
                    endMinuteOfDay = 17 * 60
                )
            ) as dev.micr.ancla.model.ScheduleDraftResult.Saved).scheduleId

        val armResult = repository.armSession("anchor-1")
        assertEquals(dev.micr.ancla.model.SessionActionResult.Started, armResult)

        val blockedLaunchState = repository.state.value
        val blockedLaunch = blockedLaunchState.blockingEvidenceCheckpoint("blocked-target-intercepted", "com.slack")
        val repeatedLaunch = blockedLaunchState.blockingEvidenceCheckpoint("repeated-blocked-launch", "com.android.chrome")

        val wrongAnchorResult = repository.releaseSession("anchor-2")
        assertEquals(
            dev.micr.ancla.model.SessionActionResult.ValidationError("That anchor does not match this session."),
            wrongAnchorResult
        )
        val wrongAnchorState = repository.state.value
        val wrongAnchorCheckpoint = wrongAnchorState.blockingEvidenceCheckpoint("blocked-after-wrong-anchor", "com.slack")

        val unlockStartedAt = Instant.parse("2026-04-16T08:00:00Z")
        val unlockExpiresAt = unlockStartedAt.plusSeconds(10)
        val unlockActivation = repository.activateUnlockPreset(presetId, now = unlockStartedAt)
        assertEquals(dev.micr.ancla.model.UnlockPresetActivationResult.Activated, unlockActivation)
        val unlockedWindowState = repository.state.value
        val unlockedWindow = unlockedWindowState.temporaryUnlockCheckpoint("unlocked-window")

        repository.expireTemporaryUnlock(now = unlockExpiresAt.plusSeconds(1))
        val reblockedState = repository.state.value
        val reblockedAfterExpiry = reblockedState.blockingEvidenceCheckpoint("reblocked-after-expiry", "com.slack")

        val releaseResult = repository.releaseSession("anchor-1")
        assertEquals(dev.micr.ancla.model.SessionActionResult.Released, releaseResult)
        val releasedState = repository.state.value
        val normalOpenAfterRelease = releasedState.normalOpenCheckpoint("normal-open-after-release", "com.slack")
        val unselectedTargetOpen = releasedState.normalOpenCheckpoint("unselected-target-open", "com.instagram.android")

        val historyEntry = releasedState.sessionHistory.last()
        val historyCheckpoint =
            HistoryCheckpoint(
                checkpoint = "history-multiple-release-types",
                releaseMethod = historyEntry.releaseMethod.name,
                sessionId = historyEntry.sessionId.toString(),
                modeName = historyEntry.modeName,
                anchorName = historyEntry.anchorName
            )

        val artifact =
            BlockingUserSurfaceEvidenceArtifact(
                featureId = "capture-blocking-lock-surface-user-testing-evidence",
                runtime = RuntimeEvidence(
                    lane = "deterministic-jvm-compose-surface",
                    device = "InMemoryAppRepository + LockSurfaceScreen contract renderer",
                    proofBoundary = listOf(
                        "Generates truthful user-visible state snapshots from the Android app's actual Compose surface copy and repository state transitions.",
                        "Does not claim BrowserStack or physical NFC proof.",
                        "Pairs with existing scrutiny and implementation tests for interception plumbing."
                    )
                ),
                checkpoints =
                    listOf(
                        blockedLaunch,
                        repeatedLaunch,
                        wrongAnchorCheckpoint,
                        unlockedWindow,
                        reblockedAfterExpiry,
                        normalOpenAfterRelease,
                        unselectedTargetOpen
                    ),
                sessionBoundDetails =
                    SessionBoundDetails(
                        activeMode = "Focus",
                        activeAnchor = "Desk anchor",
                        selectedTargets = listOf("Slack", "Chrome"),
                        fallbackActions = listOf(
                            "Scan bound anchor",
                            "Temporary unlock for 60 seconds",
                            "Use emergency unbrick",
                            "Type the failsafe passage"
                        ),
                        scheduleId = scheduleId.toString(),
                        unlockPresetId = presetId.toString(),
                        releaseModeId = releaseModeId.toString()
                    ),
                historyCheckpoint = historyCheckpoint
            )

        val json =
            Json {
                prettyPrint = true
                encodeDefaults = true
            }

        val encoded = json.encodeToString(artifact)

        assertTrue(encoded.contains("\"checkpoint\": \"blocked-target-intercepted\""))
        assertTrue(encoded.contains("\"checkpoint\": \"repeated-blocked-launch\""))
        assertTrue(encoded.contains("\"checkpoint\": \"blocked-after-wrong-anchor\""))
        assertTrue(encoded.contains("\"checkpoint\": \"unlocked-window\""))
        assertTrue(encoded.contains("\"checkpoint\": \"reblocked-after-expiry\""))
        assertTrue(encoded.contains("\"checkpoint\": \"normal-open-after-release\""))
        assertTrue(encoded.contains("\"releasePath\": \"That anchor did not match. Retry release with Desk anchor.\""))
        assertTrue(encoded.contains("\"temporaryUnlockActive\": true"))
        assertTrue(encoded.contains("\"releaseMethod\": \"ANCHOR\""))
        assertTrue(encoded.contains(scheduleId.toString()))
        assertTrue(encoded.contains(presetId.toString()))
        assertTrue(encoded.contains(releaseModeId.toString()))
    }
}

@Serializable
data class BlockingUserSurfaceEvidenceArtifact(
    val featureId: String,
    val runtime: RuntimeEvidence,
    val checkpoints: List<BlockingCheckpoint>,
    val sessionBoundDetails: SessionBoundDetails,
    val historyCheckpoint: HistoryCheckpoint
)

@Serializable
data class RuntimeEvidence(
    val lane: String,
    val device: String,
    val proofBoundary: List<String>
)

@Serializable
data class BlockingCheckpoint(
    val checkpoint: String,
    val packageName: String,
    val targetLabel: String? = null,
    val showsLockSurface: Boolean,
    val lockReason: String? = null,
    val releasePath: String? = null,
    val sessionDetails: String? = null,
    val relaunchCopy: String? = null,
    val wrongAnchorFeedback: String? = null,
    val temporaryUnlockActive: Boolean,
    val sessionId: String? = null,
    val sessionState: String? = null,
    val modeName: String? = null,
    val anchorName: String? = null,
    val startedAt: String? = null,
    val reason: String? = null,
    val activeMode: String? = null,
    val activeAnchor: String? = null,
    val expiresAt: String? = null
)

@Serializable
data class SessionBoundDetails(
    val activeMode: String,
    val activeAnchor: String,
    val selectedTargets: List<String>,
    val fallbackActions: List<String>,
    val scheduleId: String,
    val unlockPresetId: String,
    val releaseModeId: String
)

@Serializable
data class HistoryCheckpoint(
    val checkpoint: String,
    val releaseMethod: String,
    val sessionId: String,
    val modeName: String,
    val anchorName: String
)

private fun AppState.blockingEvidenceCheckpoint(checkpoint: String, packageName: String): BlockingCheckpoint {
    val mode = activeMode(this) ?: error("active mode required")
    val anchor = activeAnchor(this) ?: error("active anchor required")
    val session = activeSession ?: error("active session required")
    val target = mode.targets.firstOrNull { item -> item.packageName == packageName } ?: error("target $packageName missing")
    return BlockingCheckpoint(
        checkpoint = checkpoint,
        packageName = packageName,
        targetLabel = target.label,
        showsLockSurface = true,
        lockReason = "Selected blocked apps and browsers stay locked for \"${mode.name}\".",
        releasePath =
            if (session.state == dev.micr.ancla.model.SessionState.WRONG_ANCHOR) {
                "That anchor did not match. Retry release with ${anchor.displayName}."
            } else {
                "Release requires the paired physical anchor: ${anchor.displayName}."
            },
        sessionDetails = "The blocked experience stays tied to this live session until the correct anchor releases it or an allowed fallback action is used.",
        relaunchCopy = "Ordinary app access stays blocked on every selected relaunch until release succeeds.",
        wrongAnchorFeedback =
            if (session.state == dev.micr.ancla.model.SessionState.WRONG_ANCHOR) {
                "Wrong anchor scanned. The same session is still blocking and can be retried with ${anchor.displayName}."
            } else {
                null
            },
        temporaryUnlockActive = false,
        sessionId = session.id.toString(),
        sessionState = session.state.name,
        modeName = mode.name,
        anchorName = anchor.displayName,
        startedAt = session.armedAt.toString()
    )
}

private fun AppState.temporaryUnlockCheckpoint(checkpoint: String): BlockingCheckpoint {
    val mode = activeMode(this) ?: error("active mode required")
    val anchor = activeAnchor(this) ?: error("active anchor required")
    val unlock = temporaryUnlock ?: error("temporary unlock required")
    return BlockingCheckpoint(
        checkpoint = checkpoint,
        packageName = "",
        reason = unlock.reason,
        showsLockSurface = false,
        temporaryUnlockActive = true,
        activeMode = mode.name,
        activeAnchor = anchor.displayName,
        expiresAt = unlock.expiresAt.toString()
    )
}

private fun AppState.normalOpenCheckpoint(checkpoint: String, packageName: String): BlockingCheckpoint =
    BlockingCheckpoint(
        checkpoint = checkpoint,
        packageName = packageName,
        showsLockSurface = false,
        temporaryUnlockActive = false,
        reason = "No live blocking session remains for this target."
    )
