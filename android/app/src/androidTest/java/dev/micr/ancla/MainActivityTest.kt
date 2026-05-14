package dev.micr.ancla

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import android.content.Intent
import dev.micr.ancla.model.StaticInstalledAppCatalog
import dev.micr.ancla.model.demoBlockingTargets
import dev.micr.ancla.platform.AnchorScanException
import dev.micr.ancla.platform.AnchorScanner
import java.util.ArrayDeque
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import org.junit.Before
import org.junit.After
import org.junit.Rule
import org.junit.Test

class MainActivityTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Before
    fun installFakeCatalog() {
        MainActivity.installedAppCatalogFactoryOverride = { StaticInstalledAppCatalog(demoBlockingTargets()) }
    }

    @After
    fun clearOverrides() {
        MainActivity.anchorScannerFactoryOverride = null
        MainActivity.installedAppCatalogFactoryOverride = null
        MainActivity.accessibilityAuthorizationProviderOverride = null
    }

    private class MutableFakeScanner(
        initialAvailable: Boolean = true,
        scannedUids: List<String> = emptyList()
    ) : AnchorScanner {
        private val queue = ArrayDeque(scannedUids)
        var isAvailableNow: Boolean = initialAvailable

        override fun isAvailable(): Boolean = isAvailableNow

        override suspend fun scanAnchor(): String {
            if (!isAvailableNow) {
                throw AnchorScanException.Unavailable
            }
            return queue.removeFirst()
        }
    }

    private class DeferredFakeScanner(
        private val deferredUid: CompletableDeferred<String>
    ) : AnchorScanner {
        var wasCancelled = false

        override fun isAvailable(): Boolean = true

        override suspend fun scanAnchor(): String =
            try {
                deferredUid.await()
            } catch (_: CancellationException) {
                wasCancelled = true
                throw CancellationException()
            }
    }

    private fun installFakeScanner(vararg scannedUids: String) {
        val queue = ArrayDeque(scannedUids.toList())
        MainActivity.anchorScannerFactoryOverride = {
            object : AnchorScanner {
                override fun isAvailable(): Boolean = true

                override suspend fun scanAnchor(): String = queue.removeFirst()
            }
        }
    }

    private fun installMutableScanner(scanner: AnchorScanner) {
        MainActivity.anchorScannerFactoryOverride = { scanner }
    }

    @Test
    fun freshInstallShowsSetupGate() {
        composeRule.onNodeWithTag("setup-title").assertIsDisplayed()
        composeRule.onNodeWithText("Finish setup").assertIsDisplayed()
        composeRule.onNodeWithTag("setup-progress").assertIsDisplayed()
    }

    @Test
    fun acknowledgingManualSetupPersistsAndFocusMovesToAnchorStep() {
        composeRule.onNodeWithTag("acknowledge-blocking-setup").performClick()
        composeRule.onNodeWithText("No anchor yet").assertIsDisplayed()
        composeRule.onNodeWithText("Pair one NFC anchor.").assertIsDisplayed()
        composeRule.onNodeWithTag("setup-focus-hint").assertIsDisplayed()
    }

    @Test
    fun setupInstructionsAreAndroidSpecific() {
        composeRule.onNodeWithTag("android-setup-instructions").assertIsDisplayed()
        composeRule.onNodeWithText("No Screen Time or Shortcuts are involved on Android.")
            .assertIsDisplayed()
    }

    @Test
    fun enablingAccessibilityAutoCompletesBlockingSetup() {
        MainActivity.accessibilityAuthorizationProviderOverride = { true }

        composeRule.activityRule.scenario.recreate()

        composeRule.waitUntil(timeoutMillis = 5_000) {
            composeRule.onAllNodesWithTag("pair-anchor-from-setup").fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithText("No anchor yet").assertIsDisplayed()
        composeRule.onNodeWithTag("pair-anchor-from-setup").assertIsDisplayed()
    }

    @Test
    fun startRemainsDisabledUntilRuntimePrerequisitesAreSatisfied() {
        composeRule.onNodeWithTag("acknowledge-blocking-setup").performClick()
        composeRule.onNodeWithTag("setup-title").assertIsDisplayed()
        composeRule.onNodeWithText("No anchor yet").assertIsDisplayed()
    }

    @Test
    fun setupGateLetsUserAdvanceToModeCreationAfterPairingAnchor() {
        installFakeScanner("anchor-alpha")
        composeRule.onNodeWithTag("acknowledge-blocking-setup").performClick()
        composeRule.onNodeWithTag("pair-anchor-from-setup").performClick()
        composeRule.onNodeWithText("No mode yet").assertIsDisplayed()
        composeRule.onNodeWithTag("create-mode-from-setup").assertIsDisplayed()
        composeRule.onNodeWithTag("setup-focus-hint").assertIsDisplayed()
    }

    @Test
    fun setupGateCreateModeActionOpensModeEditor() {
        installFakeScanner("anchor-alpha")
        composeRule.onNodeWithTag("acknowledge-blocking-setup").performClick()
        composeRule.onNodeWithTag("pair-anchor-from-setup").performClick()
        composeRule.onNodeWithTag("create-mode-from-setup").performClick()
        composeRule.onNodeWithTag("mode-name-field").assertIsDisplayed()
        composeRule.onNodeWithTag("save-mode-dialog").assertIsDisplayed()
    }

    @Test
    fun savingModeFromSetupLeavesGateAndShowsSelectedModeOnHome() {
        installFakeScanner("anchor-alpha")
        composeRule.onNodeWithTag("acknowledge-blocking-setup").performClick()
        composeRule.onNodeWithTag("pair-anchor-from-setup").performClick()
        composeRule.onNodeWithTag("create-mode-from-setup").performClick()
        composeRule.onNodeWithTag("mode-name-field").performTextInput("Focus")
        composeRule.onNodeWithTag("target-slack").performClick()
        composeRule.onNodeWithTag("save-mode-dialog").performClick()

        composeRule.onNodeWithTag("home-title").assertIsDisplayed()
        composeRule.onNodeWithTag("mode-card-Focus").assertIsDisplayed()
        composeRule.onNodeWithTag("selected-mode-indicator").assertIsDisplayed()
        composeRule.onNodeWithTag("edit-selected-mode-button").assertIsDisplayed()
    }

    @Test
    fun dockTabsSwitchSectionsAfterSetupCompletes() {
        installFakeScanner("anchor-alpha")
        composeRule.onNodeWithTag("acknowledge-blocking-setup").performClick()
        composeRule.onNodeWithTag("pair-anchor-from-setup").performClick()
        composeRule.onNodeWithTag("create-mode-from-setup").performClick()
        composeRule.onNodeWithTag("mode-name-field").performTextInput("Focus")
        composeRule.onNodeWithTag("target-slack").performClick()
        composeRule.onNodeWithTag("save-mode-dialog").performClick()

        composeRule.onNodeWithTag("dock-tab-schedules").performClick()
        composeRule.onNodeWithText("Create schedule").assertIsDisplayed()

        composeRule.onNodeWithTag("dock-tab-anchors").performClick()
        composeRule.onNodeWithText("Pair another anchor").assertIsDisplayed()

        composeRule.onNodeWithTag("dock-tab-unlocks").performClick()
        composeRule.onNodeWithText("Create preset").assertIsDisplayed()

        composeRule.onNodeWithTag("dock-tab-modes").performClick()
        composeRule.onNodeWithTag("mode-card-Focus").assertIsDisplayed()
    }

    @Test
    fun startButtonShowsVisibleNfcUnavailableDialogWhenScannerTurnsOff() {
        val scanner = MutableFakeScanner(initialAvailable = true, scannedUids = listOf("anchor-alpha"))
        installMutableScanner(scanner)
        composeRule.onNodeWithTag("acknowledge-blocking-setup").performClick()
        composeRule.onNodeWithTag("pair-anchor-from-setup").performClick()
        composeRule.onNodeWithTag("create-mode-from-setup").performClick()
        composeRule.onNodeWithTag("mode-name-field").performTextInput("Focus")
        composeRule.onNodeWithTag("target-slack").performClick()
        composeRule.onNodeWithTag("save-mode-dialog").performClick()

        scanner.isAvailableNow = false

        composeRule.onNodeWithTag("start-button").performClick()
        composeRule.onNodeWithTag("anchor-scan-unavailable").assertIsDisplayed()
        composeRule.onNodeWithText("NFC unavailable").assertIsDisplayed()
    }

    @Test
    fun pairingScanRemainsActiveAfterWaitingStateTransition() {
        val deferredUid = CompletableDeferred<String>()
        val scanner = DeferredFakeScanner(deferredUid)
        installMutableScanner(scanner)

        composeRule.onNodeWithTag("acknowledge-blocking-setup").performClick()
        composeRule.onNodeWithTag("pair-anchor-from-setup").performClick()
        composeRule.onNodeWithTag("anchor-scan-dialog").assertIsDisplayed()
        composeRule.onNodeWithText("Waiting for an NFC tag…").assertIsDisplayed()
        composeRule.runOnIdle {
            check(!scanner.wasCancelled) {
                "Expected anchor scan to stay active after entering waiting state."
            }
            deferredUid.complete("anchor-alpha")
        }

        composeRule.waitUntil(timeoutMillis = 5_000) {
            composeRule.onAllNodesWithTag("create-mode-from-setup").fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.runOnIdle {
            check(!scanner.wasCancelled) {
                "Expected anchor scan to complete without cancellation."
            }
        }
        composeRule.onNodeWithTag("create-mode-from-setup").assertIsDisplayed()
    }

    @Test
    fun lockSurfaceLaunchShowsInterceptedTargetMetadata() {
        val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext
        val intent =
            Intent(context, MainActivity::class.java).apply {
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_PACKAGE, "com.slack")
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_TARGET_LABEL, "Slack")
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_MODE_NAME, "Work")
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_ANCHOR_NAME, "Desk anchor")
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_SESSION_ID, "55555555-5555-5555-5555-555555555555")
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_SESSION_STATE, "WRONG_ANCHOR")
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_SESSION_STARTED_AT, "2026-04-12T10:00:00Z")
            }

        composeRule.activityRule.scenario.onActivity { activity ->
            activity.intent = intent
        }

        composeRule.onNodeWithTag("lock-surface-target").assertIsDisplayed()
        composeRule.onNodeWithText("Blocked target: Slack").assertIsDisplayed()
        composeRule.onNodeWithTag("lock-surface-target-details").assertIsDisplayed()
        composeRule.onNodeWithTag("lock-surface-unlock-options").performClick()
        composeRule.onNodeWithTag("lock-surface-failsafe-button").assertIsDisplayed()
        composeRule.onNodeWithTag("wrong-anchor-feedback").assertIsDisplayed()
    }

    @Test
    fun incompleteLockSurfaceLaunchFallsBackToNormalHomeShell() {
        val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext
        val intent =
            Intent(context, MainActivity::class.java).apply {
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_PACKAGE, "com.slack")
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_TARGET_LABEL, "Slack")
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_MODE_NAME, "Work")
            }

        composeRule.activityRule.scenario.onActivity { activity ->
            activity.intent = intent
        }

        composeRule.onAllNodesWithTag("lock-surface-target").assertCountEquals(0)
    }
}
