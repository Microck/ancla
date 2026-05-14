package dev.micr.ancla.model

import java.util.UUID

enum class SetupStepId {
    BLOCKING_PERMISSION,
    ANCHOR,
    MODE
}

data class SetupStep(
    val id: SetupStepId,
    val title: String,
    val detail: String,
    val status: ReadinessStatus
)

enum class ReadinessBlocker {
    STORAGE,
    NFC,
    BLOCKING_TOOLS,
    ANCHOR,
    MODE,
    ACTIVE_SESSION,
    READY
}

enum class ReadinessItemId {
    BLOCKING_CAPABILITY,
    NFC,
    STORAGE,
    ANCHOR,
    MODE,
    SESSION
}

data class ReadinessItem(
    val id: ReadinessItemId,
    val label: String,
    val summary: String,
    val detail: String,
    val status: ReadinessStatus
)

data class ReadinessState(
    val blocker: ReadinessBlocker,
    val headline: String,
    val detail: String,
    val items: List<ReadinessItem>
)

data class StartGateState(
    val canStart: Boolean,
    val reason: String
)

fun setupSteps(state: AppState): List<SetupStep> =
    listOf(
        SetupStep(
            id = SetupStepId.BLOCKING_PERMISSION,
            title = "Enable Android blocking tools",
            detail = blockingToolsStepDetail(state),
            status = if (state.setup.blockingToolsAcknowledged) ReadinessStatus.READY else ReadinessStatus.ACTION_REQUIRED
        ),
        SetupStep(
            id = SetupStepId.ANCHOR,
            title = "Pair at least one anchor",
            detail = state.anchors.anchorSummary(),
            status = if (state.anchors.isEmpty()) ReadinessStatus.ACTION_REQUIRED else ReadinessStatus.READY
        ),
        SetupStep(
            id = SetupStepId.MODE,
            title = "Create one blocking mode",
            detail = state.modes.modeSummaryLine(),
            status = if (state.modes.isEmpty()) ReadinessStatus.ACTION_REQUIRED else ReadinessStatus.READY
        )
    )

fun firstIncompleteStep(state: AppState): SetupStepId? =
    setupSteps(state).firstOrNull { it.status != ReadinessStatus.READY }?.id

fun setupDestination(state: AppState): SetupDestination =
    when (firstIncompleteStep(state)) {
        SetupStepId.BLOCKING_PERMISSION -> SetupDestination.BLOCKING_PERMISSION
        SetupStepId.ANCHOR -> SetupDestination.ANCHOR
        SetupStepId.MODE -> SetupDestination.MODE
        null -> SetupDestination.COMPLETE
    }

fun readinessState(state: AppState): ReadinessState {
    val blocker = determineBlocker(state)
    return ReadinessState(
        blocker = blocker,
        headline = blockerHeadline(blocker),
        detail = blockerDetail(blocker, state),
        items = listOf(
            readinessItemBlockingCapability(state),
            readinessItemNfc(state),
            readinessItemStorage(state),
            readinessItemAnchor(state),
            readinessItemMode(state),
            readinessItemSession(state)
        )
    )
}

fun shouldShowSetupGate(state: AppState): Boolean =
    state.activeSession == null && setupSteps(state).any { it.status != ReadinessStatus.READY }

fun startGateState(state: AppState): StartGateState {
    val blocker = determineBlocker(state)
    return when (blocker) {
        ReadinessBlocker.READY -> StartGateState(true, "Ready to start.")
        ReadinessBlocker.STORAGE -> StartGateState(false, "Storage is unavailable.")
        ReadinessBlocker.NFC -> StartGateState(false, "NFC is unavailable on this device.")
        ReadinessBlocker.BLOCKING_TOOLS ->
            StartGateState(false, "Finish Android blocking setup before starting.")
        ReadinessBlocker.ANCHOR -> StartGateState(false, "Pair at least one anchor before starting.")
        ReadinessBlocker.MODE -> StartGateState(false, "Create a mode before starting.")
        ReadinessBlocker.ACTIVE_SESSION -> StartGateState(false, "A blocking session is already active.")
    }
}

fun selectedMode(state: AppState): BlockMode? =
    state.selectedModeId?.let { selectedId -> state.modes.firstOrNull { it.id == selectedId } }
        ?: preferredMode(state)

fun preferredMode(state: AppState): BlockMode? =
    state.modes.firstOrNull { it.isDefault } ?: state.modes.firstOrNull()

fun activeMode(state: AppState): BlockMode? =
    state.activeSession?.let { session -> state.modes.firstOrNull { it.id == session.modeId } }

fun activeAnchor(state: AppState): PairedAnchor? =
    state.activeSession?.let { session -> state.anchors.firstOrNull { it.id == session.anchorId } }

fun activeSessionIsBlocking(state: AppState): Boolean =
    when (state.activeSession?.state) {
        SessionState.ARMED, SessionState.WRONG_ANCHOR -> true
        null -> false
    }

fun sessionHasActiveTemporaryUnlock(
    state: AppState,
    now: java.time.Instant = java.time.Instant.now()
): Boolean =
    activeSessionIsBlocking(state) && state.temporaryUnlock?.expiresAt?.isAfter(now) == true

fun temporaryUnlockIsActive(state: AppState, now: java.time.Instant = java.time.Instant.now()): Boolean =
    sessionHasActiveTemporaryUnlock(state, now)

fun canUseEmergencyUnbrick(state: AppState): Boolean =
    activeSessionIsBlocking(state) && state.emergencyUnbricksRemaining > 0

fun canUseParagraphChallenge(state: AppState): Boolean =
    activeSessionIsBlocking(state) &&
        state.emergencyUnbricksRemaining == 0 &&
        state.paragraphChallengeEnabled &&
        state.paragraphChallenges.isNotEmpty()

fun recentHistory(state: AppState, limit: Int = 10): List<SessionHistoryEntry> {
    val entries = state.sessionHistory.sortedByDescending { it.releasedAt }
    return if (limit < entries.size) entries.take(limit) else entries
}

fun blockedPresentationIsActive(state: AppState, now: java.time.Instant = java.time.Instant.now()): Boolean =
    activeSessionIsBlocking(state) && !sessionHasActiveTemporaryUnlock(state, now)

fun blockingInterceptionForPackage(
    state: AppState,
    packageName: String,
    now: java.time.Instant = java.time.Instant.now()
): BlockingInterception? {
    if (!blockedPresentationIsActive(state, now)) return null
    val activeSession = state.activeSession ?: return null
    val mode = activeMode(state) ?: return null
    val anchor = activeAnchor(state) ?: return null
    val target =
        activeSession.resolvedTargets
            .ifEmpty { mode.targets }
            .firstOrNull { it.packageName == packageName } ?: return null
    return BlockingInterception(
        packageName = packageName,
        targetId = target.id,
        targetLabel = target.label,
        targetKind = target.kind,
        modeName = mode.name,
        anchorName = anchor.displayName,
        sessionId = activeSession.id,
        sessionState = activeSession.state,
        sessionStartedAt = activeSession.armedAt
    )
}

fun shouldInterceptPackage(
    state: AppState,
    packageName: String,
    now: java.time.Instant = java.time.Instant.now()
): Boolean = blockingInterceptionForPackage(state, packageName, now) != null

private fun determineBlocker(state: AppState): ReadinessBlocker =
    when {
        !state.storageAvailable -> ReadinessBlocker.STORAGE
        !state.nfcAvailable -> ReadinessBlocker.NFC
        !state.blockingAuthorized || !state.setup.blockingToolsAcknowledged -> ReadinessBlocker.BLOCKING_TOOLS
        state.anchors.isEmpty() -> ReadinessBlocker.ANCHOR
        state.modes.isEmpty() -> ReadinessBlocker.MODE
        state.activeSession != null -> ReadinessBlocker.ACTIVE_SESSION
        else -> ReadinessBlocker.READY
    }

private fun blockerHeadline(blocker: ReadinessBlocker): String =
    when (blocker) {
        ReadinessBlocker.STORAGE -> "Storage unavailable"
        ReadinessBlocker.NFC -> "NFC unavailable"
        ReadinessBlocker.BLOCKING_TOOLS -> "Finish Android setup"
        ReadinessBlocker.ANCHOR -> "Pair an anchor"
        ReadinessBlocker.MODE -> "Create a mode"
        ReadinessBlocker.ACTIVE_SESSION -> "Session active"
        ReadinessBlocker.READY -> "Ready to start"
    }

private fun blockerDetail(blocker: ReadinessBlocker, state: AppState): String =
    when (blocker) {
        ReadinessBlocker.STORAGE -> "The app cannot trust its stored state until storage recovers."
        ReadinessBlocker.NFC -> "Anchor pairing and anchor release cannot work without NFC."
        ReadinessBlocker.BLOCKING_TOOLS ->
            "Android needs blocking authorization plus your explicit confirmation for the manual setup step."
        ReadinessBlocker.ANCHOR -> "Pair at least one anchor so the physical release path exists."
        ReadinessBlocker.MODE -> "Save at least one mode with an Android app scope."
        ReadinessBlocker.ACTIVE_SESSION -> {
            val activeModeName = activeMode(state)?.name ?: "Current mode"
            val anchorName = activeAnchor(state)?.displayName ?: "paired anchor"
            when (state.activeSession?.state) {
                SessionState.WRONG_ANCHOR ->
                    "$activeModeName is still active. Retry release with $anchorName."
                else ->
                    "$activeModeName is already active. Finish it with $anchorName before starting another session."
            }
        }
        ReadinessBlocker.READY -> "Android can start blocking right now."
    }

private fun readinessItemBlockingCapability(state: AppState): ReadinessItem =
    ReadinessItem(
        id = ReadinessItemId.BLOCKING_CAPABILITY,
        label = "Blocking tools",
        summary =
            if (state.blockingAuthorized && state.setup.blockingToolsAcknowledged) {
                "Ready"
            } else {
                "Needs setup"
            },
        detail =
            if (state.blockingAuthorized && state.setup.blockingToolsAcknowledged) {
                "Authorization granted and the Android manual setup acknowledgment is stored."
            } else {
                "Grant Android blocking permission and confirm the manual Android step with the explicit acknowledgment button."
            },
        status =
            if (state.blockingAuthorized && state.setup.blockingToolsAcknowledged) {
                ReadinessStatus.READY
            } else {
                ReadinessStatus.ACTION_REQUIRED
            }
    )

private fun readinessItemNfc(state: AppState): ReadinessItem =
    ReadinessItem(
        id = ReadinessItemId.NFC,
        label = "NFC",
        summary = if (state.nfcAvailable) "Ready" else "Unavailable",
        detail =
            if (state.nfcAvailable) {
                "This device can pair and release with anchors."
            } else {
                "This device cannot pair or release using anchors."
            },
        status = if (state.nfcAvailable) ReadinessStatus.READY else ReadinessStatus.BLOCKED
    )

private fun readinessItemStorage(state: AppState): ReadinessItem =
    ReadinessItem(
        id = ReadinessItemId.STORAGE,
        label = "Storage",
        summary = if (state.storageAvailable) "Healthy" else "Unavailable",
        detail =
            if (state.storageAvailable) {
                "App state can be loaded and saved."
            } else {
                "State storage failed and must recover before blocking can start."
            },
        status = if (state.storageAvailable) ReadinessStatus.READY else ReadinessStatus.BLOCKED
    )

private fun readinessItemAnchor(state: AppState): ReadinessItem =
    ReadinessItem(
        id = ReadinessItemId.ANCHOR,
        label = "Anchor",
        summary = if (state.anchors.isEmpty()) "No anchors" else "${state.anchors.size} paired",
        detail =
            if (state.anchors.isEmpty()) {
                "Pair at least one anchor."
            } else {
                "${state.anchors.anchorSummary()} ${state.anchors.joinToString(separator = ", ") { it.displayName }}"
            },
        status = if (state.anchors.isEmpty()) ReadinessStatus.ACTION_REQUIRED else ReadinessStatus.READY
    )

private fun readinessItemMode(state: AppState): ReadinessItem =
    ReadinessItem(
        id = ReadinessItemId.MODE,
        label = "Mode",
        summary = preferredMode(state)?.name ?: "No modes",
        detail =
            if (state.modes.isEmpty()) {
                "Save at least one mode."
            } else {
                "${state.modes.modeSummaryLine()} Default: ${preferredMode(state)?.name.orEmpty()}"
            },
        status = if (state.modes.isEmpty()) ReadinessStatus.ACTION_REQUIRED else ReadinessStatus.READY
    )

private fun readinessItemSession(state: AppState): ReadinessItem =
    ReadinessItem(
        id = ReadinessItemId.SESSION,
        label = "Session",
        summary =
            when (state.activeSession?.state) {
                SessionState.ARMED -> "Active"
                SessionState.WRONG_ANCHOR -> "Wrong anchor"
                null -> "Idle"
            },
        detail =
            when (state.activeSession?.state) {
                SessionState.ARMED -> {
                    val anchorName = activeAnchor(state)?.displayName ?: "paired anchor"
                    "A blocking session is already active and bound to $anchorName."
                }
                SessionState.WRONG_ANCHOR -> {
                    val anchorName = activeAnchor(state)?.displayName ?: "paired anchor"
                    "Wrong anchor scanned. The session is still active. Retry with $anchorName."
                }
                null -> "No blocking session is active."
            },
        status =
            if (state.activeSession == null) {
                ReadinessStatus.READY
            } else {
                ReadinessStatus.ACTION_REQUIRED
            }
    )

fun modeSummary(mode: BlockMode): String {
    val targetLabels = mode.targets.joinToString { it.label }
    return when (mode.scope) {
        BlockScope.ONLY_SELECTED -> "Only: $targetLabels"
        BlockScope.ALL_EXCEPT_SELECTED -> "All except: $targetLabels"
        BlockScope.ALL_APPS -> "All installed apps except Android-critical surfaces."
    }
}

fun AppState.withModeSelection(
    selectedModeId: UUID? = this.selectedModeId,
    activeSession: ActiveSession? = this.activeSession
): AppState = copy(selectedModeId = selectedModeId, activeSession = activeSession)

private fun blockingToolsStepDetail(state: AppState): String =
    when {
        state.blockingAuthorized && state.setup.blockingToolsAcknowledged ->
            "Acknowledged. Android blocking tools are ready."
        state.blockingAuthorized ->
            "Blocking authorization is ready. Confirm the manual Android setup step to finish this requirement."
        else ->
            "Review the Android-only instructions, enable blocking capability in system settings, then explicitly confirm the manual setup step."
    }
