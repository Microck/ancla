package dev.micr.ancla.model

import java.util.UUID
import kotlinx.collections.immutable.PersistentList
import kotlinx.collections.immutable.persistentListOf
import java.time.Instant

enum class ReadinessStatus {
    READY,
    ACTION_REQUIRED,
    BLOCKED
}

enum class TargetKind {
    APP,
    BROWSER
}

enum class BlockScope {
    ONLY_SELECTED,
    ALL_EXCEPT_SELECTED,
    ALL_APPS
}

data class BlockingTarget(
    val id: String,
    val label: String,
    val kind: TargetKind = TargetKind.APP,
    val packageName: String
)

data class BlockMode(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val scope: BlockScope = BlockScope.ONLY_SELECTED,
    val targets: PersistentList<BlockingTarget>,
    val isDefault: Boolean = false
)

data class PairedAnchor(
    val id: UUID = UUID.randomUUID(),
    val uid: String,
    val displayName: String
)

enum class SessionState {
    ARMED,
    WRONG_ANCHOR
}

data class ActiveSession(
    val id: UUID = UUID.randomUUID(),
    val modeId: UUID,
    val anchorId: UUID,
    val state: SessionState,
    val resolvedTargets: PersistentList<BlockingTarget> = persistentListOf(),
    val armedAt: Instant = Instant.now(),
    val scheduleId: UUID? = null
)

data class TemporaryUnlockState(
    val presetId: UUID? = null,
    val reason: String,
    val startedAt: Instant,
    val expiresAt: Instant
)

enum class ReleaseMethod {
    ANCHOR,
    SCHEDULE,
    EMERGENCY_UNBRICK,
    PARAGRAPH_CHALLENGE
}

data class ParagraphChallenge(
    val id: UUID = UUID.randomUUID(),
    val title: String,
    val passage: String,
    val createdAt: Instant = Instant.now()
)

data class UnlockPreset(
    val id: UUID = UUID.randomUUID(),
    val title: String,
    val detail: String,
    val durationSeconds: Int
)

data class ScheduledSessionPlan(
    val id: UUID = UUID.randomUUID(),
    val modeId: UUID,
    val anchorId: UUID,
    val weekdayNumbers: PersistentList<Int>,
    val startMinuteOfDay: Int,
    val endMinuteOfDay: Int,
    val isEnabled: Boolean = true,
    val lastStartedDayKey: String? = null,
    val lastEndedDayKey: String? = null
)

data class SessionHistoryEntry(
    val id: UUID = UUID.randomUUID(),
    val sessionId: UUID,
    val anchorId: UUID,
    val anchorName: String,
    val modeId: UUID,
    val modeName: String,
    val armedAt: Instant,
    val releasedAt: Instant,
    val releaseMethod: ReleaseMethod
)

data class AppSetupState(
    val blockingToolsAcknowledged: Boolean = false
)

enum class SetupDestination {
    BLOCKING_PERMISSION,
    ANCHOR,
    MODE,
    COMPLETE
}

data class BlockingInterception(
    val packageName: String,
    val targetId: String,
    val targetLabel: String,
    val targetKind: TargetKind,
    val modeName: String,
    val anchorName: String,
    val sessionId: UUID,
    val sessionState: SessionState,
    val sessionStartedAt: Instant
)

data class AppState(
    val blockingAuthorized: Boolean = false,
    val storageAvailable: Boolean = true,
    val nfcAvailable: Boolean = true,
    val setup: AppSetupState = AppSetupState(),
    val anchors: PersistentList<PairedAnchor> = persistentListOf(),
    val modes: PersistentList<BlockMode> = persistentListOf(),
    val selectedModeId: UUID? = null,
    val activeSession: ActiveSession? = null,
    val scheduledPlans: PersistentList<ScheduledSessionPlan> = persistentListOf(),
    val unlockPresets: PersistentList<UnlockPreset> = persistentListOf(),
    val temporaryUnlock: TemporaryUnlockState? = null,
    val sessionHistory: PersistentList<SessionHistoryEntry> = persistentListOf(),
    val emergencyUnbricksRemaining: Int = 5,
    val paragraphChallengeEnabled: Boolean = true,
    val paragraphChallenges: PersistentList<ParagraphChallenge> = defaultParagraphChallenges()
)

fun PersistentList<PairedAnchor>.anchorSummary(): String =
    when (size) {
        0 -> "No anchors paired yet."
        1 -> "${first().displayName} paired."
        else -> "$size anchors paired."
    }

fun PersistentList<BlockMode>.modeSummaryLine(): String =
    when (size) {
        0 -> "No modes saved yet."
        1 -> "${first().name} ready."
        else -> "$size modes saved."
    }

fun defaultParagraphChallenges(): PersistentList<ParagraphChallenge> =
    persistentListOf(
        ParagraphChallenge(
            title = "Deliberate focus",
            passage = "Attention drifts toward the nearest open door, even when the work in front of you is the work you chose. A locked boundary is not punishment. It is a promise that the next impulse does not get to outrank the longer intention."
        ),
        ParagraphChallenge(
            title = "Convenience is not freedom",
            passage = "The fastest option is rarely the most deliberate one. Real freedom is the ability to keep a commitment after the novelty has burned off, the message can wait, and the mind starts bargaining for an easier hour than the one it already asked for."
        )
    )
