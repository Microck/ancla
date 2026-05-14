package dev.micr.ancla.platform

import dev.micr.ancla.model.AppState
import dev.micr.ancla.model.AccessibilityBlockingSnapshotPayload
import dev.micr.ancla.model.BlockingInterception
import dev.micr.ancla.model.blockedPresentationIsActive
import dev.micr.ancla.model.blockingInterceptionForPackage
import java.time.Instant

data class AccessibilityBlockingSnapshot(
    val state: AppState,
    val nowProvider: () -> Instant = Instant::now
) {
    val isBlocking: Boolean
        get() = blockedPresentationIsActive(state, nowProvider())

    fun interceptionFor(packageName: String): BlockingInterception? =
        blockingInterceptionForPackage(state, packageName, nowProvider())

    fun toPayload(): AccessibilityBlockingSnapshotPayload =
        AccessibilityBlockingSnapshotPayload.fromState(state)

    companion object {
        fun empty(): AccessibilityBlockingSnapshot = AccessibilityBlockingSnapshot(state = AppState())
    }
}
