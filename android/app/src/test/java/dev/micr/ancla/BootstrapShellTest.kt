package dev.micr.ancla

import dev.micr.ancla.model.ActiveSession
import dev.micr.ancla.model.AppSetupState
import dev.micr.ancla.model.AppState
import dev.micr.ancla.model.BlockMode
import dev.micr.ancla.model.BlockingTarget
import dev.micr.ancla.model.FakeAppStateStorage
import dev.micr.ancla.model.InMemoryAppRepository
import dev.micr.ancla.model.ModeDraft
import dev.micr.ancla.model.ModeDraftResult
import dev.micr.ancla.model.PairedAnchor
import dev.micr.ancla.model.PersistentAppRepository
import dev.micr.ancla.model.ReadinessBlocker
import dev.micr.ancla.model.ReadinessItemId
import dev.micr.ancla.model.ReleaseMethod
import dev.micr.ancla.model.SessionActionResult
import dev.micr.ancla.model.SessionState
import dev.micr.ancla.model.SetupDestination
import dev.micr.ancla.model.TargetKind
import dev.micr.ancla.model.activeAnchor
import dev.micr.ancla.model.anchorSummary
import dev.micr.ancla.model.firstIncompleteStep
import dev.micr.ancla.model.modeSummary
import dev.micr.ancla.model.modeSummaryLine
import dev.micr.ancla.model.readinessState
import dev.micr.ancla.model.repairState
import dev.micr.ancla.model.selectedMode
import dev.micr.ancla.model.setupDestination
import dev.micr.ancla.model.shouldShowSetupGate
import dev.micr.ancla.model.startGateState
import java.util.UUID
import kotlinx.collections.immutable.persistentListOf
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlinx.coroutines.runBlocking

class BootstrapShellTest {
    @Test
    fun setupFocusAdvancesToFirstIncompleteStep() {
        val blockedToolsPending = AppState()
        assertEquals(
            dev.micr.ancla.model.SetupStepId.BLOCKING_PERMISSION,
            firstIncompleteStep(blockedToolsPending)
        )

        val anchorPending =
            blockedToolsPending.copy(
                setup = AppSetupState(blockingToolsAcknowledged = true)
            )
        assertEquals(dev.micr.ancla.model.SetupStepId.ANCHOR, firstIncompleteStep(anchorPending))

        val modePending =
            anchorPending.copy(
                anchors = persistentListOf(PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor"))
            )
        assertEquals(dev.micr.ancla.model.SetupStepId.MODE, firstIncompleteStep(modePending))
    }

    @Test
    fun readinessBlockerPrecedenceIsStable() {
        val readyState = readyAppState()
        assertEquals(ReadinessBlocker.READY, readinessState(readyState).blocker)

        assertEquals(
            ReadinessBlocker.ACTIVE_SESSION,
            readinessState(
                readyState.copy(
                    activeSession =
                        ActiveSession(
                            modeId = readyState.modes.first().id,
                            anchorId = readyState.anchors.first().id,
                            state = SessionState.ARMED
                        )
                )
            ).blocker
        )

        assertEquals(
            ReadinessBlocker.MODE,
            readinessState(readyState.copy(modes = persistentListOf(), selectedModeId = null)).blocker
        )

        assertEquals(
            ReadinessBlocker.ANCHOR,
            readinessState(readyState.copy(anchors = persistentListOf())).blocker
        )

        assertEquals(
            ReadinessBlocker.BLOCKING_TOOLS,
            readinessState(readyState.copy(blockingAuthorized = false)).blocker
        )

        assertEquals(
            ReadinessBlocker.NFC,
            readinessState(readyState.copy(nfcAvailable = false, blockingAuthorized = false)).blocker
        )

        assertEquals(
            ReadinessBlocker.STORAGE,
            readinessState(readyState.copy(storageAvailable = false, nfcAvailable = false)).blocker
        )
    }

    @Test
    fun setupGateClearsOnlyAfterAllStepsButActiveSessionOverridesIt() {
        val incomplete = AppState()
        assertTrue(shouldShowSetupGate(incomplete))

        val complete = readyAppState()
        assertFalse(shouldShowSetupGate(complete))

        val activeButIncomplete =
            incomplete.copy(
                activeSession =
                    ActiveSession(
                        modeId = UUID.randomUUID(),
                        anchorId = UUID.randomUUID(),
                        state = SessionState.WRONG_ANCHOR
                    )
            )
        assertFalse(shouldShowSetupGate(activeButIncomplete))
    }

    @Test
    fun startGateRequiresRuntimePrerequisites() {
        val readyState = readyAppState()
        assertTrue(startGateState(readyState).canStart)

        assertEquals(
            "Pair at least one anchor before starting.",
            startGateState(readyState.copy(anchors = persistentListOf())).reason
        )
        assertEquals(
            "Create a mode before starting.",
            startGateState(readyState.copy(modes = persistentListOf(), selectedModeId = null)).reason
        )
        assertEquals(
            "A blocking session is already active.",
            startGateState(
                readyState.copy(
                    activeSession =
                        ActiveSession(
                            modeId = readyState.modes.first().id,
                            anchorId = readyState.anchors.first().id,
                            state = SessionState.ARMED
                        )
                )
            ).reason
        )
    }

    @Test
    fun repairedStatePromotesFirstModeToDefaultAndSelection() {
        val firstMode = mode("Work", default = false)
        val secondMode = mode("Deep work", default = false)

        val repaired =
            repairState(
                AppState(
                    modes = persistentListOf(firstMode, secondMode)
                )
            )

        assertTrue(repaired.modes.first().isDefault)
        assertEquals(firstMode.id, selectedMode(repaired)?.id)
    }

    @Test
    fun modeSummaryUsesAndroidRelevantAppAndBrowserLabels() {
        val summary =
            modeSummary(
                mode(
                    name = "Work",
                    default = true,
                    targets =
                        persistentListOf(
                            BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"),
                            BlockingTarget("chrome", "Chrome", TargetKind.BROWSER, "com.android.chrome")
                        )
                )
            )

        assertEquals("Only: Slack, Chrome", summary)
    }

    @Test
    fun setupDestinationTracksFirstIncompleteRequirement() {
        assertEquals(SetupDestination.BLOCKING_PERMISSION, setupDestination(AppState()))

        val anchorPending =
            AppState(
                blockingAuthorized = true,
                setup = AppSetupState(blockingToolsAcknowledged = true)
            )
        assertEquals(SetupDestination.ANCHOR, setupDestination(anchorPending))

        val modePending =
            anchorPending.copy(
                anchors = persistentListOf(PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor"))
            )
        assertEquals(SetupDestination.MODE, setupDestination(modePending))

        assertEquals(SetupDestination.COMPLETE, setupDestination(readyAppState()))
    }

    @Test
    fun readinessItemsExposeAllRequiredCategories() {
        val readiness = readinessState(readyAppState())

        assertEquals(
            listOf(
                ReadinessItemId.BLOCKING_CAPABILITY,
                ReadinessItemId.NFC,
                ReadinessItemId.STORAGE,
                ReadinessItemId.ANCHOR,
                ReadinessItemId.MODE,
                ReadinessItemId.SESSION
            ),
            readiness.items.map { it.id }
        )
    }

    @Test
    fun inMemoryRepositoryPersistsDefaultRepairAndSessionCleanupOnDelete() {
        val repository =
            InMemoryAppRepository(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true),
                    anchors = persistentListOf(PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")),
                    modes =
                        persistentListOf(
                            mode("Work", default = false),
                            mode("Calls", default = false)
                        )
                )
            )

        val firstModeId = repository.state.value.modes.first().id
        val secondModeId = repository.state.value.modes.last().id
        repository.selectMode(secondModeId)

        val repaired = repository.state.value
        assertTrue(repaired.modes.first().isDefault)
        assertEquals(secondModeId, selectedMode(repaired)?.id)

        repository.deleteMode(secondModeId)
        assertEquals(firstModeId, selectedMode(repository.state.value)?.id)
    }

    @Test
    fun persistentRepositoryKeepsAcknowledgmentAndModesAcrossReload() = runBlocking {
        val storage = FakeAppStateStorage()
        val repository = PersistentAppRepository.create(storage)

        repository.setBlockingAuthorization(true)
        repository.acknowledgeBlockingSetup()
        repository.pairAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val saveResult =
            repository.saveMode(
                ModeDraft(
                    name = "Work",
                    selectedTargetIds = setOf("com.slack"),
                    isDefault = true
                )
            )

        assertTrue(saveResult is ModeDraftResult.Saved)

        val reloaded = PersistentAppRepository.create(storage)
        assertTrue(reloaded.state.value.setup.blockingToolsAcknowledged)
        assertEquals(1, reloaded.state.value.anchors.size)
        assertEquals(1, reloaded.state.value.modes.size)
        assertNotNull(selectedMode(reloaded.state.value))
    }

    @Test
    fun summaryHelpersReflectAnchorAndModeReadinessCounts() {
        assertEquals("No anchors paired yet.", persistentListOf<PairedAnchor>().anchorSummary())
        assertEquals(
            "Desk anchor paired.",
            persistentListOf(PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")).anchorSummary()
        )
        assertEquals("No modes saved yet.", persistentListOf<BlockMode>().modeSummaryLine())
        assertEquals(
            "Work ready.",
            persistentListOf(mode("Work", default = true)).modeSummaryLine()
        )
    }

    @Test
    fun duplicateAnchorPairingIsRejectedAndFallbackNamingApplies() {
        val repository = InMemoryAppRepository()

        repository.pairAnchor(uid = "anchor-alpha", displayName = "   ")
        repository.pairAnchor(uid = "anchor-alpha", displayName = "Duplicate")
        repository.pairAnchor(uid = "anchor-bravo", displayName = "")

        assertEquals(listOf("Desk anchor", "Anchor 2"), repository.state.value.anchors.map { it.displayName })
        assertEquals(2, repository.state.value.anchors.size)
    }

    @Test
    fun renamingOnlyChangesChosenAnchorDisplayName() {
        val first = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val second = PairedAnchor(uid = "anchor-bravo", displayName = "Door anchor")
        val repository =
            InMemoryAppRepository(
                AppState(
                    anchors = persistentListOf(first, second)
                )
            )

        repository.renameAnchor(first.id, "Kitchen anchor")

        assertEquals("Kitchen anchor", repository.state.value.anchors.first { it.id == first.id }.displayName)
        assertEquals("Door anchor", repository.state.value.anchors.first { it.id == second.id }.displayName)
    }

    @Test
    fun armingBindsTheScannedAnchorAndWrongAnchorKeepsSessionRetryable() {
        val first = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val second = PairedAnchor(uid = "anchor-bravo", displayName = "Door anchor")
        val mode = mode("Work", default = true)
        val repository =
            InMemoryAppRepository(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true),
                    anchors = persistentListOf(first, second),
                    modes = persistentListOf(mode),
                    selectedModeId = mode.id
                )
            )

        assertEquals(SessionActionResult.Started, repository.armSession("anchor-bravo"))
        assertEquals(second.id, repository.state.value.activeSession?.anchorId)
        assertEquals("Door anchor", activeAnchor(repository.state.value)?.displayName)

        val wrongResult = repository.releaseSession("anchor-alpha")
        assertTrue(wrongResult is SessionActionResult.ValidationError)
        assertEquals(SessionState.WRONG_ANCHOR, repository.state.value.activeSession?.state)
        assertTrue(repository.state.value.sessionHistory.isEmpty())

        assertEquals(SessionActionResult.Released, repository.releaseSession("anchor-bravo"))
        assertEquals(null, repository.state.value.activeSession)
        assertEquals(1, repository.state.value.sessionHistory.size)
        val historyEntry = repository.state.value.sessionHistory.single()
        assertEquals("Door anchor", historyEntry.anchorName)
        assertEquals(mode.name, historyEntry.modeName)
        assertEquals(ReleaseMethod.ANCHOR, historyEntry.releaseMethod)
    }

    @Test
    fun removingOwningAnchorClearsSessionWithoutHistoryWhileInactiveRemovalLeavesSessionAlone() {
        val first = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val second = PairedAnchor(uid = "anchor-bravo", displayName = "Door anchor")
        val mode = mode("Work", default = true)
        val activeSession =
            ActiveSession(
                modeId = mode.id,
                anchorId = first.id,
                state = SessionState.ARMED
            )
        val repository =
            InMemoryAppRepository(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true),
                    anchors = persistentListOf(first, second),
                    modes = persistentListOf(mode),
                    selectedModeId = mode.id,
                    activeSession = activeSession
                )
            )

        repository.removeAnchor(second.id)
        assertEquals(activeSession.id, repository.state.value.activeSession?.id)
        assertEquals(1, repository.state.value.anchors.size)

        repository.removeAnchor(first.id)
        assertEquals(null, repository.state.value.activeSession)
        assertTrue(repository.state.value.sessionHistory.isEmpty())
    }

    @Test
    fun persistentRepositoryKeepsWrongAnchorStateCorrectReleaseHistoryAndForcedCleanupBehavior() = runBlocking {
        val storage = FakeAppStateStorage()
        val repository = PersistentAppRepository.create(storage)

        repository.setBlockingAuthorization(true)
        repository.acknowledgeBlockingSetup()
        repository.pairAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        repository.pairAnchor(uid = "anchor-bravo", displayName = "Door anchor")
        val saveResult =
            repository.saveMode(
                ModeDraft(
                    name = "Work",
                    selectedTargetIds = setOf("com.slack"),
                    isDefault = true
                )
            )
        assertTrue(saveResult is ModeDraftResult.Saved)

        assertEquals(SessionActionResult.Started, repository.armSession("anchor-alpha"))
        val boundSession = requireNotNull(repository.state.value.activeSession)
        assertEquals(
            SessionActionResult.ValidationError("That anchor does not match this session."),
            repository.releaseSession("anchor-bravo")
        )

        val reloadedAfterWrongScan = PersistentAppRepository.create(storage)
        assertEquals(SessionState.WRONG_ANCHOR, reloadedAfterWrongScan.state.value.activeSession?.state)
        assertEquals(boundSession.id, reloadedAfterWrongScan.state.value.activeSession?.id)
        assertTrue(reloadedAfterWrongScan.state.value.sessionHistory.isEmpty())

        assertEquals(SessionActionResult.Released, reloadedAfterWrongScan.releaseSession("anchor-alpha"))
        val releasedState = PersistentAppRepository.create(storage).state.value
        assertEquals(null, releasedState.activeSession)
        assertEquals(1, releasedState.sessionHistory.size)
        val releaseEntry = releasedState.sessionHistory.single()
        assertEquals(boundSession.id, releaseEntry.sessionId)
        assertEquals("Desk anchor", releaseEntry.anchorName)
        assertEquals("Work", releaseEntry.modeName)
        assertEquals(ReleaseMethod.ANCHOR, releaseEntry.releaseMethod)

        val cleanupStorage = FakeAppStateStorage()
        val cleanupRepository = PersistentAppRepository.create(cleanupStorage)
        cleanupRepository.setBlockingAuthorization(true)
        cleanupRepository.acknowledgeBlockingSetup()
        cleanupRepository.pairAnchor(uid = "anchor-charlie", displayName = "Shelf anchor")
        cleanupRepository.saveMode(
            ModeDraft(
                name = "Focus",
                selectedTargetIds = setOf("com.android.chrome"),
                isDefault = true
            )
        )
        assertEquals(SessionActionResult.Started, cleanupRepository.armSession("anchor-charlie"))
        val cleanupAnchorId = cleanupRepository.state.value.anchors.single().id

        cleanupRepository.removeAnchor(cleanupAnchorId)

        val cleanedState = PersistentAppRepository.create(cleanupStorage).state.value
        assertEquals(null, cleanedState.activeSession)
        assertTrue(cleanedState.sessionHistory.isEmpty())
    }

    @Test
    fun armingRejectsUnpairedAnchorsAndMissingPrerequisites() {
        val mode = mode("Work", default = true)
        val readyRepository =
            InMemoryAppRepository(
                AppState(
                    blockingAuthorized = true,
                    setup = AppSetupState(blockingToolsAcknowledged = true),
                    anchors = persistentListOf(PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")),
                    modes = persistentListOf(mode),
                    selectedModeId = mode.id
                )
            )
        val missingBlockingRepository = InMemoryAppRepository()

        assertEquals(
            SessionActionResult.ValidationError("That NFC anchor is not paired."),
            readyRepository.armSession("anchor-bravo")
        )
        assertEquals(
            SessionActionResult.ValidationError("Create a mode before starting."),
            missingBlockingRepository.armSession("anchor-alpha")
        )
    }

    private fun readyAppState(): AppState {
        val anchor = PairedAnchor(uid = "anchor-alpha", displayName = "Desk anchor")
        val mode = mode("Work", default = true)
        return repairState(
            AppState(
                blockingAuthorized = true,
                setup = AppSetupState(blockingToolsAcknowledged = true),
                anchors = persistentListOf(anchor),
                modes = persistentListOf(mode),
                selectedModeId = mode.id
            )
        )
    }

    private fun mode(
        name: String,
        default: Boolean,
        targets: kotlinx.collections.immutable.PersistentList<BlockingTarget> =
            persistentListOf(BlockingTarget("slack", "Slack", TargetKind.APP, "com.slack"))
    ): BlockMode = BlockMode(name = name, targets = targets, isDefault = default)
}
