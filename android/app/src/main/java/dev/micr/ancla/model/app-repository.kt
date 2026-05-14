package dev.micr.ancla.model

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStoreFile
import java.util.UUID
import kotlinx.collections.immutable.PersistentList
import kotlinx.collections.immutable.persistentListOf
import kotlinx.collections.immutable.toPersistentList
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.IOException

data class ModeDraft(
    val id: UUID? = null,
    val name: String = "",
    val scope: BlockScope = BlockScope.ONLY_SELECTED,
    val selectedTargetIds: Set<String> = emptySet(),
    val isDefault: Boolean = false
)

data class ScheduleDraft(
    val id: UUID? = null,
    val modeId: UUID? = null,
    val anchorId: UUID? = null,
    val weekdayNumbers: Set<Int> = emptySet(),
    val startMinuteOfDay: Int = 9 * 60,
    val endMinuteOfDay: Int = 17 * 60,
    val isEnabled: Boolean = true
)

data class UnlockPresetDraft(
    val id: UUID? = null,
    val title: String = "",
    val detail: String = "",
    val durationSeconds: Int = 60
)

interface AppRepository {
    val state: StateFlow<AppState>

    fun availableBlockingTargets(): List<BlockingTarget>

    fun acknowledgeBlockingSetup()

    fun setBlockingAuthorization(isAuthorized: Boolean)

    fun setStorageAvailability(isAvailable: Boolean)

    fun setNfcAvailability(isAvailable: Boolean)

    fun pairAnchor(uid: String, displayName: String = "")

    fun renameAnchor(anchorId: UUID, displayName: String)

    fun removeAnchor(anchorId: UUID)

    fun selectMode(modeId: UUID)

    fun saveMode(draft: ModeDraft): ModeDraftResult

    fun deleteMode(modeId: UUID)

    fun armSession(scannedAnchorUid: String): SessionActionResult

    fun releaseSession(scannedAnchorUid: String): SessionActionResult

    fun useEmergencyUnbrick(now: java.time.Instant = java.time.Instant.now()): SessionActionResult

    fun submitParagraphChallenge(typedPassage: String, now: java.time.Instant = java.time.Instant.now()): SessionActionResult

    fun adjustEmergencyUnbricks(delta: Int)

    fun setParagraphChallengeEnabled(isEnabled: Boolean)

    fun saveSchedule(draft: ScheduleDraft): ScheduleDraftResult

    fun deleteSchedule(scheduleId: UUID)

    fun evaluateSchedules(now: java.time.Instant = java.time.Instant.now())

    fun saveUnlockPreset(draft: UnlockPresetDraft): UnlockPresetDraftResult

    fun deleteUnlockPreset(presetId: UUID)

    fun activateUnlockPreset(presetId: UUID, now: java.time.Instant = java.time.Instant.now()): UnlockPresetActivationResult

    fun activateTemporaryUnlock(reason: String, durationSeconds: Int)

    fun expireTemporaryUnlock(now: java.time.Instant = java.time.Instant.now())
}

sealed interface ModeDraftResult {
    data class Saved(val modeId: UUID) : ModeDraftResult

    data class ValidationError(val message: String) : ModeDraftResult
}

sealed interface SessionActionResult {
    data object Started : SessionActionResult

    data object Released : SessionActionResult

    data class ValidationError(val message: String) : SessionActionResult
}

sealed interface ScheduleDraftResult {
    data class Saved(val scheduleId: UUID) : ScheduleDraftResult

    data class ValidationError(val message: String) : ScheduleDraftResult
}

sealed interface UnlockPresetDraftResult {
    data class Saved(val presetId: UUID) : UnlockPresetDraftResult

    data class ValidationError(val message: String) : UnlockPresetDraftResult
}

sealed interface UnlockPresetActivationResult {
    data object Activated : UnlockPresetActivationResult

    data class ValidationError(val message: String) : UnlockPresetActivationResult
}

class InMemoryAppRepository(
    initialState: AppState = AppState(),
    private val installedAppCatalog: InstalledAppCatalog = StaticInstalledAppCatalog()
) : AppRepository {
    private val mutableState = MutableStateFlow(hydrateState(initialState))

    override val state: StateFlow<AppState> = mutableState.asStateFlow()

    override fun availableBlockingTargets(): List<BlockingTarget> = installedAppCatalog.availableTargets()

    override fun acknowledgeBlockingSetup() {
        updateState { current ->
            current.copy(setup = current.setup.copy(blockingToolsAcknowledged = true))
        }
    }

    override fun setBlockingAuthorization(isAuthorized: Boolean) {
        updateState { current ->
            current.copy(blockingAuthorized = isAuthorized)
        }
    }

    override fun setStorageAvailability(isAvailable: Boolean) {
        updateState { current ->
            current.copy(storageAvailable = isAvailable)
        }
    }

    override fun setNfcAvailability(isAvailable: Boolean) {
        updateState { current ->
            current.copy(nfcAvailable = isAvailable)
        }
    }

    override fun pairAnchor(uid: String, displayName: String) {
        updateState { current ->
            if (current.anchors.any { it.uid == uid }) {
                current
            } else {
                val trimmedName = displayName.trim().ifBlank { defaultAnchorName(current.anchors.size) }
                current.copy(
                    anchors = current.anchors.add(PairedAnchor(uid = uid, displayName = trimmedName))
                )
            }
        }
    }

    override fun renameAnchor(anchorId: UUID, displayName: String) {
        updateState { current ->
            val index = current.anchors.indexOfFirst { it.id == anchorId }
            if (index == -1) {
                current
            } else {
                val trimmedName = displayName.trim().ifBlank { "Desk anchor" }
                val updatedAnchors = current.anchors.toMutableList()
                updatedAnchors[index] = updatedAnchors[index].copy(displayName = trimmedName)
                current.copy(
                    anchors = updatedAnchors.toPersistentList(),
                    sessionHistory =
                        current.sessionHistory.map { entry ->
                            if (entry.anchorId == anchorId) entry.copy(anchorName = trimmedName) else entry
                        }.toPersistentList()
                )
            }
        }
    }

    override fun removeAnchor(anchorId: UUID) {
        updateState { current ->
            current.copy(
                anchors = current.anchors.removeAll { it.id == anchorId }.toPersistentList(),
                scheduledPlans = current.scheduledPlans.removeAll { it.anchorId == anchorId }.toPersistentList(),
                activeSession = current.activeSession.takeUnless { it?.anchorId == anchorId },
                temporaryUnlock = if (current.activeSession?.anchorId == anchorId) null else current.temporaryUnlock
            )
        }
    }

    override fun selectMode(modeId: UUID) {
        updateState { current ->
            if (current.modes.none { it.id == modeId }) current else current.copy(selectedModeId = modeId)
        }
    }

    override fun saveMode(draft: ModeDraft): ModeDraftResult {
        val name = draft.name.trim().ifBlank { "Focus mode" }
        val availableTargetsById = availableBlockingTargets().associateBy(BlockingTarget::id)
        val targets =
            draft.selectedTargetIds
                .mapNotNull(availableTargetsById::get)
                .distinctBy(BlockingTarget::packageName)
        if (draft.scope == BlockScope.ONLY_SELECTED && targets.isEmpty()) {
            return ModeDraftResult.ValidationError("Choose at least one app.")
        }
        if (draft.scope == BlockScope.ALL_EXCEPT_SELECTED && targets.isEmpty()) {
            return ModeDraftResult.ValidationError("Choose at least one app to exclude.")
        }

        var resultId: UUID? = null
        updateState { current ->
            val mode = BlockMode(
                id = draft.id ?: UUID.randomUUID(),
                name = name,
                scope = draft.scope,
                targets = targets.toPersistentList(),
                isDefault = draft.isDefault
            )
            resultId = mode.id
            current.copy(
                modes = promoteSingleDefault(current.modes.removeAll { it.id == mode.id }.add(mode).toPersistentList(), mode.id, draft.isDefault),
                selectedModeId = mode.id
            )
        }
        return ModeDraftResult.Saved(requireNotNull(resultId))
    }

    override fun deleteMode(modeId: UUID) {
        updateState { current ->
            current.copy(
                modes = current.modes.removeAll { it.id == modeId }.toPersistentList(),
                selectedModeId = current.selectedModeId.takeUnless { it == modeId },
                scheduledPlans = current.scheduledPlans.removeAll { it.modeId == modeId }.toPersistentList(),
                activeSession = current.activeSession.takeUnless { it?.modeId == modeId },
                temporaryUnlock = if (current.activeSession?.modeId == modeId) null else current.temporaryUnlock
            )
        }
    }

    override fun armSession(scannedAnchorUid: String): SessionActionResult {
        val current = state.value
        val mode = selectedMode(current) ?: preferredMode(current)
            ?: return SessionActionResult.ValidationError("Create a mode before starting.")
        val pairedAnchor = current.anchors.firstOrNull { it.uid == scannedAnchorUid }
            ?: return SessionActionResult.ValidationError("That NFC anchor is not paired.")
        val readinessError = readinessError(current)
        if (readinessError != null) {
            return SessionActionResult.ValidationError(readinessError)
        }
        val resolvedTargets = resolveTargetsForMode(mode)
        if (resolvedTargets.isEmpty()) {
            return SessionActionResult.ValidationError("No installed apps are available to block for this mode.")
        }

        updateState { latest ->
            latest.copy(
                selectedModeId = mode.id,
                temporaryUnlock = null,
                activeSession =
                    ActiveSession(
                        modeId = mode.id,
                        anchorId = pairedAnchor.id,
                        state = SessionState.ARMED,
                        resolvedTargets = resolvedTargets.toPersistentList()
                    )
            )
        }
        return SessionActionResult.Started
    }

    override fun releaseSession(scannedAnchorUid: String): SessionActionResult {
        val current = state.value
        val activeSession = current.activeSession
            ?: return SessionActionResult.ValidationError("No blocking session is active.")
        val boundAnchor = current.anchors.firstOrNull { it.id == activeSession.anchorId }
            ?: return SessionActionResult.ValidationError("The session anchor is missing.")
        if (boundAnchor.uid != scannedAnchorUid) {
            updateState { latest ->
                val latestSession = latest.activeSession ?: return@updateState latest
                latest.copy(activeSession = latestSession.copy(state = SessionState.WRONG_ANCHOR))
            }
            return SessionActionResult.ValidationError("That anchor does not match this session.")
        }
        val mode = current.modes.firstOrNull { it.id == activeSession.modeId }
            ?: return SessionActionResult.ValidationError("The active mode is missing.")
        completeRelease(activeSession, mode, boundAnchor, ReleaseMethod.ANCHOR, java.time.Instant.now())
        return SessionActionResult.Released
    }

    override fun useEmergencyUnbrick(now: java.time.Instant): SessionActionResult {
        val current = state.value
        val activeSession = current.activeSession
            ?: return SessionActionResult.ValidationError("No blocking session is active.")
        if (!canUseEmergencyUnbrick(current)) {
            return SessionActionResult.ValidationError("No emergency unbricks remain.")
        }
        val boundAnchor = current.anchors.firstOrNull { it.id == activeSession.anchorId }
            ?: return SessionActionResult.ValidationError("The session anchor is missing.")
        val mode = current.modes.firstOrNull { it.id == activeSession.modeId }
            ?: return SessionActionResult.ValidationError("The active mode is missing.")
        updateState { latest ->
            completeRelease(latest, activeSession, mode, boundAnchor, ReleaseMethod.EMERGENCY_UNBRICK, now).copy(
                emergencyUnbricksRemaining = (latest.emergencyUnbricksRemaining - 1).coerceAtLeast(0)
            )
        }
        return SessionActionResult.Released
    }

    override fun submitParagraphChallenge(typedPassage: String, now: java.time.Instant): SessionActionResult {
        val current = state.value
        val activeSession = current.activeSession
            ?: return SessionActionResult.ValidationError("No blocking session is active.")
        if (!canUseParagraphChallenge(current)) {
            return SessionActionResult.ValidationError("No paragraph challenge is available for this session.")
        }
        val challenge = current.paragraphChallenges.firstOrNull()
            ?: return SessionActionResult.ValidationError("No paragraph challenge is available for this session.")
        if (normalizedChallengeText(typedPassage) != normalizedChallengeText(challenge.passage)) {
            return SessionActionResult.ValidationError("The typed passage did not match.")
        }
        val boundAnchor = current.anchors.firstOrNull { it.id == activeSession.anchorId }
            ?: return SessionActionResult.ValidationError("The session anchor is missing.")
        val mode = current.modes.firstOrNull { it.id == activeSession.modeId }
            ?: return SessionActionResult.ValidationError("The active mode is missing.")
        completeRelease(activeSession, mode, boundAnchor, ReleaseMethod.PARAGRAPH_CHALLENGE, now)
        return SessionActionResult.Released
    }

    override fun adjustEmergencyUnbricks(delta: Int) {
        updateState { current ->
            current.copy(
                emergencyUnbricksRemaining = (current.emergencyUnbricksRemaining + delta).coerceIn(0, 99)
            )
        }
    }

    override fun setParagraphChallengeEnabled(isEnabled: Boolean) {
        updateState { current ->
            current.copy(paragraphChallengeEnabled = isEnabled)
        }
    }

    override fun saveSchedule(draft: ScheduleDraft): ScheduleDraftResult {
        val modeId = draft.modeId ?: return ScheduleDraftResult.ValidationError("Choose a mode for this schedule.")
        val anchorId = draft.anchorId ?: return ScheduleDraftResult.ValidationError("Choose an anchor for this schedule.")
        val weekdayNumbers = draft.weekdayNumbers.filter { it in 1..7 }.toSortedSet()
        if (weekdayNumbers.isEmpty()) return ScheduleDraftResult.ValidationError("Choose at least one weekday.")
        if (draft.endMinuteOfDay <= draft.startMinuteOfDay) {
            return ScheduleDraftResult.ValidationError("Schedule end time must be after start time.")
        }
        val current = state.value
        if (current.modes.none { it.id == modeId }) return ScheduleDraftResult.ValidationError("Choose a saved mode for this schedule.")
        if (current.anchors.none { it.id == anchorId }) return ScheduleDraftResult.ValidationError("Choose a paired anchor for this schedule.")

        var resultId: UUID? = null
        updateState { latest ->
            val existing = draft.id?.let { scheduleId -> latest.scheduledPlans.firstOrNull { it.id == scheduleId } }
            val schedule = ScheduledSessionPlan(
                id = draft.id ?: UUID.randomUUID(),
                modeId = modeId,
                anchorId = anchorId,
                weekdayNumbers = weekdayNumbers.toPersistentList(),
                startMinuteOfDay = draft.startMinuteOfDay,
                endMinuteOfDay = draft.endMinuteOfDay,
                isEnabled = draft.isEnabled,
                lastStartedDayKey = existing?.lastStartedDayKey,
                lastEndedDayKey = existing?.lastEndedDayKey
            )
            resultId = schedule.id
            latest.copy(
                scheduledPlans = latest.scheduledPlans.removeAll { it.id == schedule.id }.add(schedule).toPersistentList()
            )
        }
        return ScheduleDraftResult.Saved(requireNotNull(resultId))
    }

    override fun deleteSchedule(scheduleId: UUID) {
        updateState { current ->
            val removedSchedule = current.scheduledPlans.firstOrNull { it.id == scheduleId }
            val releasedState =
                if (current.activeSession?.scheduleId == scheduleId && removedSchedule != null) {
                    val mode = current.modes.firstOrNull { it.id == removedSchedule.modeId }
                    val anchor = current.anchors.firstOrNull { it.id == removedSchedule.anchorId }
                    if (mode != null && anchor != null) {
                        completeRelease(current, requireNotNull(current.activeSession), mode, anchor, ReleaseMethod.SCHEDULE, java.time.Instant.now())
                    } else {
                        current.copy(activeSession = null, temporaryUnlock = null)
                    }
                } else {
                    current
                }
            releasedState.copy(
                scheduledPlans = releasedState.scheduledPlans.removeAll { it.id == scheduleId }.toPersistentList()
            )
        }
    }

    override fun evaluateSchedules(now: java.time.Instant) {
        updateState { current ->
            val afterExpiry = expireTemporaryUnlockIfNeeded(current, now)
            val scheduledSession = afterExpiry.activeSession
            val activeSchedule =
                scheduledSession?.scheduleId?.let { scheduleId -> afterExpiry.scheduledPlans.firstOrNull { it.id == scheduleId } }
            if (scheduledSession != null && activeSchedule != null && !scheduleIsActive(activeSchedule, now)) {
                val mode = afterExpiry.modes.firstOrNull { it.id == scheduledSession.modeId }
                val anchor = afterExpiry.anchors.firstOrNull { it.id == scheduledSession.anchorId }
                if (mode != null && anchor != null) {
                    return@updateState markScheduleEnded(
                        completeRelease(afterExpiry, scheduledSession, mode, anchor, ReleaseMethod.SCHEDULE, now),
                        activeSchedule.id,
                        dayKey(now)
                    )
                }
                return@updateState markScheduleEnded(afterExpiry.copy(activeSession = null, temporaryUnlock = null), activeSchedule.id, dayKey(now))
            }
            if (afterExpiry.activeSession != null) {
                return@updateState afterExpiry
            }
            val todayKey = dayKey(now)
            val eligible = afterExpiry.scheduledPlans.firstOrNull { plan ->
                scheduleIsEligible(plan, afterExpiry, now) && plan.lastStartedDayKey != todayKey
            } ?: return@updateState afterExpiry
            val mode = afterExpiry.modes.firstOrNull { it.id == eligible.modeId } ?: return@updateState afterExpiry
            val anchor = afterExpiry.anchors.firstOrNull { it.id == eligible.anchorId } ?: return@updateState afterExpiry
            val resolvedTargets = resolveTargetsForMode(mode)
            if (resolvedTargets.isEmpty()) {
                return@updateState afterExpiry
            }
            markScheduleStarted(
                afterExpiry.copy(
                    selectedModeId = mode.id,
                    activeSession =
                        ActiveSession(
                            modeId = mode.id,
                            anchorId = anchor.id,
                            state = SessionState.ARMED,
                            resolvedTargets = resolvedTargets.toPersistentList(),
                            armedAt = now,
                            scheduleId = eligible.id
                        ),
                    temporaryUnlock = null
                ),
                eligible.id,
                todayKey
            )
        }
    }

    override fun saveUnlockPreset(draft: UnlockPresetDraft): UnlockPresetDraftResult {
        val title = draft.title.trim()
        if (title.isEmpty() || draft.durationSeconds !in 5..300) {
            return UnlockPresetDraftResult.ValidationError("Give the preset a name and keep the duration between 5 and 300 seconds.")
        }
        val detail = draft.detail.trim().ifBlank { "Temporary access." }
        var resultId: UUID? = null
        updateState { current ->
            val preset = UnlockPreset(id = draft.id ?: UUID.randomUUID(), title = title, detail = detail, durationSeconds = draft.durationSeconds)
            resultId = preset.id
            current.copy(
                unlockPresets = current.unlockPresets.removeAll { it.id == preset.id }.add(preset).toPersistentList()
            )
        }
        return UnlockPresetDraftResult.Saved(requireNotNull(resultId))
    }

    override fun deleteUnlockPreset(presetId: UUID) {
        updateState { current ->
            val clearedUnlock = current.temporaryUnlock?.takeIf { it.presetId == presetId }
            current.copy(
                unlockPresets = current.unlockPresets.removeAll { it.id == presetId }.toPersistentList(),
                temporaryUnlock = if (clearedUnlock != null) null else current.temporaryUnlock
            )
        }
    }

    override fun activateUnlockPreset(presetId: UUID, now: java.time.Instant): UnlockPresetActivationResult {
        val current = state.value
        if (!activeSessionIsBlocking(current)) {
            return UnlockPresetActivationResult.ValidationError("No blocking session is active.")
        }
        val preset = current.unlockPresets.firstOrNull { it.id == presetId }
            ?: return UnlockPresetActivationResult.ValidationError("Create a preset before trying to use it.")
        updateState { latest ->
            latest.copy(
                temporaryUnlock = TemporaryUnlockState(
                    presetId = preset.id,
                    reason = preset.title,
                    startedAt = now,
                    expiresAt = now.plusSeconds(preset.durationSeconds.toLong())
                )
            )
        }
        return UnlockPresetActivationResult.Activated
    }

    override fun activateTemporaryUnlock(reason: String, durationSeconds: Int) {
        val trimmedReason = reason.trim().ifBlank { "Temporary unlock" }
        updateState { current ->
            if (!activeSessionIsBlocking(current)) return@updateState current
            val now = java.time.Instant.now()
            current.copy(
                temporaryUnlock = TemporaryUnlockState(
                    reason = trimmedReason,
                    startedAt = now,
                    expiresAt = now.plusSeconds(durationSeconds.toLong())
                )
            )
        }
    }

    override fun expireTemporaryUnlock(now: java.time.Instant) {
        updateState { current -> expireTemporaryUnlockIfNeeded(current, now) }
    }

    private fun updateState(transform: (AppState) -> AppState) {
        mutableState.update { current ->
            hydrateState(transform(current))
        }
    }

    private fun readinessError(state: AppState): String? =
        when {
            !state.storageAvailable -> "Storage is unavailable."
            !state.nfcAvailable -> "NFC is unavailable on this device."
            !state.blockingAuthorized || !state.setup.blockingToolsAcknowledged -> "Finish Android blocking setup before starting."
            state.activeSession != null -> "A blocking session is already active."
            else -> null
        }

    private fun completeRelease(
        session: ActiveSession,
        mode: BlockMode,
        anchor: PairedAnchor,
        releaseMethod: ReleaseMethod,
        releasedAt: java.time.Instant
    ) {
        updateState { current -> completeRelease(current, session, mode, anchor, releaseMethod, releasedAt) }
    }

    private fun completeRelease(
        current: AppState,
        session: ActiveSession,
        mode: BlockMode,
        anchor: PairedAnchor,
        releaseMethod: ReleaseMethod,
        releasedAt: java.time.Instant
    ): AppState =
        current.copy(
            activeSession = null,
            temporaryUnlock = null,
            sessionHistory =
                current.sessionHistory.add(
                    SessionHistoryEntry(
                        sessionId = session.id,
                        anchorId = anchor.id,
                        anchorName = anchor.displayName,
                        modeId = mode.id,
                        modeName = mode.name,
                        armedAt = session.armedAt,
                        releasedAt = releasedAt,
                        releaseMethod = releaseMethod
                    )
                )
        )

    private fun expireTemporaryUnlockIfNeeded(current: AppState, now: java.time.Instant): AppState {
        val activeUnlock = current.temporaryUnlock ?: return current
        return if (activeUnlock.expiresAt.isAfter(now)) current else current.copy(temporaryUnlock = null)
    }

    private fun resolveTargetsForMode(mode: BlockMode): List<BlockingTarget> {
        val availableTargets = availableBlockingTargets().distinctBy(BlockingTarget::packageName)
        val selectedPackages = mode.targets.map(BlockingTarget::packageName).toSet()
        val exemptPackages = installedAppCatalog.defaultExemptPackages()
        return when (mode.scope) {
            BlockScope.ONLY_SELECTED ->
                mode.targets
                    .filter { it.packageName !in exemptPackages }
                    .distinctBy(BlockingTarget::packageName)
            BlockScope.ALL_EXCEPT_SELECTED ->
                availableTargets.filter { it.packageName !in exemptPackages && it.packageName !in selectedPackages }
            BlockScope.ALL_APPS ->
                availableTargets.filter { it.packageName !in exemptPackages }
        }
    }

    // Restored sessions must be expanded back to the real installed-app set for ALL/ALL_EXCEPT modes.
    private fun hydrateState(state: AppState): AppState {
        val repaired = repairState(state)
        val session = repaired.activeSession ?: return repaired
        if (session.resolvedTargets.isNotEmpty()) {
            return repaired
        }
        val mode = repaired.modes.firstOrNull { it.id == session.modeId } ?: return repaired
        val resolvedTargets = resolveTargetsForMode(mode)
        return repaired.copy(activeSession = session.copy(resolvedTargets = resolvedTargets.toPersistentList()))
    }

    private fun scheduleIsEligible(plan: ScheduledSessionPlan, state: AppState, now: java.time.Instant): Boolean {
        if (!plan.isEnabled || plan.endMinuteOfDay <= plan.startMinuteOfDay) return false
        if (state.modes.none { it.id == plan.modeId }) return false
        if (state.anchors.none { it.id == plan.anchorId }) return false
        return scheduleIsActive(plan, now)
    }

    private fun scheduleIsActive(plan: ScheduledSessionPlan, now: java.time.Instant): Boolean {
        val zoned = now.atZone(java.time.ZoneOffset.UTC)
        val weekday = ((zoned.dayOfWeek.value % 7) + 1)
        if (!plan.weekdayNumbers.contains(weekday)) return false
        val minute = zoned.hour * 60 + zoned.minute
        return minute >= plan.startMinuteOfDay && minute < plan.endMinuteOfDay
    }

    private fun dayKey(now: java.time.Instant): String = now.atZone(java.time.ZoneOffset.UTC).toLocalDate().toString()

    private fun markScheduleStarted(current: AppState, scheduleId: UUID, dayKey: String): AppState =
        current.copy(
            scheduledPlans =
                current.scheduledPlans.map { plan ->
                    if (plan.id == scheduleId) plan.copy(lastStartedDayKey = dayKey, lastEndedDayKey = null) else plan
                }.toPersistentList()
        )

    private fun markScheduleEnded(current: AppState, scheduleId: UUID, dayKey: String): AppState =
        current.copy(
            scheduledPlans =
                current.scheduledPlans.map { plan ->
                    if (plan.id == scheduleId) plan.copy(lastEndedDayKey = dayKey) else plan
                }.toPersistentList()
        )

    companion object {
        private fun defaultAnchorName(index: Int): String =
            if (index == 0) "Desk anchor" else "Anchor ${index + 1}"

        internal fun defaultAnchorUid(index: Int = 0): String = "demo-anchor-${index + 1}"

        private fun promoteSingleDefault(
            modes: PersistentList<BlockMode>,
            preferredModeId: UUID,
            shouldPromotePreferred: Boolean
        ): PersistentList<BlockMode> {
            if (modes.isEmpty()) return persistentListOf()
            val idToPromote =
                when {
                    shouldPromotePreferred -> preferredModeId
                    modes.count { it.isDefault } == 1 -> modes.first { it.isDefault }.id
                    else -> modes.first().id
                }
            return modes.map { mode -> mode.copy(isDefault = mode.id == idToPromote) }.toPersistentList()
        }
    }
}

private fun normalizedChallengeText(text: String): String =
    text.replace("\r\n", "\n").replace("\r", "\n")


internal fun repairState(state: AppState): AppState {
    val repairedModes =
        when {
            state.modes.isEmpty() -> state.modes
            state.modes.count { it.isDefault } == 1 -> state.modes
            else ->
                state.modes.mapIndexed { index, mode ->
                    mode.copy(isDefault = index == 0)
                }.toPersistentList()
        }

    val selectedModeId =
        state.selectedModeId
            ?.takeIf { selectedId -> repairedModes.any { it.id == selectedId } }
            ?: repairedModes.firstOrNull()?.id

    return state.copy(
        modes = repairedModes,
        selectedModeId = selectedModeId,
        activeSession = state.activeSession,
        emergencyUnbricksRemaining = state.emergencyUnbricksRemaining.coerceAtLeast(0),
        paragraphChallenges = if (state.paragraphChallenges.isEmpty()) defaultParagraphChallenges() else state.paragraphChallenges
    )
}

class PersistentAppRepository private constructor(
    private val storage: AppStateStorage,
    private val installedAppCatalog: InstalledAppCatalog,
    initialState: AppState
) : AppRepository {
    private val delegate = InMemoryAppRepository(initialState, installedAppCatalog = installedAppCatalog)

    override val state: StateFlow<AppState> = delegate.state

    override fun availableBlockingTargets(): List<BlockingTarget> = delegate.availableBlockingTargets()

    override fun acknowledgeBlockingSetup() {
        delegate.acknowledgeBlockingSetup()
        persist()
    }

    override fun setBlockingAuthorization(isAuthorized: Boolean) {
        delegate.setBlockingAuthorization(isAuthorized)
        persist()
    }

    override fun setStorageAvailability(isAvailable: Boolean) {
        delegate.setStorageAvailability(isAvailable)
        persist()
    }

    override fun setNfcAvailability(isAvailable: Boolean) {
        delegate.setNfcAvailability(isAvailable)
        persist()
    }

    override fun pairAnchor(uid: String, displayName: String) {
        delegate.pairAnchor(uid, displayName)
        persist()
    }

    override fun renameAnchor(anchorId: UUID, displayName: String) {
        delegate.renameAnchor(anchorId, displayName)
        persist()
    }

    override fun removeAnchor(anchorId: UUID) {
        delegate.removeAnchor(anchorId)
        persist()
    }

    override fun selectMode(modeId: UUID) {
        delegate.selectMode(modeId)
        persist()
    }

    override fun saveMode(draft: ModeDraft): ModeDraftResult {
        val result = delegate.saveMode(draft)
        if (result is ModeDraftResult.Saved) {
            persist()
        }
        return result
    }

    override fun deleteMode(modeId: UUID) {
        delegate.deleteMode(modeId)
        persist()
    }

    override fun armSession(scannedAnchorUid: String): SessionActionResult {
        val result = delegate.armSession(scannedAnchorUid)
        if (result is SessionActionResult.Started) {
            persist()
        }
        return result
    }

    override fun releaseSession(scannedAnchorUid: String): SessionActionResult {
        val result = delegate.releaseSession(scannedAnchorUid)
        if (result !is SessionActionResult.ValidationError || result.message == "That anchor does not match this session.") {
            persist()
        }
        return result
    }

    override fun useEmergencyUnbrick(now: java.time.Instant): SessionActionResult {
        val result = delegate.useEmergencyUnbrick(now)
        if (result is SessionActionResult.Released) {
            persist()
        }
        return result
    }

    override fun submitParagraphChallenge(typedPassage: String, now: java.time.Instant): SessionActionResult {
        val result = delegate.submitParagraphChallenge(typedPassage, now)
        if (result is SessionActionResult.Released) {
            persist()
        }
        return result
    }

    override fun adjustEmergencyUnbricks(delta: Int) {
        delegate.adjustEmergencyUnbricks(delta)
        persist()
    }

    override fun setParagraphChallengeEnabled(isEnabled: Boolean) {
        delegate.setParagraphChallengeEnabled(isEnabled)
        persist()
    }

    override fun saveSchedule(draft: ScheduleDraft): ScheduleDraftResult {
        val result = delegate.saveSchedule(draft)
        if (result is ScheduleDraftResult.Saved) {
            persist()
        }
        return result
    }

    override fun deleteSchedule(scheduleId: UUID) {
        delegate.deleteSchedule(scheduleId)
        persist()
    }

    override fun evaluateSchedules(now: java.time.Instant) {
        delegate.evaluateSchedules(now)
        persist()
    }

    override fun saveUnlockPreset(draft: UnlockPresetDraft): UnlockPresetDraftResult {
        val result = delegate.saveUnlockPreset(draft)
        if (result is UnlockPresetDraftResult.Saved) {
            persist()
        }
        return result
    }

    override fun deleteUnlockPreset(presetId: UUID) {
        delegate.deleteUnlockPreset(presetId)
        persist()
    }

    override fun activateUnlockPreset(presetId: UUID, now: java.time.Instant): UnlockPresetActivationResult {
        val result = delegate.activateUnlockPreset(presetId, now)
        if (result is UnlockPresetActivationResult.Activated) {
            persist()
        }
        return result
    }

    override fun activateTemporaryUnlock(reason: String, durationSeconds: Int) {
        delegate.activateTemporaryUnlock(reason, durationSeconds)
        persist()
    }

    override fun expireTemporaryUnlock(now: java.time.Instant) {
        delegate.expireTemporaryUnlock(now)
        persist()
    }

    private fun persist() {
        storage.save(state.value)
    }

    companion object {
        suspend fun create(
            storage: AppStateStorage,
            installedAppCatalog: InstalledAppCatalog = StaticInstalledAppCatalog()
        ): PersistentAppRepository {
            val loaded = storage.load()
            return PersistentAppRepository(
                storage = storage,
                installedAppCatalog = installedAppCatalog,
                initialState = loaded
            )
        }
    }
}

fun browserstackSeededAppState(): AppState {
    val anchor = PairedAnchor(uid = InMemoryAppRepository.defaultAnchorUid(), displayName = "Desk anchor")
    val mode =
        BlockMode(
            name = "Focus",
            scope = BlockScope.ONLY_SELECTED,
            targets = persistentListOf(demoBlockingTargets().first { it.packageName == "com.slack" }),
            isDefault = true
        )
    val preset = UnlockPreset(title = "Check 2FA", detail = "Open Messages long enough to read a code.", durationSeconds = 20)
    val now = java.time.Instant.now()
    val historyEntry =
        SessionHistoryEntry(
            sessionId = java.util.UUID.fromString("11111111-1111-1111-1111-111111111111"),
            anchorId = anchor.id,
            anchorName = anchor.displayName,
            modeId = mode.id,
            modeName = mode.name,
            armedAt = now.minusSeconds(25 * 60),
            releasedAt = now.minusSeconds(22 * 60),
            releaseMethod = ReleaseMethod.ANCHOR
        )
    return repairState(
        AppState(
            blockingAuthorized = true,
            storageAvailable = true,
            nfcAvailable = true,
            setup = AppSetupState(blockingToolsAcknowledged = true),
            anchors = persistentListOf(anchor),
            modes = persistentListOf(mode),
            selectedModeId = mode.id,
            unlockPresets = persistentListOf(preset),
            sessionHistory = persistentListOf(historyEntry)
        )
    )
}

fun browserstackScheduleSeededAppState(now: java.time.Instant = java.time.Instant.now()): AppState {
    val anchor = PairedAnchor(uid = InMemoryAppRepository.defaultAnchorUid(), displayName = "Desk anchor")
    val mode =
        BlockMode(
            name = "Focus",
            scope = BlockScope.ONLY_SELECTED,
            targets = persistentListOf(demoBlockingTargets().first { it.packageName == "com.slack" }),
            isDefault = true
        )
    val scheduleSeed = browserstackScheduleSeed(now)
    val schedule =
        ScheduledSessionPlan(
            modeId = mode.id,
            anchorId = anchor.id,
            weekdayNumbers = persistentListOf(scheduleSeed.weekdayNumber),
            startMinuteOfDay = scheduleSeed.startMinuteOfDay,
            endMinuteOfDay = scheduleSeed.endMinuteOfDay,
            isEnabled = true
        )
    val preset = UnlockPreset(title = "Check 2FA", detail = "Open Messages long enough to read a code.", durationSeconds = 20)
    val historyEntry =
        SessionHistoryEntry(
            sessionId = java.util.UUID.fromString("22222222-2222-2222-2222-222222222222"),
            anchorId = anchor.id,
            anchorName = anchor.displayName,
            modeId = mode.id,
            modeName = mode.name,
            armedAt = now.minusSeconds(35 * 60),
            releasedAt = now.minusSeconds(30 * 60),
            releaseMethod = ReleaseMethod.SCHEDULE
        )
    return repairState(
        AppState(
            blockingAuthorized = true,
            storageAvailable = true,
            nfcAvailable = true,
            setup = AppSetupState(blockingToolsAcknowledged = true),
            anchors = persistentListOf(anchor),
            modes = persistentListOf(mode),
            selectedModeId = mode.id,
            scheduledPlans = persistentListOf(schedule),
            unlockPresets = persistentListOf(preset),
            sessionHistory = persistentListOf(historyEntry)
        )
    )
}

internal fun nextScheduleTransitionAt(
    state: AppState,
    now: java.time.Instant = java.time.Instant.now()
): java.time.Instant? {
    val zone = java.time.ZoneOffset.UTC
    val today = now.atZone(zone).toLocalDate()
    val validPlans =
        state.scheduledPlans.filter { plan ->
            plan.isEnabled &&
                plan.endMinuteOfDay > plan.startMinuteOfDay &&
                state.modes.any { it.id == plan.modeId } &&
                state.anchors.any { it.id == plan.anchorId }
        }
    if (validPlans.isEmpty()) {
        return null
    }
    val candidates =
        buildList {
            validPlans.forEach { plan ->
                for (offset in 0..7) {
                    val date = today.plusDays(offset.toLong())
                    val weekdayNumber = (date.dayOfWeek.value % 7) + 1
                    if (!plan.weekdayNumbers.contains(weekdayNumber)) {
                        continue
                    }
                    val dayStart = date.atStartOfDay(zone)
                    val start = dayStart.plusMinutes(plan.startMinuteOfDay.toLong()).toInstant()
                    val end = dayStart.plusMinutes(plan.endMinuteOfDay.toLong()).toInstant()
                    if (start.isAfter(now)) {
                        add(start)
                    }
                    if (end.isAfter(now)) {
                        add(end)
                    }
                }
            }
        }
    return candidates.minOrNull()
}

private data class BrowserstackScheduleSeed(
    val weekdayNumber: Int,
    val startMinuteOfDay: Int,
    val endMinuteOfDay: Int
)

private fun browserstackScheduleSeed(now: java.time.Instant): BrowserstackScheduleSeed {
    val zoned = now.atZone(java.time.ZoneOffset.UTC)
    val currentMinuteOfDay = zoned.hour * 60 + zoned.minute
    val currentWeekday = (zoned.dayOfWeek.value % 7) + 1

    // BrowserStack proof needs a cold-launch home shell first, then an automatic schedule
    // start, then an automatic schedule end without any manual start action.
    return if (currentMinuteOfDay <= (24 * 60) - 4) {
        val startMinute = currentMinuteOfDay + 1
        BrowserstackScheduleSeed(
            weekdayNumber = currentWeekday,
            startMinuteOfDay = startMinute,
            endMinuteOfDay = startMinute + 2
        )
    } else {
        BrowserstackScheduleSeed(
            weekdayNumber = (currentWeekday % 7) + 1,
            startMinuteOfDay = 0,
            endMinuteOfDay = 2
        )
    }
}

interface AppStateStorage {
    suspend fun load(): AppState

    fun save(state: AppState)
}

interface BlockingSnapshotStorage {
    fun loadBlockingSnapshot(): AccessibilityBlockingSnapshotPayload
}

class FakeAppStateStorage(
    initialState: AppState = AppState()
) : AppStateStorage, BlockingSnapshotStorage {
    private var persistedState: AppState = repairState(initialState)

    override suspend fun load(): AppState = persistedState

    override fun save(state: AppState) {
        persistedState = repairState(state)
    }

    override fun loadBlockingSnapshot(): AccessibilityBlockingSnapshotPayload =
        AccessibilityBlockingSnapshotPayload.fromState(persistedState)
}

class AndroidDataStoreAppStateStorage(
    context: Context,
    private val json: Json = Json { ignoreUnknownKeys = true }
) : AppStateStorage, BlockingSnapshotStorage {
    private val dataStore = sharedDataStore(context.applicationContext)

    companion object {
        @Volatile
        private var sharedPreferenceDataStore: DataStore<Preferences>? = null

        internal fun sharedDataStore(context: Context): DataStore<Preferences> =
            sharedPreferenceDataStore ?: synchronized(this) {
                sharedPreferenceDataStore
                    ?: PreferenceDataStoreFactory.create {
                        context.applicationContext.preferencesDataStoreFile("ancla-app-state.preferences_pb")
                    }.also { sharedPreferenceDataStore = it }
            }

        internal fun resetSharedDataStoreForTests() {
            sharedPreferenceDataStore = null
        }
    }

    override suspend fun load(): AppState =
        dataStore.data
            .catch { throwable ->
                if (throwable is IOException) {
                    emit(emptyPreferences())
                } else {
                    throw throwable
                }
            }
            .map { preferences ->
                val encodedModes = preferences[PreferencesKeys.MODES]
                val encodedAnchors = preferences[PreferencesKeys.ANCHORS]
                val encodedSession = preferences[PreferencesKeys.ACTIVE_SESSION]

                repairState(
                    AppState(
                        blockingAuthorized = preferences[PreferencesKeys.BLOCKING_AUTHORIZED] ?: false,
                        storageAvailable = preferences[PreferencesKeys.STORAGE_AVAILABLE] ?: true,
                        nfcAvailable = preferences[PreferencesKeys.NFC_AVAILABLE] ?: true,
                        setup =
                            AppSetupState(
                                blockingToolsAcknowledged =
                                    preferences[PreferencesKeys.BLOCKING_SETUP_ACKNOWLEDGED] ?: false
                            ),
                        anchors =
                            encodedAnchors
                                ?.let { encoded -> json.decodeFromString<List<StoredAnchor>>(encoded) }
                                ?.map { storedAnchor -> storedAnchor.toModel() }
                                ?.toPersistentList()
                                ?: persistentListOf(),
                        modes =
                            encodedModes
                                ?.let { encoded -> json.decodeFromString<List<StoredMode>>(encoded) }
                                ?.map { storedMode -> storedMode.toModel() }
                                ?.toPersistentList()
                                ?: persistentListOf(),
                        selectedModeId = preferences[PreferencesKeys.SELECTED_MODE_ID]?.let(UUID::fromString),
                        sessionHistory =
                            preferences[PreferencesKeys.SESSION_HISTORY]
                                ?.let { encoded -> json.decodeFromString<List<StoredHistoryEntry>>(encoded) }
                                ?.map { it.toModel() }
                                ?.toPersistentList()
                                ?: persistentListOf(),
                        scheduledPlans =
                            preferences[PreferencesKeys.SCHEDULED_PLANS]
                                ?.let { encoded -> json.decodeFromString<List<StoredSchedule>>(encoded) }
                                ?.map { it.toModel() }
                                ?.toPersistentList()
                                ?: persistentListOf(),
                        unlockPresets =
                            preferences[PreferencesKeys.UNLOCK_PRESETS]
                                ?.let { encoded -> json.decodeFromString<List<StoredUnlockPreset>>(encoded) }
                                ?.map { it.toModel() }
                                ?.toPersistentList()
                                ?: persistentListOf(),
                        temporaryUnlock =
                            preferences[PreferencesKeys.TEMPORARY_UNLOCK]
                                ?.let { encoded -> json.decodeFromString<StoredTemporaryUnlockState>(encoded).toModel() },
                        emergencyUnbricksRemaining = preferences[PreferencesKeys.EMERGENCY_UNBRICKS_REMAINING] ?: 5,
                        paragraphChallengeEnabled = preferences[PreferencesKeys.PARAGRAPH_CHALLENGE_ENABLED] ?: true,
                        paragraphChallenges =
                            preferences[PreferencesKeys.PARAGRAPH_CHALLENGES]
                                ?.let { encoded -> json.decodeFromString<List<StoredParagraphChallenge>>(encoded) }
                                ?.map { it.toModel() }
                                ?.toPersistentList()
                                ?: defaultParagraphChallenges(),
                        activeSession = encodedSession?.let {
                            json.decodeFromString<StoredSession>(it).toModel()
                        }
                    )
                )
            }
            .first()

    override fun save(state: AppState) {
        kotlinx.coroutines.runBlocking {
            dataStore.edit { preferences ->
                preferences[PreferencesKeys.BLOCKING_AUTHORIZED] = state.blockingAuthorized
                preferences[PreferencesKeys.STORAGE_AVAILABLE] = state.storageAvailable
                preferences[PreferencesKeys.NFC_AVAILABLE] = state.nfcAvailable
                preferences[PreferencesKeys.BLOCKING_SETUP_ACKNOWLEDGED] =
                    state.setup.blockingToolsAcknowledged
                if (state.selectedModeId == null) {
                    preferences.remove(PreferencesKeys.SELECTED_MODE_ID)
                } else {
                    preferences[PreferencesKeys.SELECTED_MODE_ID] = state.selectedModeId.toString()
                }
                preferences[PreferencesKeys.MODES] =
                    json.encodeToString(state.modes.map { StoredMode.from(it) })
                preferences[PreferencesKeys.ANCHORS] =
                    json.encodeToString(state.anchors.map { StoredAnchor.from(it) })
                preferences[PreferencesKeys.SESSION_HISTORY] =
                    json.encodeToString(state.sessionHistory.map { StoredHistoryEntry.from(it) })
                preferences[PreferencesKeys.EMERGENCY_UNBRICKS_REMAINING] = state.emergencyUnbricksRemaining
                preferences[PreferencesKeys.PARAGRAPH_CHALLENGE_ENABLED] = state.paragraphChallengeEnabled
                preferences[PreferencesKeys.PARAGRAPH_CHALLENGES] =
                    json.encodeToString(state.paragraphChallenges.map { StoredParagraphChallenge.from(it) })
                preferences[PreferencesKeys.SCHEDULED_PLANS] =
                    json.encodeToString(state.scheduledPlans.map { StoredSchedule.from(it) })
                preferences[PreferencesKeys.UNLOCK_PRESETS] =
                    json.encodeToString(state.unlockPresets.map { StoredUnlockPreset.from(it) })
                if (state.temporaryUnlock == null) {
                    preferences.remove(PreferencesKeys.TEMPORARY_UNLOCK)
                } else {
                    preferences[PreferencesKeys.TEMPORARY_UNLOCK] =
                        json.encodeToString(StoredTemporaryUnlockState.from(state.temporaryUnlock))
                }
                if (state.activeSession == null) {
                    preferences.remove(PreferencesKeys.ACTIVE_SESSION)
                } else {
                    preferences[PreferencesKeys.ACTIVE_SESSION] =
                        json.encodeToString(StoredSession.from(state.activeSession))
                }
                preferences[PreferencesKeys.BLOCKING_SNAPSHOT] =
                    json.encodeToString(
                        StoredBlockingSnapshot.from(
                            AccessibilityBlockingSnapshotPayload.fromState(state)
                        )
                    )
            }
        }
    }

    override fun loadBlockingSnapshot(): AccessibilityBlockingSnapshotPayload =
        kotlinx.coroutines.runBlocking {
            dataStore.data
                .catch { throwable ->
                    if (throwable is IOException) {
                        emit(emptyPreferences())
                    } else {
                        throw throwable
                    }
                }
                .map { preferences ->
                    preferences[PreferencesKeys.BLOCKING_SNAPSHOT]
                        ?.let { encoded ->
                            json.decodeFromString<StoredBlockingSnapshot>(encoded).toModel()
                        }
                        ?: AccessibilityBlockingSnapshotPayload.empty()
                }
                .first()
        }

    private object PreferencesKeys {
        val BLOCKING_AUTHORIZED = booleanPreferencesKey("blocking_authorized")
        val STORAGE_AVAILABLE = booleanPreferencesKey("storage_available")
        val NFC_AVAILABLE = booleanPreferencesKey("nfc_available")
        val BLOCKING_SETUP_ACKNOWLEDGED = booleanPreferencesKey("blocking_setup_acknowledged")
        val SELECTED_MODE_ID = stringPreferencesKey("selected_mode_id")
        val MODES = stringPreferencesKey("modes")
        val ANCHORS = stringPreferencesKey("anchors")
        val SESSION_HISTORY = stringPreferencesKey("session_history")
        val EMERGENCY_UNBRICKS_REMAINING = androidx.datastore.preferences.core.intPreferencesKey("emergency_unbricks_remaining")
        val PARAGRAPH_CHALLENGE_ENABLED = booleanPreferencesKey("paragraph_challenge_enabled")
        val PARAGRAPH_CHALLENGES = stringPreferencesKey("paragraph_challenges")
        val SCHEDULED_PLANS = stringPreferencesKey("scheduled_plans")
        val UNLOCK_PRESETS = stringPreferencesKey("unlock_presets")
        val TEMPORARY_UNLOCK = stringPreferencesKey("temporary_unlock")
        val ACTIVE_SESSION = stringPreferencesKey("active_session")
        val BLOCKING_SNAPSHOT = stringPreferencesKey("blocking_snapshot")
    }
}

@Serializable
private data class StoredParagraphChallenge(
    val id: String,
    val title: String,
    val passage: String,
    val createdAt: String
) {
    fun toModel(): ParagraphChallenge =
        ParagraphChallenge(
            id = UUID.fromString(id),
            title = title,
            passage = passage,
            createdAt = java.time.Instant.parse(createdAt)
        )

    companion object {
        fun from(challenge: ParagraphChallenge): StoredParagraphChallenge =
            StoredParagraphChallenge(
                id = challenge.id.toString(),
                title = challenge.title,
                passage = challenge.passage,
                createdAt = challenge.createdAt.toString()
            )
    }
}

@Serializable
private data class StoredTarget(
    val id: String,
    val label: String,
    val kind: String = TargetKind.APP.name,
    val packageName: String
) {
    fun toModel(): BlockingTarget =
        BlockingTarget(
            id = id,
            label = label,
            kind = TargetKind.valueOf(kind),
            packageName = packageName
        )

    companion object {
        fun from(target: BlockingTarget): StoredTarget =
            StoredTarget(id = target.id, label = target.label, kind = target.kind.name, packageName = target.packageName)
    }
}

@Serializable
private data class StoredMode(
    val id: String,
    val name: String,
    val scope: String = BlockScope.ONLY_SELECTED.name,
    val targets: List<StoredTarget>,
    val isDefault: Boolean
) {
    fun toModel(): BlockMode =
        BlockMode(
            id = UUID.fromString(id),
            name = name,
            scope = BlockScope.valueOf(scope),
            targets = targets.map { it.toModel() }.toPersistentList(),
            isDefault = isDefault
        )

    companion object {
        fun from(mode: BlockMode): StoredMode =
            StoredMode(
                id = mode.id.toString(),
                name = mode.name,
                scope = mode.scope.name,
                targets = mode.targets.map { StoredTarget.from(it) },
                isDefault = mode.isDefault
            )
    }
}

@Serializable
private data class StoredAnchor(
    val id: String,
    val uid: String,
    val displayName: String
) {
    fun toModel(): PairedAnchor =
        PairedAnchor(id = UUID.fromString(id), uid = uid, displayName = displayName)

    companion object {
        fun from(anchor: PairedAnchor): StoredAnchor =
            StoredAnchor(id = anchor.id.toString(), uid = anchor.uid, displayName = anchor.displayName)
    }
}

@Serializable
private data class StoredSession(
    val id: String,
    val modeId: String,
    val anchorId: String,
    val state: String,
    val resolvedTargets: List<StoredTarget> = emptyList(),
    val armedAt: String,
    val scheduleId: String?
) {
    fun toModel(): ActiveSession =
        ActiveSession(
            id = UUID.fromString(id),
            modeId = UUID.fromString(modeId),
            anchorId = UUID.fromString(anchorId),
            state = SessionState.valueOf(state),
            resolvedTargets = resolvedTargets.map { it.toModel() }.toPersistentList(),
            armedAt = java.time.Instant.parse(armedAt),
            scheduleId = scheduleId?.let(UUID::fromString)
        )

    companion object {
        fun from(session: ActiveSession): StoredSession =
            StoredSession(
                id = session.id.toString(),
                modeId = session.modeId.toString(),
                anchorId = session.anchorId.toString(),
                state = session.state.name,
                resolvedTargets = session.resolvedTargets.map { StoredTarget.from(it) },
                armedAt = session.armedAt.toString(),
                scheduleId = session.scheduleId?.toString()
            )
    }
}

@Serializable
private data class StoredTemporaryUnlockState(
    val presetId: String? = null,
    val reason: String,
    val startedAt: String,
    val expiresAt: String
) {
    fun toModel(): TemporaryUnlockState =
        TemporaryUnlockState(
            presetId = presetId?.let(UUID::fromString),
            reason = reason,
            startedAt = java.time.Instant.parse(startedAt),
            expiresAt = java.time.Instant.parse(expiresAt)
        )

    companion object {
        fun from(state: TemporaryUnlockState): StoredTemporaryUnlockState =
            StoredTemporaryUnlockState(
                presetId = state.presetId?.toString(),
                reason = state.reason,
                startedAt = state.startedAt.toString(),
                expiresAt = state.expiresAt.toString()
            )
    }
}


@Serializable
private data class StoredSchedule(
    val id: String,
    val modeId: String,
    val anchorId: String,
    val weekdayNumbers: List<Int>,
    val startMinuteOfDay: Int,
    val endMinuteOfDay: Int,
    val isEnabled: Boolean,
    val lastStartedDayKey: String?,
    val lastEndedDayKey: String?
) {
    fun toModel(): ScheduledSessionPlan =
        ScheduledSessionPlan(
            id = UUID.fromString(id),
            modeId = UUID.fromString(modeId),
            anchorId = UUID.fromString(anchorId),
            weekdayNumbers = weekdayNumbers.toPersistentList(),
            startMinuteOfDay = startMinuteOfDay,
            endMinuteOfDay = endMinuteOfDay,
            isEnabled = isEnabled,
            lastStartedDayKey = lastStartedDayKey,
            lastEndedDayKey = lastEndedDayKey
        )

    companion object {
        fun from(schedule: ScheduledSessionPlan): StoredSchedule =
            StoredSchedule(
                id = schedule.id.toString(),
                modeId = schedule.modeId.toString(),
                anchorId = schedule.anchorId.toString(),
                weekdayNumbers = schedule.weekdayNumbers.toList(),
                startMinuteOfDay = schedule.startMinuteOfDay,
                endMinuteOfDay = schedule.endMinuteOfDay,
                isEnabled = schedule.isEnabled,
                lastStartedDayKey = schedule.lastStartedDayKey,
                lastEndedDayKey = schedule.lastEndedDayKey
            )
    }
}

@Serializable
private data class StoredUnlockPreset(
    val id: String,
    val title: String,
    val detail: String,
    val durationSeconds: Int
) {
    fun toModel(): UnlockPreset =
        UnlockPreset(
            id = UUID.fromString(id),
            title = title,
            detail = detail,
            durationSeconds = durationSeconds
        )

    companion object {
        fun from(preset: UnlockPreset): StoredUnlockPreset =
            StoredUnlockPreset(
                id = preset.id.toString(),
                title = preset.title,
                detail = preset.detail,
                durationSeconds = preset.durationSeconds
            )
    }
}

@Serializable
private data class StoredHistoryEntry(
    val id: String,
    val sessionId: String,
    val anchorId: String,
    val anchorName: String,
    val modeId: String,
    val modeName: String,
    val armedAt: String,
    val releasedAt: String,
    val releaseMethod: String
) {
    fun toModel(): SessionHistoryEntry =
        SessionHistoryEntry(
            id = UUID.fromString(id),
            sessionId = UUID.fromString(sessionId),
            anchorId = UUID.fromString(anchorId),
            anchorName = anchorName,
            modeId = UUID.fromString(modeId),
            modeName = modeName,
            armedAt = java.time.Instant.parse(armedAt),
            releasedAt = java.time.Instant.parse(releasedAt),
            releaseMethod = ReleaseMethod.valueOf(releaseMethod)
        )

    companion object {
        fun from(entry: SessionHistoryEntry): StoredHistoryEntry =
            StoredHistoryEntry(
                id = entry.id.toString(),
                sessionId = entry.sessionId.toString(),
                anchorId = entry.anchorId.toString(),
                anchorName = entry.anchorName,
                modeId = entry.modeId.toString(),
                modeName = entry.modeName,
                armedAt = entry.armedAt.toString(),
                releasedAt = entry.releasedAt.toString(),
                releaseMethod = entry.releaseMethod.name
            )
    }
}

@Serializable
private data class StoredBlockingSnapshot(
    val isBlocking: Boolean,
    val sessionId: String?,
    val sessionState: String?,
    val sessionStartedAt: String?,
    val modeName: String?,
    val anchorName: String?,
    val targets: List<StoredTarget>
) {
    fun toModel(): AccessibilityBlockingSnapshotPayload =
        AccessibilityBlockingSnapshotPayload(
            isBlocking = isBlocking,
            sessionId = sessionId?.let(UUID::fromString),
            sessionState = sessionState?.let(SessionState::valueOf),
            sessionStartedAt = sessionStartedAt?.let(java.time.Instant::parse),
            modeName = modeName,
            anchorName = anchorName,
            targets = targets.map { it.toModel() }
        )

    companion object {
        fun from(payload: AccessibilityBlockingSnapshotPayload): StoredBlockingSnapshot =
            StoredBlockingSnapshot(
                isBlocking = payload.isBlocking,
                sessionId = payload.sessionId?.toString(),
                sessionState = payload.sessionState?.name,
                sessionStartedAt = payload.sessionStartedAt?.toString(),
                modeName = payload.modeName,
                anchorName = payload.anchorName,
                targets = payload.targets.map { StoredTarget.from(it) }
            )
    }
}
