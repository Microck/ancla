package dev.micr.ancla.model

import java.util.UUID

data class AccessibilityBlockingSnapshotPayload(
    val isBlocking: Boolean,
    val sessionId: UUID?,
    val sessionState: SessionState?,
    val sessionStartedAt: java.time.Instant?,
    val modeName: String?,
    val anchorName: String?,
    val targets: List<BlockingTarget>
) {
    fun interceptionFor(packageName: String): BlockingInterception? {
        if (!isBlocking) return null
        val blockingSessionId = sessionId ?: return null
        val blockingSessionState = sessionState ?: return null
        val blockingModeName = modeName ?: return null
        val blockingAnchorName = anchorName ?: return null
        val target = targets.firstOrNull { it.packageName == packageName } ?: return null
        return BlockingInterception(
            packageName = packageName,
            targetId = target.id,
            targetLabel = target.label,
            targetKind = target.kind,
            modeName = blockingModeName,
            anchorName = blockingAnchorName,
            sessionId = blockingSessionId,
            sessionState = blockingSessionState,
            sessionStartedAt = sessionStartedAt ?: java.time.Instant.EPOCH
        )
    }

    companion object {
        fun fromState(state: AppState): AccessibilityBlockingSnapshotPayload {
            val interceptionAnchor = activeAnchor(state)
            val resolvedTargets = state.activeSession?.resolvedTargets.orEmpty()
            return AccessibilityBlockingSnapshotPayload(
                isBlocking = blockedPresentationIsActive(state),
                sessionId = state.activeSession?.id,
                sessionState = state.activeSession?.state,
                sessionStartedAt = state.activeSession?.armedAt,
                modeName = activeMode(state)?.name,
                anchorName = interceptionAnchor?.displayName,
                targets = resolvedTargets
            )
        }

        fun empty(): AccessibilityBlockingSnapshotPayload =
            AccessibilityBlockingSnapshotPayload(
                isBlocking = false,
                sessionId = null,
                sessionState = null,
                sessionStartedAt = null,
                modeName = null,
                anchorName = null,
                targets = emptyList()
            )
    }
}
