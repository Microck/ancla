package dev.micr.ancla

import android.content.Context
import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.Settings
import android.net.Uri
import android.os.Bundle
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Code
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.LockOpen
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.WifiTethering
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import dev.micr.ancla.model.AndroidDataStoreAppStateStorage
import dev.micr.ancla.model.AndroidInstalledAppCatalog
import dev.micr.ancla.model.AppRepository
import dev.micr.ancla.model.AppState
import dev.micr.ancla.model.BlockScope
import dev.micr.ancla.model.BlockMode
import dev.micr.ancla.model.BlockingTarget
import dev.micr.ancla.model.InMemoryAppRepository
import dev.micr.ancla.model.InstalledAppCatalog
import dev.micr.ancla.model.ModeDraft
import dev.micr.ancla.model.ModeDraftResult
import dev.micr.ancla.model.PairedAnchor
import dev.micr.ancla.model.ParagraphChallenge
import dev.micr.ancla.model.ReadinessStatus
import dev.micr.ancla.model.ReleaseMethod
import dev.micr.ancla.model.ScheduleDraft
import dev.micr.ancla.model.ScheduleDraftResult
import dev.micr.ancla.model.SessionActionResult
import dev.micr.ancla.model.SessionHistoryEntry
import dev.micr.ancla.model.SetupStep
import dev.micr.ancla.model.SetupStepId
import dev.micr.ancla.model.SetupDestination
import dev.micr.ancla.model.ScheduledSessionPlan
import dev.micr.ancla.model.UnlockPreset
import dev.micr.ancla.model.UnlockPresetActivationResult
import dev.micr.ancla.model.UnlockPresetDraft
import dev.micr.ancla.model.UnlockPresetDraftResult
import dev.micr.ancla.model.activeAnchor
import dev.micr.ancla.model.activeSessionIsBlocking
import dev.micr.ancla.model.activeMode
import dev.micr.ancla.model.anchorSummary
import dev.micr.ancla.model.browserstackSeededAppState
import dev.micr.ancla.model.blockedPresentationIsActive
import dev.micr.ancla.model.canUseEmergencyUnbrick
import dev.micr.ancla.model.canUseParagraphChallenge
import dev.micr.ancla.model.firstIncompleteStep
import dev.micr.ancla.model.modeSummary
import dev.micr.ancla.model.modeSummaryLine
import dev.micr.ancla.model.PersistentAppRepository
import dev.micr.ancla.model.browserstackScheduleSeededAppState
import dev.micr.ancla.model.recentHistory
import dev.micr.ancla.model.selectedMode
import dev.micr.ancla.model.setupSteps
import dev.micr.ancla.model.shouldShowSetupGate
import dev.micr.ancla.model.temporaryUnlockIsActive
import dev.micr.ancla.model.startGateState
import dev.micr.ancla.model.nextScheduleTransitionAt
import dev.micr.ancla.platform.AccessibilityBlockingSnapshot
import dev.micr.ancla.platform.AnchorScanException
import dev.micr.ancla.platform.AnchorScanner
import dev.micr.ancla.platform.AndroidNfcDebugLog
import dev.micr.ancla.platform.AnclaAccessibilityService
import dev.micr.ancla.platform.AndroidNfcAnchorScanner
import dev.micr.ancla.ui.theme.AnclaTheme
import kotlinx.collections.immutable.persistentListOf
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

class MainActivity : ComponentActivity() {
    private val launchedLockSurfaceState = mutableStateOf<LockSurfaceLaunch?>(null)

    companion object {
        const val EXTRA_LOCK_SURFACE_PACKAGE = "dev.micr.ancla.lock_surface.package"
        const val EXTRA_LOCK_SURFACE_TARGET_LABEL = "dev.micr.ancla.lock_surface.target_label"
        const val EXTRA_LOCK_SURFACE_MODE_NAME = "dev.micr.ancla.lock_surface.mode_name"
        const val EXTRA_LOCK_SURFACE_ANCHOR_NAME = "dev.micr.ancla.lock_surface.anchor_name"
        const val EXTRA_LOCK_SURFACE_SESSION_ID = "dev.micr.ancla.lock_surface.session_id"
        const val EXTRA_LOCK_SURFACE_SESSION_STATE = "dev.micr.ancla.lock_surface.session_state"
        const val EXTRA_LOCK_SURFACE_SESSION_STARTED_AT = "dev.micr.ancla.lock_surface.session_started_at"

        @Volatile
        var anchorScannerFactoryOverride: (() -> AnchorScanner)? = null

        @Volatile
        var installedAppCatalogFactoryOverride: ((Context) -> InstalledAppCatalog)? = null

        @Volatile
        var accessibilityAuthorizationProviderOverride: ((Context) -> Boolean)? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AndroidNfcDebugLog.append("activity-create")
        launchedLockSurfaceState.value = intent?.toLockSurfaceLaunch()
        enableEdgeToEdge()
        setContent {
            val repositoryState = remember { mutableStateOf<AppRepository?>(null) }
            LaunchedEffect(Unit) {
                repositoryState.value =
                    if (BuildConfig.BROWSERSTACK_SCHEDULE_SEEDED_STATE) {
                        InMemoryAppRepository(browserstackScheduleSeededAppState())
                    } else if (BuildConfig.BROWSERSTACK_SEEDED_STATE) {
                        InMemoryAppRepository(browserstackSeededAppState())
                    } else {
                        PersistentAppRepository.create(
                            storage = AndroidDataStoreAppStateStorage(applicationContext),
                            installedAppCatalog =
                                installedAppCatalogFactoryOverride?.invoke(applicationContext)
                                    ?: AndroidInstalledAppCatalog(applicationContext)
                        )
                    }
            }
            AnclaTheme(darkTheme = true) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    repositoryState.value?.let { repository ->
                        AnclaApp(
                            repository = repository,
                            launchedLockSurface = launchedLockSurfaceState.value,
                            provideAnchorScanner = {
                                anchorScannerFactoryOverride?.invoke()
                                    ?: AndroidNfcAnchorScanner(this@MainActivity)
                            }
                        )
                    } ?: LoadingScreen()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        AndroidNfcDebugLog.append("activity-resume")
    }

    override fun onPause() {
        AndroidNfcDebugLog.append("activity-pause")
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchedLockSurfaceState.value = intent.toLockSurfaceLaunch()
    }
}

private enum class HomeSection(val title: String) {
    MODES("Mode"),
    ANCHORS("Anchor"),
    SCHEDULES("Schedule"),
    UNLOCKS("Unlock")
}

private fun homeSectionIcon(section: HomeSection): ImageVector =
    when (section) {
        HomeSection.MODES -> Icons.Outlined.GridView
        HomeSection.ANCHORS -> Icons.Outlined.WifiTethering
        HomeSection.SCHEDULES -> Icons.Outlined.CalendarMonth
        HomeSection.UNLOCKS -> Icons.Outlined.LockOpen
    }

private enum class SetupSection(val title: String, val setupStepId: SetupStepId) {
    BLOCKING("Blocking", SetupStepId.BLOCKING_PERMISSION),
    ANCHOR("Anchor", SetupStepId.ANCHOR),
    MODE("Mode", SetupStepId.MODE)
}

@Composable
fun AnclaApp(
    repository: AppRepository = remember { InMemoryAppRepository() },
    launchedLockSurface: LockSurfaceLaunch? = null,
    provideAnchorScanner: () -> AnchorScanner = {
        object : AnchorScanner {
            override fun isAvailable(): Boolean = false

            override suspend fun scanAnchor(): String {
                throw AnchorScanException.Unavailable
            }
        }
    }
) {
    val state by repository.state.collectAsState()
    val steps = remember(state) { setupSteps(state) }
    val startGate = remember(state) { startGateState(state) }
    val blockingSurfaceVisible = remember(state) { blockedPresentationIsActive(state) }
    val activeModeName = remember(state) { activeMode(state)?.name.orEmpty() }
    val activeAnchorName = remember(state) { activeAnchor(state)?.displayName.orEmpty() }
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var editorModeId by rememberSaveable { mutableStateOf<String?>(null) }
    var anchorEditorId by rememberSaveable { mutableStateOf<String?>(null) }
    var scanSheetState by remember { mutableStateOf<AnchorScanSheetState?>(null) }
    var scheduleEditorId by rememberSaveable { mutableStateOf<String?>(null) }
    var unlockPresetEditorId by rememberSaveable { mutableStateOf<String?>(null) }
    var paragraphChallengePresented by rememberSaveable { mutableStateOf(false) }
    var paragraphChallengeError by rememberSaveable { mutableStateOf<String?>(null) }
    var feedbackMessage by rememberSaveable { mutableStateOf<String?>(null) }
    var selectedHomeSection by rememberSaveable { mutableStateOf(HomeSection.MODES) }
    var selectedSetupSection by rememberSaveable { mutableStateOf(SetupSection.BLOCKING) }
    var unlockMenuPresented by rememberSaveable { mutableStateOf(false) }

    val editingMode = remember(editorModeId, state.modes) {
        editorModeId?.let { id -> state.modes.firstOrNull { it.id.toString() == id } }
    }
    val editingAnchor = remember(anchorEditorId, state.anchors) {
        anchorEditorId?.let { id -> state.anchors.firstOrNull { it.id.toString() == id } }
    }
    val editingSchedule = remember(scheduleEditorId, state.scheduledPlans) {
        scheduleEditorId?.takeUnless { it.isEmpty() }?.let { id -> state.scheduledPlans.firstOrNull { it.id.toString() == id } }
    }
    val editingUnlockPreset = remember(unlockPresetEditorId, state.unlockPresets) {
        unlockPresetEditorId?.takeUnless { it.isEmpty() }?.let { id -> state.unlockPresets.firstOrNull { it.id.toString() == id } }
    }

    LaunchedEffect(state.activeSession?.scheduleId, state.scheduledPlans, state.unlockPresets, state.temporaryUnlock?.expiresAt) {
        repository.evaluateSchedules()
    }

    LaunchedEffect(state.scheduledPlans, state.activeSession?.scheduleId) {
        val nextTransition = nextScheduleTransitionAt(state) ?: return@LaunchedEffect
        val delayMillis =
            java.time.Duration.between(Instant.now(), nextTransition).toMillis().coerceAtLeast(0L) + 250L

        kotlinx.coroutines.delay(delayMillis)
        repository.evaluateSchedules()
    }

    DisposableEffect(lifecycleOwner, repository) {
        fun refreshNfcAvailability() {
            repository.setNfcAvailability(provideAnchorScanner().isAvailable())
            repository.setBlockingAuthorization(context.isBlockingAuthorizationGranted())
        }

        refreshNfcAvailability()
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                refreshNfcAvailability()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    LaunchedEffect(state.blockingAuthorized, state.setup.blockingToolsAcknowledged) {
        if (state.blockingAuthorized && !state.setup.blockingToolsAcknowledged) {
            repository.acknowledgeBlockingSetup()
        }
    }

    LaunchedEffect(steps) {
        selectedSetupSection =
            when (firstIncompleteStep(state)) {
                SetupStepId.BLOCKING_PERMISSION, null -> SetupSection.BLOCKING
                SetupStepId.ANCHOR -> SetupSection.ANCHOR
                SetupStepId.MODE -> SetupSection.MODE
            }
    }

    LaunchedEffect(blockingSurfaceVisible) {
        if (!blockingSurfaceVisible) {
            unlockMenuPresented = false
        }
    }

    LaunchedEffect(feedbackMessage) {
        val visibleMessage = feedbackMessage ?: return@LaunchedEffect
        kotlinx.coroutines.delay(if (visibleMessage.length > 72) 2_800L else 2_400L)
        if (feedbackMessage == visibleMessage) {
            feedbackMessage = null
        }
    }

    Scaffold { innerPadding ->
        if (blockingSurfaceVisible) {
            LockSurfaceScreen(
                state = state,
                launchedLockSurface = launchedLockSurface,
                unlockMenuPresented = unlockMenuPresented,
                feedbackMessage = feedbackMessage,
                onLockedSurfaceTap = { scanSheetState = AnchorScanSheetState(mode = AnchorScanMode.RELEASE) },
                onToggleUnlockMenu = { unlockMenuPresented = !unlockMenuPresented },
                onEmergencyUnbrick = {
                    when (val result = repository.useEmergencyUnbrick()) {
                        SessionActionResult.Released -> feedbackMessage = "Emergency unbrick used. Session released."
                        is SessionActionResult.ValidationError -> feedbackMessage = result.message
                        else -> Unit
                    }
                },
                onOpenParagraphChallenge = {
                    paragraphChallengeError = null
                    paragraphChallengePresented = true
                },
                onActivateUnlockPreset = { preset ->
                    when (val result = repository.activateUnlockPreset(preset.id)) {
                        UnlockPresetActivationResult.Activated ->
                            feedbackMessage = "\"${preset.title}\" unlocked this session for ${preset.durationSeconds} seconds."
                        is UnlockPresetActivationResult.ValidationError -> feedbackMessage = result.message
                    }
                    unlockMenuPresented = false
                },
                modifier = Modifier.padding(innerPadding)
            )
        } else if (shouldShowSetupGate(state)) {
            SetupGateScreen(
                state = state,
                steps = steps,
                selectedSection = selectedSetupSection,
                onSelectSection = { selectedSetupSection = it },
                onAcknowledgeBlockingSetup = repository::acknowledgeBlockingSetup,
                onPairAnchor = {
                    feedbackMessage = null
                    scanSheetState = AnchorScanSheetState(mode = AnchorScanMode.PAIR)
                },
                onOpenCreateMode = { editorModeId = "" },
                modifier = Modifier.padding(innerPadding)
            )
        } else {
            LaunchedEffect(state.temporaryUnlock?.expiresAt, activeModeName, activeAnchorName) {
                val expiresAt = state.temporaryUnlock?.expiresAt ?: return@LaunchedEffect
                val delayMillis = java.time.Duration.between(Instant.now(), expiresAt).toMillis().coerceAtLeast(0L)
                kotlinx.coroutines.delay(delayMillis)
                repository.expireTemporaryUnlock()
                if (activeSessionIsBlocking(repository.state.value)) {
                    feedbackMessage = "Temporary unlock ended. \"$activeModeName\" is blocking again with $activeAnchorName."
                }
            }
            val refreshHomeChrome: () -> Unit = {
                repository.setNfcAvailability(provideAnchorScanner().isAvailable())
                repository.evaluateSchedules()
                feedbackMessage = "Status refreshed."
            }
            HomeScreen(
                state = state,
                selectedSection = selectedHomeSection,
                onSelectSection = { selectedHomeSection = it },
                canStart = startGate.canStart,
                isPrimaryActionLoading = scanSheetState?.status in setOf(AnchorScanStatus.STARTING, AnchorScanStatus.WAITING),
                feedbackMessage = feedbackMessage,
                onRefreshHeader = refreshHomeChrome,
                onPairAnchor = {
                    feedbackMessage = null
                    scanSheetState = AnchorScanSheetState(mode = AnchorScanMode.PAIR)
                },
                onRenameAnchor = { anchor -> anchorEditorId = anchor.id.toString() },
                onRemoveAnchor = { anchor -> repository.removeAnchor(anchor.id) },
                onStartScan = { scanSheetState = AnchorScanSheetState(mode = AnchorScanMode.ARM) },
                onReleaseScan = { scanSheetState = AnchorScanSheetState(mode = AnchorScanMode.RELEASE) },
                onSelectMode = repository::selectMode,
                onDeleteMode = repository::deleteMode,
                onOpenCreateMode = { editorModeId = "" },
                onOpenEditMode = { mode -> editorModeId = mode.id.toString() },
                onOpenCreateSchedule = { scheduleEditorId = "" },
                onOpenEditSchedule = { plan -> scheduleEditorId = plan.id.toString() },
                onDeleteSchedule = repository::deleteSchedule,
                onOpenCreateUnlockPreset = { unlockPresetEditorId = "" },
                onOpenEditUnlockPreset = { preset -> unlockPresetEditorId = preset.id.toString() },
                onDeleteUnlockPreset = repository::deleteUnlockPreset,
                onAdjustEmergencyUnbricks = repository::adjustEmergencyUnbricks,
                onSetParagraphChallengeEnabled = repository::setParagraphChallengeEnabled,
                modifier = Modifier.padding(innerPadding)
            )
        }
    }

    if (editorModeId != null) {
        ModeEditorDialog(
            existingMode = editingMode,
            repository = repository,
            onDismiss = { editorModeId = null }
        )
    }

    if (paragraphChallengePresented) {
        ParagraphChallengeDialog(
            challenge = state.paragraphChallenges.firstOrNull(),
            validationMessage = paragraphChallengeError,
            onDismiss = {
                paragraphChallengeError = null
                paragraphChallengePresented = false
            },
            onSubmit = { typedPassage ->
                when (val result = repository.submitParagraphChallenge(typedPassage)) {
                    SessionActionResult.Released -> {
                        paragraphChallengeError = null
                        feedbackMessage = "Failsafe challenge passed. Session released."
                        paragraphChallengePresented = false
                    }
                    is SessionActionResult.ValidationError -> {
                        paragraphChallengeError = result.message
                        feedbackMessage = result.message
                    }
                    else -> Unit
                }
            }
        )
    }

    if (anchorEditorId != null) {
        RenameAnchorDialog(
            anchor = editingAnchor,
            onDismiss = { anchorEditorId = null },
            onConfirm = { anchor, name ->
                repository.renameAnchor(anchor.id, name)
                feedbackMessage = "Anchor renamed to ${repository.state.value.anchors.first { it.id == anchor.id }.displayName}."
                anchorEditorId = null
            }
        )
    }

    if (scheduleEditorId != null) {
        ScheduleEditorDialog(
            existingSchedule = editingSchedule,
            repository = repository,
            onDismiss = { scheduleEditorId = null }
        )
    }

    if (unlockPresetEditorId != null) {
        UnlockPresetEditorDialog(
            existingPreset = editingUnlockPreset,
            repository = repository,
            onDismiss = { unlockPresetEditorId = null }
        )
    }

    scanSheetState?.let { dialogState ->
        AnchorScanDialog(
            anchors = state.anchors,
            dialogState = dialogState,
            onDismiss = {
                AndroidNfcDebugLog.append(
                    "sheet-dismiss",
                    "mode=${dialogState.mode} status=${dialogState.status}"
                )
                if (dialogState.status == AnchorScanStatus.STARTING || dialogState.status == AnchorScanStatus.WAITING) {
                    feedbackMessage = "Anchor scan canceled."
                }
                scanSheetState = null
            }
        )
        LaunchedEffect(dialogState.diagnosticsSessionId, dialogState.mode) {
            if (dialogState.status != AnchorScanStatus.STARTING) {
                return@LaunchedEffect
            }
            // Keep the scan coroutine scoped to a single dialog session. Including status here
            // would cancel the active NFC read as soon as STARTING transitions to WAITING.
            AndroidNfcDebugLog.resetSession(
                "mode=${dialogState.mode} scanSession=${dialogState.diagnosticsSessionId}"
            )
            val scanner = provideAnchorScanner()
            AndroidNfcDebugLog.append("sheet-scanner-created", scanner::class.java.name)
            repository.setNfcAvailability(scanner.isAvailable())
            AndroidNfcDebugLog.append("sheet-nfc-availability", scanner.isAvailable().toString())
            if (!scanner.isAvailable()) {
                AndroidNfcDebugLog.append("sheet-unavailable-before-scan")
                scanSheetState =
                    dialogState.copy(
                        status = AnchorScanStatus.UNAVAILABLE,
                        message = "NFC is unavailable on this Android phone. Turn it on in settings, then try again."
                    )
                return@LaunchedEffect
            }

            AndroidNfcDebugLog.append("sheet-status", "waiting")
            scanSheetState = dialogState.copy(status = AnchorScanStatus.WAITING)
            try {
                val scannedUid = scanner.scanAnchor()
                AndroidNfcDebugLog.append("sheet-scan-success", "uid=$scannedUid")
                feedbackMessage = processAnchorScanResult(dialogState.mode, scannedUid, state, repository)
                feedbackMessage?.let { AndroidNfcDebugLog.append("sheet-result-message", it) }
                scanSheetState = null
            } catch (cancellation: CancellationException) {
                AndroidNfcDebugLog.append("sheet-scan-cancelled")
                throw cancellation
            } catch (_: AnchorScanException.Unavailable) {
                repository.setNfcAvailability(false)
                AndroidNfcDebugLog.append("sheet-scan-unavailable-exception")
                scanSheetState =
                    dialogState.copy(
                        status = AnchorScanStatus.UNAVAILABLE,
                        message = "NFC is unavailable on this Android phone. Turn it on in settings, then try again."
                    )
            } catch (_: AnchorScanException.UnsupportedTag) {
                AndroidNfcDebugLog.append("sheet-scan-unsupported-tag")
                scanSheetState =
                    dialogState.copy(
                        status = AnchorScanStatus.FAILURE,
                        message = "This NFC anchor could not be read. Hold the phone closer or try another tag."
                    )
            } catch (error: IllegalStateException) {
                AndroidNfcDebugLog.append(
                    "sheet-scan-illegal-state",
                    error.message ?: error::class.java.name
                )
                scanSheetState =
                    dialogState.copy(
                        status = AnchorScanStatus.FAILURE,
                        message = error.message ?: "Anchor scan failed."
                    )
            }
        }
    }

}

@Composable
private fun LoadingScreen() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text("Loading Ancla Android…")
    }
}

@Composable
private fun SetupGateScreen(
    state: AppState,
    steps: List<SetupStep>,
    selectedSection: SetupSection,
    onSelectSection: (SetupSection) -> Unit,
    onAcknowledgeBlockingSetup: () -> Unit,
    onPairAnchor: () -> Unit,
    onOpenCreateMode: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    androidx.compose.foundation.layout.BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val compactScreen = maxHeight < 760.dp || maxWidth < 380.dp
        val horizontalPadding = if (compactScreen) 20.dp else 24.dp
        val topPadding = if (compactScreen) 16.dp else 20.dp
        val contentSpacing = if (compactScreen) 20.dp else 24.dp

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = horizontalPadding, vertical = topPadding),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Spacer(modifier = Modifier.size(width = 42.dp, height = 18.dp))
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = "Finish setup",
                        style = MaterialTheme.typography.headlineSmall,
                        modifier = Modifier.testTag("setup-title")
                    )
                    Text(
                        text = "Three steps.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Spacer(modifier = Modifier.size(width = 42.dp, height = 18.dp))
            }

            Row(
                modifier = Modifier.padding(horizontal = horizontalPadding),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                SetupSection.entries.forEach { section ->
                    val step = steps.first { it.id == section.setupStepId }
                    SetupTab(
                        title = section.title,
                        selected = selectedSection == section,
                        status = step.status,
                        onClick = { onSelectSection(section) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = horizontalPadding, vertical = contentSpacing),
                verticalArrangement = Arrangement.spacedBy(contentSpacing)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "${steps.count { it.status == ReadinessStatus.READY }} / ${steps.size} ready",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.testTag("setup-progress")
                    )
                    if (steps.all { it.status == ReadinessStatus.READY }) {
                        Text(
                            text = "All set",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }

                when (selectedSection) {
                    SetupSection.BLOCKING -> {
                        SetupStatusLine(
                            title = if (state.blockingAuthorized) "Accessibility ready" else "Accessibility not ready",
                            detail =
                                if (state.blockingAuthorized && state.setup.blockingToolsAcknowledged) {
                                    "Android blocking is configured for this phone."
                                } else if (state.blockingAuthorized) {
                                    "Accessibility permission is enabled. Confirm the final Android setup step here."
                                } else {
                                    "Grant Ancla the Android accessibility permission, then confirm setup here."
                                }
                        )
                        if (!state.blockingAuthorized) {
                            SetupActionRow(
                                icon = Icons.Outlined.Code,
                                title = "Open accessibility settings",
                                detail = "Grant the Android permission Ancla needs to block apps.",
                                tag = "open-blocking-settings",
                                onClick = {
                                    context.startActivity(
                                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    )
                                }
                            )
                        }
                        if (state.setup.blockingToolsAcknowledged) {
                            SetupActionRow(
                                icon = Icons.Filled.CheckCircle,
                                title = "Review Android setup",
                                detail = "No Screen Time or Shortcuts are involved on Android.",
                                tag = "acknowledge-blocking-setup",
                                onClick = onAcknowledgeBlockingSetup
                            )
                        } else {
                            SetupPrimaryButton(
                                title = "Done",
                                tag = "acknowledge-blocking-setup",
                                onClick = onAcknowledgeBlockingSetup
                            )
                            Text(
                                text = "No Screen Time or Shortcuts are involved on Android.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Text(
                            text = "1. Enable Ancla in Android accessibility settings.\n2. Return here. If Android reports the service as ready, this step finishes automatically.\n3. Pair an anchor and create one mode with the app scope you want blocked.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.testTag("android-setup-instructions")
                        )
                    }

                    SetupSection.ANCHOR -> {
                        SetupStatusLine(
                            title =
                                when {
                                    !state.nfcAvailable -> "Turn on NFC"
                                    state.anchors.isEmpty() -> "No anchor yet"
                                    else -> "${state.anchors.size} paired"
                                },
                            detail =
                                when {
                                    !state.nfcAvailable -> "Turn on NFC on this Android phone before pairing or scanning an anchor."
                                    state.anchors.isEmpty() -> "Pair one NFC anchor for this Android phone."
                                    else -> state.anchors.joinToString(" • ") { it.displayName }
                                }
                        )
                        if (!state.nfcAvailable) {
                            SetupActionRow(
                                icon = Icons.Outlined.Settings,
                                title = "Open NFC settings",
                                detail = "Enable NFC on this Android phone before pairing.",
                                tag = "open-nfc-settings",
                                onClick = { context.openNfcSettings() }
                            )
                        }
                        SetupActionRow(
                            icon = Icons.Outlined.WifiTethering,
                            title = if (state.anchors.isEmpty()) "Pair anchor" else "Pair another anchor",
                            detail = "Scan it on this Android phone with NFC enabled.",
                            tag = "pair-anchor-from-setup",
                            onClick = onPairAnchor
                        )
                    }

                    SetupSection.MODE -> {
                        SetupStatusLine(
                            title = if (state.modes.isEmpty()) "No mode yet" else "${state.modes.size} ready",
                            detail =
                                if (state.modes.isEmpty()) {
                                    "Create one mode with the Android app scope you want blocked."
                                } else {
                                    state.modes.joinToString(" • ") { "${it.name}: ${modeSummary(it)}" }
                                }
                        )
                        SetupActionRow(
                            icon = Icons.Filled.Add,
                            title = if (state.modes.isEmpty()) "Create mode" else "Add mode",
                            detail = "Choose only, all except, or all installed apps.",
                            tag = "create-mode-from-setup",
                            onClick = onOpenCreateMode
                        )
                    }
                }

                SetupFocusHint(
                    destination =
                        when (firstIncompleteStep(state)) {
                            SetupStepId.BLOCKING_PERMISSION, null -> SetupDestination.BLOCKING_PERMISSION
                            SetupStepId.ANCHOR -> SetupDestination.ANCHOR
                            SetupStepId.MODE -> SetupDestination.MODE
                        }
                )
            }
        }
    }
}

@Composable
private fun SetupTab(
    title: String,
    selected: Boolean,
    status: ReadinessStatus,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(38.dp)
                .clickable(onClick = onClick),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            StatusDot(status)
            Text(
                title,
                color =
                    if (selected) MaterialTheme.colorScheme.onSurface
                    else MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        HorizontalDivider(
            color =
                if (selected) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                else MaterialTheme.colorScheme.outline.copy(alpha = 0.6f)
        )
    }
}

@Composable
private fun SetupStatusLine(title: String, detail: String) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(title, style = MaterialTheme.typography.headlineSmall)
        Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    HorizontalDivider(modifier = Modifier.padding(top = 8.dp))
}

@Composable
private fun SetupActionRow(
    icon: ImageVector,
    title: String,
    detail: String,
    tag: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp)
            .testTag(tag),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Surface(
            shape = CircleShape,
            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.14f),
            modifier = Modifier.size(38.dp)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(14.dp)
        )
    }
    HorizontalDivider()
}

@Composable
private fun SetupPrimaryButton(
    title: String,
    tag: String,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().testTag(tag),
        shape = RoundedCornerShape(18.dp),
        colors =
            ButtonDefaults.buttonColors(
                containerColor = Color.White,
                contentColor = Color.Black
            ),
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 16.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium
        )
    }
}

@Composable
private fun SetupFocusHint(destination: SetupDestination) {
    val message =
        when (destination) {
            SetupDestination.BLOCKING_PERMISSION -> "Focus: finish Android blocking setup first."
            SetupDestination.ANCHOR -> "Focus: pair an anchor next."
            SetupDestination.MODE -> "Focus: create a blocking mode next."
            SetupDestination.COMPLETE -> "All setup steps are complete."
        }
    Text(
        text = message,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.testTag("setup-focus-hint")
    )
}

@Composable
private fun HomeScreen(
    state: AppState,
    selectedSection: HomeSection,
    onSelectSection: (HomeSection) -> Unit,
    canStart: Boolean,
    isPrimaryActionLoading: Boolean,
    feedbackMessage: String?,
    onRefreshHeader: () -> Unit,
    onPairAnchor: () -> Unit,
    onRenameAnchor: (PairedAnchor) -> Unit,
    onRemoveAnchor: (PairedAnchor) -> Unit,
    onStartScan: () -> Unit,
    onReleaseScan: () -> Unit,
    onSelectMode: (java.util.UUID) -> Unit,
    onDeleteMode: (java.util.UUID) -> Unit,
    onOpenCreateMode: () -> Unit,
    onOpenEditMode: (BlockMode) -> Unit,
    onOpenCreateSchedule: () -> Unit,
    onOpenEditSchedule: (ScheduledSessionPlan) -> Unit,
    onDeleteSchedule: (java.util.UUID) -> Unit,
    onOpenCreateUnlockPreset: () -> Unit,
    onOpenEditUnlockPreset: (UnlockPreset) -> Unit,
    onDeleteUnlockPreset: (java.util.UUID) -> Unit,
    onAdjustEmergencyUnbricks: (Int) -> Unit,
    onSetParagraphChallengeEnabled: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    val currentSelectedMode = selectedMode(state)
    val currentActiveMode = activeMode(state)
    val currentActiveAnchor = activeAnchor(state)
    val blockingNow = activeSessionIsBlocking(state)
    val tempUnlockActive = temporaryUnlockIsActive(state)
    val recentSessionHistory = recentHistory(state, limit = 5)
    val activeTemporaryUnlock = state.temporaryUnlock
    val context = LocalContext.current
    val primaryButtonLabel =
        when {
            blockingNow -> "End block"
            !state.nfcAvailable -> "Turn on NFC"
            state.anchors.isEmpty() -> "Pair anchor"
            state.modes.isEmpty() -> "Create mode"
            canStart -> "Start block"
            else -> "Start block"
        }
    val primaryAction: () -> Unit =
        when {
            blockingNow -> onReleaseScan
            state.anchors.isEmpty() -> onPairAnchor
            state.modes.isEmpty() -> onOpenCreateMode
            else -> onStartScan
        }
    val primaryButtonEnabled =
        blockingNow || state.anchors.isEmpty() || state.modes.isEmpty() || canStart || !state.nfcAvailable

    androidx.compose.foundation.layout.BoxWithConstraints(
        modifier = modifier.fillMaxSize()
    ) {
        val compactScreen = maxHeight < 760.dp || maxWidth < 380.dp
        val horizontalPadding = if (compactScreen) 16.dp else 24.dp
        val verticalPadding = if (compactScreen) 12.dp else 24.dp
        val dockToastPadding = if (compactScreen) 118.dp else 132.dp

        Box(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(horizontal = horizontalPadding, vertical = verticalPadding)
        ) {
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(if (compactScreen) 14.dp else 18.dp)
            ) {
                HomeHeader(
                    onRefreshHeader = onRefreshHeader,
                    onOpenRepository = {
                        context.startActivity(
                            Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("https://github.com/Microck/ancla")
                            )
                        )
                    }
                )
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    if (tempUnlockActive && activeTemporaryUnlock != null) {
                        HomeBanner(
                            title = "Preset unlock active",
                            detail = "${activeTemporaryUnlock.reason} • ${temporaryUnlockRemainingSeconds(state)}s left",
                            accent = MaterialTheme.colorScheme.primary,
                            tag = "temporary-unlock-banner"
                        )
                    }
                    when (selectedSection) {
                        HomeSection.MODES -> {
                            HomeHero(
                                content =
                                    homeHeroContent(
                                        state = state,
                                        selectedModeName = currentSelectedMode?.name ?: currentActiveMode?.name,
                                        activeAnchorName = currentActiveAnchor?.displayName
                                    ),
                                compact = compactScreen
                            )
                            if (state.modes.isEmpty()) {
                                HomeInfoRow(
                                    title = "No modes saved",
                                    detail = "Create one block setup first.",
                                    trailingIcon = Icons.Filled.Add,
                                    accent = MaterialTheme.colorScheme.onSurface,
                                    tag = "empty-modes"
                                )
                            } else {
                                state.modes.forEach { mode ->
                                    ModeCard(
                                        mode = mode,
                                        isSelected = currentSelectedMode?.id == mode.id,
                                        isActive = currentActiveMode?.id == mode.id,
                                        onSelect = { onSelectMode(mode.id) },
                                        onEdit = { onOpenEditMode(mode) },
                                        onDelete = { onDeleteMode(mode.id) }
                                    )
                                }
                            }
                            currentSelectedMode?.let { selectedMode ->
                                HomeSectionAction(
                                    icon = Icons.Outlined.Edit,
                                    title = "Edit selected mode",
                                    detail = "Adjust the mode that will start next.",
                                    tag = "edit-selected-mode-button",
                                    onClick = { onOpenEditMode(selectedMode) }
                                )
                            }
                            HomeSectionAction(
                                icon = Icons.Filled.Add,
                                title = "Create mode",
                                detail = "Add another saved block setup.",
                                tag = "create-mode-button",
                                onClick = onOpenCreateMode
                            )
                        }

                        HomeSection.ANCHORS -> {
                            if (state.anchors.isEmpty()) {
                                HomeInfoRow(
                                    title = "No anchor paired",
                                    detail = "Pair one NFC anchor for this Android phone.",
                                    trailingIcon = Icons.Outlined.WifiTethering,
                                    accent = MaterialTheme.colorScheme.onSurface,
                                    tag = "empty-anchors"
                                )
                            } else {
                                state.anchors.forEach { anchor ->
                                    AnchorRow(
                                        anchor = anchor,
                                        isActive = currentActiveAnchor?.id == anchor.id,
                                        onRename = { onRenameAnchor(anchor) },
                                        onRemove = { onRemoveAnchor(anchor) }
                                    )
                                }
                            }
                            HomeSectionAction(
                                icon = Icons.Outlined.WifiTethering,
                                title = if (state.anchors.isEmpty()) "Pair anchor" else "Pair another anchor",
                                detail = "Scan an NFC anchor on this Android phone.",
                                tag = "pair-anchor-button",
                                onClick = onPairAnchor
                            )
                        }

                        HomeSection.SCHEDULES -> {
                            if (state.scheduledPlans.isEmpty()) {
                                HomeInfoRow(
                                    title = "No schedules saved",
                                    detail =
                                        if (state.modes.isEmpty() || state.anchors.isEmpty()) {
                                            "Pair an anchor and save a mode first."
                                        } else {
                                            "Auto-start a saved mode on selected days."
                                        },
                                    trailingIcon = Icons.Outlined.CalendarMonth,
                                    accent = MaterialTheme.colorScheme.onSurface,
                                    tag = "empty-schedules"
                                )
                            } else {
                                state.scheduledPlans.forEach { plan ->
                                    ScheduleCard(
                                        plan = plan,
                                        state = state,
                                        isActive = state.activeSession?.scheduleId == plan.id,
                                        onEdit = { onOpenEditSchedule(plan) },
                                        onDelete = { onDeleteSchedule(plan.id) }
                                    )
                                }
                            }
                            HomeSectionAction(
                                icon = Icons.Outlined.CalendarMonth,
                                title = "Create schedule",
                                detail = "Auto-start a saved mode on selected days.",
                                tag = "create-schedule-button",
                                onClick = onOpenCreateSchedule
                            )
                        }

                        HomeSection.UNLOCKS -> {
                            HomeInfoRow(
                                title = sessionSectionTitle(state),
                                detail = sessionSectionDetail(state, currentActiveMode?.name, currentActiveAnchor?.displayName),
                                trailingText = sessionSectionBadge(state),
                                accent =
                                    when {
                                        tempUnlockActive -> MaterialTheme.colorScheme.primary
                                        blockingNow -> MaterialTheme.colorScheme.tertiary
                                        else -> MaterialTheme.colorScheme.onSurface
                                    }
                            )
                            CompactSectionTitle("Failsafe")
                            FailsafeCountRow(
                                remaining = state.emergencyUnbricksRemaining,
                                detail = emergencyUnbrickDetail(state),
                                accent =
                                    if (state.emergencyUnbricksRemaining == 0) {
                                        MaterialTheme.colorScheme.error
                                    } else {
                                        MaterialTheme.colorScheme.onSurface
                                    },
                                onDecrease = { onAdjustEmergencyUnbricks(-1) },
                                onIncrease = { onAdjustEmergencyUnbricks(1) }
                            )
                            ParagraphChallengeToggleRow(
                                isEnabled = state.paragraphChallengeEnabled,
                                detail =
                                    if (canUseParagraphChallenge(state)) {
                                        "Failsafes are empty. Type the stored passage exactly."
                                    } else if (!state.paragraphChallengeEnabled) {
                                        "Turn this on to keep the typing unlock ready."
                                    } else {
                                        "This appears only after failsafes hit zero."
                                    },
                                accent =
                                    if (state.paragraphChallengeEnabled) {
                                        MaterialTheme.colorScheme.onSurface
                                    } else {
                                        MaterialTheme.colorScheme.onSurfaceVariant
                                    },
                                onToggle = onSetParagraphChallengeEnabled
                            )
                            CompactSectionTitle("Presets")
                            if (state.unlockPresets.isEmpty()) {
                                HomeInfoRow(
                                    title = "No presets saved",
                                    detail = "Save a short unlock like checking 2FA.",
                                    trailingIcon = Icons.Outlined.LockOpen,
                                    accent = MaterialTheme.colorScheme.onSurface,
                                    tag = "empty-unlock-presets"
                                )
                            } else {
                                state.unlockPresets.forEach { preset ->
                                    UnlockPresetCard(
                                        preset = preset,
                                        state = state,
                                        onEdit = { onOpenEditUnlockPreset(preset) },
                                        onDelete = { onDeleteUnlockPreset(preset.id) }
                                    )
                                }
                            }
                            HomeSectionAction(
                                icon = Icons.Outlined.LockOpen,
                                title = "Create preset",
                                detail = "Add a short timed unlock.",
                                tag = "create-unlock-preset-button",
                                onClick = onOpenCreateUnlockPreset
                            )
                            CompactSectionTitle("Recent")
                            if (recentSessionHistory.isEmpty()) {
                                HomeInfoRow(
                                    title = "No sessions recorded",
                                    detail = "Completed sessions will appear here after they end.",
                                    trailingIcon = Icons.Filled.Refresh,
                                    accent = MaterialTheme.colorScheme.onSurface,
                                    tag = "empty-history"
                                )
                            } else {
                                recentSessionHistory.forEach { entry ->
                                    HistoryEntryCard(entry = entry)
                                }
                            }
                        }
                    }
                }
                HomeDock(
                    selectedSection = selectedSection,
                    onSelectSection = onSelectSection,
                    primaryButtonLabel = primaryButtonLabel,
                    primaryButtonIcon = Icons.Filled.Add,
                    primaryButtonEnabled = primaryButtonEnabled,
                    isPrimaryActionLoading = isPrimaryActionLoading,
                    primaryAction = primaryAction
                )
            }
            feedbackMessage?.let { message ->
                FeedbackToast(
                    message = message,
                    modifier =
                        Modifier
                            .align(Alignment.BottomCenter)
                            .padding(horizontal = horizontalPadding, vertical = dockToastPadding)
                            .testTag("action-feedback")
                )
            }
        }
    }
}

@Composable
private fun HomeHeader(
    onRefreshHeader: () -> Unit,
    onOpenRepository: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            AnclaMark(size = 20.dp, tint = MaterialTheme.colorScheme.onSurface)
            Text(
                text = "Ancla",
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.testTag("home-title")
            )
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            HeaderPillButton(
                text = "Refresh",
                icon = Icons.Filled.Refresh,
                tag = "home-refresh-button",
                onClick = onRefreshHeader
            )
            HeaderCircleButton(
                icon = Icons.Outlined.Code,
                tag = "home-repository-button",
                onClick = onOpenRepository
            )
        }
    }
}

@Composable
private fun HeaderPillButton(
    text: String,
    icon: ImageVector,
    tag: String,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(999.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)),
        modifier = Modifier.testTag(tag)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 9.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(14.dp)
            )
            Text(
                text = text,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.labelMedium
            )
        }
    }
}

@Composable
private fun HeaderCircleButton(
    icon: ImageVector,
    tag: String,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)),
        modifier = Modifier
            .size(38.dp)
            .testTag(tag)
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

@Composable
private fun HomeBanner(
    title: String,
    detail: String,
    accent: Color,
    tag: String
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        border = BorderStroke(1.dp, accent.copy(alpha = 0.22f)),
        modifier = Modifier.fillMaxWidth().testTag(tag)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .background(accent.copy(alpha = 0.16f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text("•", color = accent)
            }
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(title, color = accent, style = MaterialTheme.typography.labelLarge)
                Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun FeedbackToast(
    message: String,
    modifier: Modifier = Modifier
) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.96f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.22f)),
        modifier = modifier
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 11.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .background(MaterialTheme.colorScheme.secondary.copy(alpha = 0.16f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.secondary,
                    modifier = Modifier.size(12.dp)
                )
            }
            Text(
                text = message,
                color = MaterialTheme.colorScheme.secondary,
                style = MaterialTheme.typography.labelLarge,
                maxLines = 2
            )
        }
    }
}

@Composable
private fun HomeInfoRow(
    title: String,
    detail: String,
    trailingText: String? = null,
    trailingIcon: ImageVector? = null,
    accent: Color,
    tag: String? = null
) {
    Column(
        modifier =
            (if (tag == null) Modifier else Modifier.testTag(tag))
                .fillMaxWidth()
                .padding(vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top
        ) {
            Text(title, color = accent, style = MaterialTheme.typography.titleMedium)
            trailingText?.let {
                Text(
                    it,
                    color = accent,
                    style = MaterialTheme.typography.labelMedium
                )
            }
            trailingIcon?.let {
                Icon(
                    imageVector = it,
                    contentDescription = null,
                    tint = accent,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    HorizontalDivider()
}

@Composable
private fun FailsafeCountRow(
    remaining: Int,
    detail: String,
    accent: Color,
    onDecrease: () -> Unit,
    onIncrease: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text("Failsafes", color = accent, style = MaterialTheme.typography.titleMedium)
            Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            FailsafeCountButton(
                icon = Icons.Filled.Remove,
                enabled = remaining > 0,
                onClick = onDecrease
            )
            Text(
                text = remaining.toString(),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurface
            )
            FailsafeCountButton(
                icon = Icons.Filled.Add,
                enabled = remaining < 99,
                onClick = onIncrease
            )
        }
    }
    HorizontalDivider()
}

@Composable
private fun FailsafeCountButton(
    icon: ImageVector,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        enabled = enabled,
        shape = RoundedCornerShape(10.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.82f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.45f)),
        modifier = Modifier.size(width = 30.dp, height = 30.dp)
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint =
                    if (enabled) MaterialTheme.colorScheme.onSurface
                    else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                modifier = Modifier.size(14.dp)
            )
        }
    }
}

@Composable
private fun ParagraphChallengeToggleRow(
    isEnabled: Boolean,
    detail: String,
    accent: Color,
    onToggle: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text("Typing challenge", color = accent, style = MaterialTheme.typography.titleMedium)
            Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Switch(
            checked = isEnabled,
            onCheckedChange = onToggle
        )
    }
    HorizontalDivider()
}

@Composable
private fun CompactSectionTitle(text: String) {
    Text(
        text = text.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(top = 18.dp, bottom = 2.dp)
    )
}

@Composable
private fun HomeSectionAction(
    icon: ImageVector,
    title: String,
    detail: String,
    tag: String,
    onClick: () -> Unit
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(vertical = 14.dp)
                .testTag(tag),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(38.dp)
                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.14f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(18.dp)
            )
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(14.dp)
        )
    }
    HorizontalDivider()
}

private fun temporaryUnlockRemainingSeconds(state: AppState): Long =
    state.temporaryUnlock?.expiresAt?.let { expiresAt ->
        java.time.Duration.between(Instant.now(), expiresAt).seconds.coerceAtLeast(0)
    } ?: 0

private data class HomeHeroContent(
    val badge: String? = null,
    val title: String,
    val detail: String? = null
)

private fun homeHeroContent(
    state: AppState,
    selectedModeName: String?,
    activeAnchorName: String?
): HomeHeroContent =
    when {
        temporaryUnlockIsActive(state) && state.temporaryUnlock != null ->
            HomeHeroContent(
                badge = "OPEN",
                title = "\"${state.temporaryUnlock.reason}\" is active",
                detail = "The phone is temporarily open for ${temporaryUnlockRemainingSeconds(state)} more seconds."
            )
        activeSessionIsBlocking(state) ->
            HomeHeroContent(
                badge = if (state.activeSession?.state == dev.micr.ancla.model.SessionState.WRONG_ANCHOR) "WRONG ANCHOR" else "LIVE",
                title = sessionSectionTitle(state),
                detail = sessionSectionDetail(state, selectedModeName, activeAnchorName)
            )
        !state.nfcAvailable ->
            HomeHeroContent(
                badge = "NFC",
                title = "Turn on NFC",
                detail = "Start and release scans require NFC on this Android phone."
            )
        state.anchors.isEmpty() ->
            HomeHeroContent(
                badge = "PAIR",
                title = "Pair an anchor",
                detail = "Pair one anchor to move the release path off the screen and into the room."
            )
        state.modes.isEmpty() ->
            HomeHeroContent(
                badge = "MODE",
                title = "Create a mode",
                detail = "Create the first mode you want ready before starting a block."
            )
        else ->
            HomeHeroContent(
                title = selectedModeName ?: "Mode ready"
            )
    }

@Composable
private fun HomeHero(
    content: HomeHeroContent,
    compact: Boolean
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = if (compact) 2.dp else 6.dp, bottom = 4.dp),
        verticalArrangement = Arrangement.spacedBy(if (content.badge == null) 8.dp else 12.dp)
    ) {
        content.badge?.let { badge ->
            Surface(
                shape = RoundedCornerShape(999.dp),
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.4f))
            ) {
                Text(
                    text = badge,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
                )
            }
        }
        Text(
            text = content.title,
            style =
                MaterialTheme.typography.headlineMedium.copy(
                    fontSize = if (compact) 32.sp else 36.sp,
                    lineHeight = if (compact) 34.sp else 38.sp
                )
        )
        content.detail?.let { detail ->
            Text(
                text = detail,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private fun sessionSectionTitle(state: AppState): String =
    when (state.activeSession?.state) {
        dev.micr.ancla.model.SessionState.ARMED -> "Block is live"
        dev.micr.ancla.model.SessionState.WRONG_ANCHOR -> "Wrong anchor"
        null -> "No live block"
    }

private fun sessionSectionBadge(state: AppState): String =
    when {
        temporaryUnlockIsActive(state) -> "Open"
        activeSessionIsBlocking(state) -> "Live"
        else -> "Idle"
    }

private fun sessionSectionDetail(
    state: AppState,
    activeModeName: String?,
    activeAnchorName: String?
): String =
    when (state.activeSession?.state) {
        dev.micr.ancla.model.SessionState.ARMED ->
            if (temporaryUnlockIsActive(state)) {
                "\"${state.temporaryUnlock?.reason ?: "Preset"}\" is open for ${temporaryUnlockRemainingSeconds(state)} more seconds. The block returns automatically when that timer ends."
            } else {
                "The current session remains active until ${activeAnchorName ?: "the release anchor"} is scanned. ${emergencyCountSentence(state)}"
            }
        dev.micr.ancla.model.SessionState.WRONG_ANCHOR ->
            "A different anchor was scanned. The session remains active for ${activeModeName ?: "the current mode"}. ${emergencyCountSentence(state)}"
        null -> "No active session is running right now."
    }

private fun emergencyCountSentence(state: AppState): String =
    if (state.emergencyUnbricksRemaining == 1) {
        "1 failsafe remains."
    } else {
        "${state.emergencyUnbricksRemaining} failsafes remain."
    }

private fun emergencyUnbrickBadge(state: AppState): String =
    if (state.emergencyUnbricksRemaining == 0) {
        "Empty"
    } else {
        "${state.emergencyUnbricksRemaining} left"
    }

private fun emergencyUnbrickDetail(state: AppState): String =
    when {
        state.emergencyUnbricksRemaining == 0 && canUseParagraphChallenge(state) ->
            "Normal failsafes are empty. The typing challenge is the only non-anchor release path."
        state.emergencyUnbricksRemaining == 0 ->
            "Normal failsafes are empty. The paired anchor is now required."
        canUseEmergencyUnbrick(state) ->
            "Use one to end the current session without the paired anchor."
        else ->
            "Keep these for moments when you cannot reach the paired anchor."
    }

@Composable
private fun HomeDock(
    selectedSection: HomeSection,
    onSelectSection: (HomeSection) -> Unit,
    primaryButtonLabel: String,
    primaryButtonIcon: ImageVector,
    primaryButtonEnabled: Boolean,
    isPrimaryActionLoading: Boolean,
    primaryAction: () -> Unit
) {
    androidx.compose.foundation.layout.BoxWithConstraints(
        modifier = Modifier
            .fillMaxWidth()
            .height(116.dp)
            .navigationBarsPadding()
    ) {
        val compactWidth = maxWidth < 390.dp
        val centerGap = if (compactWidth) 82.dp else 92.dp
        Surface(
            shape = RoundedCornerShape(34.dp),
            color = MaterialTheme.colorScheme.surface.copy(alpha = 0.98f),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)),
            modifier = Modifier
                .fillMaxWidth()
                .height(94.dp)
                .align(Alignment.BottomCenter)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = if (compactWidth) 14.dp else 18.dp, vertical = 18.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.Bottom
            ) {
                HomeDockTab(
                    section = HomeSection.MODES,
                    isSelected = selectedSection == HomeSection.MODES,
                    onClick = { onSelectSection(HomeSection.MODES) },
                    modifier = Modifier.weight(1f)
                )
                HomeDockTab(
                    section = HomeSection.SCHEDULES,
                    isSelected = selectedSection == HomeSection.SCHEDULES,
                    onClick = { onSelectSection(HomeSection.SCHEDULES) },
                    modifier = Modifier.weight(1f)
                )
                Spacer(modifier = Modifier.width(centerGap))
                HomeDockTab(
                    section = HomeSection.ANCHORS,
                    isSelected = selectedSection == HomeSection.ANCHORS,
                    onClick = { onSelectSection(HomeSection.ANCHORS) },
                    modifier = Modifier.weight(1f)
                )
                HomeDockTab(
                    section = HomeSection.UNLOCKS,
                    isSelected = selectedSection == HomeSection.UNLOCKS,
                    onClick = { onSelectSection(HomeSection.UNLOCKS) },
                    modifier = Modifier.weight(1f)
                )
            }
        }
        Button(
            onClick = primaryAction,
            enabled = primaryButtonEnabled && !isPrimaryActionLoading,
            modifier = Modifier
                .shadow(
                    elevation = 24.dp,
                    shape = CircleShape,
                    ambientColor = Color.Black.copy(alpha = 0.32f),
                    spotColor = Color.Black.copy(alpha = 0.38f)
                )
                .size(84.dp)
                .align(Alignment.TopCenter)
                .offset(y = (-2).dp)
                .testTag(if (primaryButtonLabel == "End block") "release-button" else "start-button"),
            shape = CircleShape,
            colors =
                ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = Color.White,
                    disabledContainerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.55f),
                    disabledContentColor = Color.White.copy(alpha = 0.72f)
                )
        ) {
            if (isPrimaryActionLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    strokeWidth = 2.dp,
                    color = Color.White
                )
            } else {
                Icon(
                    imageVector = primaryButtonIcon,
                    contentDescription = primaryButtonLabel,
                    modifier = Modifier.size(28.dp)
                )
            }
        }
    }
}

@Composable
private fun HomeDockTab(
    section: HomeSection,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        onClick = onClick,
        modifier =
            modifier
                .testTag("dock-tab-${section.name.lowercase()}")
                .semantics(mergeDescendants = true) {
                    contentDescription = "${section.title} tab"
                },
        shape = RoundedCornerShape(18.dp),
        color = Color.Transparent
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            Icon(
                imageVector = homeSectionIcon(section),
                contentDescription = null,
                tint =
                    if (isSelected) MaterialTheme.colorScheme.onSurface
                    else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.55f),
                modifier = Modifier.size(16.dp)
            )
            Text(
                text = section.title,
                color = if (isSelected) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.labelSmall
            )
        }
    }
}

@Composable
private fun ScheduleCard(
    plan: ScheduledSessionPlan,
    state: AppState,
    isActive: Boolean,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    var menuExpanded by remember { mutableStateOf(false) }
    val modeName = state.modes.firstOrNull { it.id == plan.modeId }?.name ?: "Missing mode"
    val anchorName = state.anchors.firstOrNull { it.id == plan.anchorId }?.displayName ?: "Missing anchor"
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 14.dp)
            .testTag("schedule-card-${plan.id}"),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("$modeName • ${weekdaySummary(plan.weekdayNumbers)}", style = MaterialTheme.typography.titleMedium)
            Text(
                scheduleCardDetail(plan, anchorName, isActive),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top
        ) {
            Text(
                scheduleCardBadge(plan, isActive),
                color = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.labelMedium
            )
            Box {
                RowMenuButton(onClick = { menuExpanded = true })
                DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                    DropdownMenuItem(
                        text = { Text("Edit schedule") },
                        onClick = {
                            menuExpanded = false
                            onEdit()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Delete schedule") },
                        onClick = {
                            menuExpanded = false
                            onDelete()
                        }
                    )
                }
            }
        }
    }
    HorizontalDivider()
}

@Composable
private fun UnlockPresetCard(
    preset: UnlockPreset,
    state: AppState,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    var menuExpanded by remember { mutableStateOf(false) }
    val isActive = state.temporaryUnlock?.presetId == preset.id
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 14.dp)
            .testTag("unlock-preset-card-${preset.id}"),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(preset.title, style = MaterialTheme.typography.titleMedium)
            Text(preset.detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (isActive) {
                val secondsRemaining =
                    state.temporaryUnlock?.expiresAt?.let { expiresAt ->
                        java.time.Duration.between(Instant.now(), expiresAt).seconds.coerceAtLeast(0)
                    } ?: 0
                Text(
                    "Temporary unlock active for ${secondsRemaining}s more. The same session will re-block when this ends.",
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.testTag("temporary-unlock-countdown")
                )
            }
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top
        ) {
            Text(
                "${preset.durationSeconds}s",
                color = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.labelMedium
            )
            Box {
                RowMenuButton(onClick = { menuExpanded = true })
                DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                    DropdownMenuItem(
                        text = { Text("Edit preset") },
                        onClick = {
                            menuExpanded = false
                            onEdit()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Delete preset") },
                        onClick = {
                            menuExpanded = false
                            onDelete()
                        }
                    )
                }
            }
        }
    }
    HorizontalDivider()
}

private fun scheduleCardDetail(
    plan: ScheduledSessionPlan,
    anchorName: String,
    isActive: Boolean
): String {
    val detail = mutableListOf("${minuteLabel(plan.startMinuteOfDay)} - ${minuteLabel(plan.endMinuteOfDay)}")
    if (isActive) {
        detail += "Running now"
    } else if (plan.isEnabled) {
        detail += "On"
    } else {
        detail += "Off"
    }
    detail += "Release early with $anchorName"
    return detail.joinToString(" • ")
}

private fun scheduleCardBadge(plan: ScheduledSessionPlan, isActive: Boolean): String =
    when {
        isActive -> "Active"
        !plan.isEnabled -> "Off"
        else -> "On"
    }

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ScheduleEditorDialog(
    existingSchedule: ScheduledSessionPlan?,
    repository: AppRepository,
    onDismiss: () -> Unit
) {
    val state by repository.state.collectAsState()
    var selectedModeId by remember(existingSchedule, state.selectedModeId, state.modes) {
        mutableStateOf(existingSchedule?.modeId ?: state.selectedModeId ?: state.modes.firstOrNull()?.id)
    }
    var selectedAnchorId by remember(existingSchedule, state.anchors) {
        mutableStateOf(existingSchedule?.anchorId ?: state.anchors.firstOrNull()?.id)
    }
    var weekdayNumbers by remember(existingSchedule) { mutableStateOf(existingSchedule?.weekdayNumbers?.toSet() ?: setOf(2)) }
    var startMinute by remember(existingSchedule) { mutableStateOf(existingSchedule?.startMinuteOfDay ?: 9 * 60) }
    var endMinute by remember(existingSchedule) { mutableStateOf(existingSchedule?.endMinuteOfDay ?: 17 * 60) }
    var isEnabled by remember(existingSchedule) { mutableStateOf(existingSchedule?.isEnabled ?: true) }
    var validationMessage by remember { mutableStateOf<String?>(null) }

    AnclaSheetDialog(
        title = if (existingSchedule == null) "New Schedule" else "Edit Schedule",
        confirmLabel = "Save",
        confirmTag = "save-schedule-dialog",
        onDismissRequest = onDismiss,
        onConfirm = {
            when (
                val result =
                    repository.saveSchedule(
                        ScheduleDraft(
                            id = existingSchedule?.id,
                            modeId = selectedModeId,
                            anchorId = selectedAnchorId,
                            weekdayNumbers = weekdayNumbers,
                            startMinuteOfDay = startMinute,
                            endMinuteOfDay = endMinute,
                            isEnabled = isEnabled
                        )
                    )
            ) {
                is ScheduleDraftResult.Saved -> onDismiss()
                is ScheduleDraftResult.ValidationError -> validationMessage = result.message
            }
        }
    ) {
        SheetSectionLabel("MODE")
        Text(
            "Pick the mode this schedule should start.",
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        state.modes.forEach { mode ->
            SheetSelectionCard(
                title = mode.name,
                detail = modeSummary(mode),
                selected = selectedModeId == mode.id,
                onClick = { selectedModeId = mode.id }
            )
        }

        SheetDivider()
        SheetSectionLabel("ANCHOR")
        Text(
            "Pick the paired anchor that can release it early.",
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        state.anchors.forEach { anchor ->
            SheetSelectionCard(
                title = anchor.displayName,
                detail = "Scheduled sessions still bind to this anchor for manual release.",
                selected = selectedAnchorId == anchor.id,
                onClick = { selectedAnchorId = anchor.id }
            )
        }

        SheetDivider()
        SheetSectionLabel("DAYS")
        Text(
            "Choose the weekdays.",
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            weekdayOptions().forEach { option ->
                WeekdayChip(
                    label = option.shortLabel,
                    selected = option.number in weekdayNumbers,
                    onClick = {
                        weekdayNumbers =
                            if (option.number in weekdayNumbers) {
                                weekdayNumbers - option.number
                            } else {
                                weekdayNumbers + option.number
                            }
                    }
                )
            }
        }

        SheetDivider()
        SheetSectionLabel("TIME")
        Text(
            "Set when the schedule should start and end.",
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        HomeSectionAction(
            icon = Icons.Outlined.CalendarMonth,
            title = "Use current time window",
            detail = "Set today and start it around right now.",
            tag = "use-current-time-window",
            onClick = {
                val now = ZonedDateTime.now()
                val minutes = now.hour * 60 + now.minute
                weekdayNumbers = setOf((now.dayOfWeek.value % 7) + 1)
                startMinute = (minutes - 15).coerceAtLeast(0)
                endMinute = (minutes + 60).coerceAtMost(23 * 60 + 59)
                isEnabled = true
            }
        )
        TimeAdjusterRow(
            title = "Start",
            value = minuteLabel(startMinute),
            onEarlier = { startMinute = (startMinute - 15).coerceAtLeast(0).coerceAtMost(endMinute - 15) },
            onLater = { startMinute = (startMinute + 15).coerceAtMost(endMinute - 15) }
        )
        TimeAdjusterRow(
            title = "End",
            value = minuteLabel(endMinute),
            onEarlier = { endMinute = (endMinute - 15).coerceAtLeast(startMinute + 15) },
            onLater = { endMinute = (endMinute + 15).coerceAtMost(23 * 60 + 59) }
        )

        SheetDivider()
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Enabled")
                Text(
                    "Disabled schedules stay saved but do not auto-start.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Switch(checked = isEnabled, onCheckedChange = { isEnabled = it })
        }

        validationMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("schedule-validation-message"))
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun UnlockPresetEditorDialog(
    existingPreset: UnlockPreset?,
    repository: AppRepository,
    onDismiss: () -> Unit
) {
    var title by remember(existingPreset) { mutableStateOf(existingPreset?.title ?: "Check 2FA") }
    var detail by remember(existingPreset) { mutableStateOf(existingPreset?.detail ?: "Open Messages long enough to read a code.") }
    var durationSeconds by remember(existingPreset) { mutableStateOf(existingPreset?.durationSeconds ?: 10) }
    var validationMessage by remember { mutableStateOf<String?>(null) }

    AnclaSheetDialog(
        title = if (existingPreset == null) "New Preset" else "Edit Preset",
        confirmLabel = "Save",
        confirmTag = "save-unlock-preset-dialog",
        onDismissRequest = onDismiss,
        onConfirm = {
            when (
                val result =
                    repository.saveUnlockPreset(
                        UnlockPresetDraft(
                            id = existingPreset?.id,
                            title = title,
                            detail = detail,
                            durationSeconds = durationSeconds
                        )
                    )
            ) {
                is UnlockPresetDraftResult.Saved -> onDismiss()
                is UnlockPresetDraftResult.ValidationError -> validationMessage = result.message
            }
        }
    ) {
        SheetTextField(
            title = "PRESET NAME",
            value = title,
            onValueChange = { title = it },
            placeholder = "Check 2FA",
            textStyle = MaterialTheme.typography.headlineMedium
        )
        SheetTextField(
            title = "WHAT THIS IS FOR",
            value = detail,
            onValueChange = { detail = it },
            placeholder = "Open Messages long enough to read a code.",
            minLines = 3
        )
        SheetSectionLabel("DURATION")
        DurationStepperRow(
            durationSeconds = durationSeconds,
            onDecrease = { durationSeconds = (durationSeconds - 5).coerceAtLeast(5) },
            onIncrease = { durationSeconds = (durationSeconds + 5).coerceAtMost(300) }
        )
        SheetSectionLabel("PREVIEW")
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = title.ifBlank { "Check 2FA" },
                        style = MaterialTheme.typography.titleMedium
                    )
                    Text(
                        text = detail.ifBlank { "Temporary access." },
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Text(text = "${durationSeconds}s", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            SheetDivider()
        }
        validationMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("unlock-preset-validation-message"))
        }
    }
}

@Composable
private fun TimeAdjusterRow(
    title: String,
    value: String,
    onEarlier: () -> Unit,
    onLater: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(title, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                onClick = onEarlier,
                shape = RoundedCornerShape(14.dp),
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)),
                modifier = Modifier.width(92.dp)
            ) {
                Box(
                    modifier = Modifier.height(42.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text("Earlier", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Surface(
                shape = RoundedCornerShape(14.dp),
                color = MaterialTheme.colorScheme.surface,
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)),
                modifier = Modifier.weight(1f)
            ) {
                Box(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(value, style = MaterialTheme.typography.titleMedium)
                }
            }
            Surface(
                onClick = onLater,
                shape = RoundedCornerShape(14.dp),
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)),
                modifier = Modifier.width(92.dp)
            ) {
                Box(
                    modifier = Modifier.height(42.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text("Later", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
private fun DurationStepperRow(
    durationSeconds: Int,
    onDecrease: () -> Unit,
    onIncrease: () -> Unit
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        DurationButton(icon = Icons.Filled.Remove, onClick = onDecrease)
        Text(
            text = "${durationSeconds}s",
            style = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.width(88.dp)
        )
        DurationButton(icon = Icons.Filled.Add, onClick = onIncrease)
    }
}

@Composable
private fun DurationButton(
    icon: ImageVector,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)),
        modifier = Modifier.size(42.dp)
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

@Composable
private fun WeekdayChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(14.dp),
        color =
            if (selected) MaterialTheme.colorScheme.surface
            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
        border =
            BorderStroke(
                1.dp,
                if (selected) MaterialTheme.colorScheme.primary.copy(alpha = 0.55f)
                else MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)
            )
    ) {
        Box(
            modifier = Modifier
                .width(42.dp)
                .height(42.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = label,
                color =
                    if (selected) MaterialTheme.colorScheme.onSurface
                    else MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.titleSmall
            )
        }
    }
}

private data class WeekdayOption(val number: Int, val shortLabel: String)

private fun weekdayOptions(): List<WeekdayOption> =
    listOf(
        WeekdayOption(1, "S"),
        WeekdayOption(2, "M"),
        WeekdayOption(3, "T"),
        WeekdayOption(4, "W"),
        WeekdayOption(5, "T"),
        WeekdayOption(6, "F"),
        WeekdayOption(7, "S")
    )

private fun weekdaySummary(weekdayNumbers: List<Int>): String =
    weekdayOptions().filter { it.number in weekdayNumbers }.joinToString(" ") { it.shortLabel }

private fun minuteLabel(totalMinutes: Int): String {
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    val isPm = hours >= 12
    val displayHour = ((hours + 11) % 12) + 1
    return "%d:%02d %s".format(displayHour, minutes, if (isPm) "PM" else "AM")
}

@Composable
private fun LockSurfaceScreen(
    state: AppState,
    launchedLockSurface: LockSurfaceLaunch?,
    unlockMenuPresented: Boolean,
    feedbackMessage: String?,
    onLockedSurfaceTap: () -> Unit,
    onToggleUnlockMenu: () -> Unit,
    onEmergencyUnbrick: () -> Unit,
    onOpenParagraphChallenge: () -> Unit,
    onActivateUnlockPreset: (UnlockPreset) -> Unit,
    modifier: Modifier = Modifier
) {
    val modeName = activeMode(state)?.name ?: "Current mode"
    val anchorName = activeAnchor(state)?.displayName ?: "paired anchor"
    val isWrongAnchor = state.activeSession?.state == dev.micr.ancla.model.SessionState.WRONG_ANCHOR
    val emergencyAvailable = canUseEmergencyUnbrick(state)
    val paragraphChallengeAvailable = canUseParagraphChallenge(state)
    val interactionSource = remember { MutableInteractionSource() }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .statusBarsPadding()
            .navigationBarsPadding()
            .testTag("lock-surface")
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clickable(
                    interactionSource = interactionSource,
                    indication = null,
                    onClick = onLockedSurfaceTap
                )
        )
        Column(
            modifier = Modifier
                .align(Alignment.Center)
                .padding(horizontal = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            AnclaMark(size = 128.dp, tint = Color.White.copy(alpha = 0.94f))
            Text("You're anchored", style = MaterialTheme.typography.headlineMedium)
            Text(
                "Tap anywhere, then hold your phone near your anchor to unlock.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .testTag("lock-surface-release-path")
            )
        }

        Text(
            text = "Unlock options stay on the top left.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 36.dp)
                .testTag("lock-surface-relaunch-copy")
        )

        Column(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            HeaderCircleButton(
                icon = Icons.Outlined.LockOpen,
                tag = "lock-surface-unlock-options",
                onClick = onToggleUnlockMenu
            )
            if (unlockMenuPresented) {
                Surface(
                    shape = RoundedCornerShape(24.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.94f),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.38f)),
                    modifier = Modifier
                        .width(280.dp)
                        .testTag("lock-surface-actions")
                ) {
                    Column(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                        verticalArrangement = Arrangement.spacedBy(0.dp)
                    ) {
                        LockMenuRow(
                            title =
                                when {
                                    emergencyAvailable -> "Failsafe"
                                    paragraphChallengeAvailable -> "Failsafe challenge"
                                    else -> "Failsafe unavailable"
                                },
                            detail =
                                when {
                                    emergencyAvailable -> {
                                        val count = state.emergencyUnbricksRemaining
                                        if (count == 1) "1 failsafe left" else "$count failsafes left"
                                    }
                                    paragraphChallengeAvailable -> "Type the passage exactly"
                                    else -> "No release path ready"
                                },
                            enabled = emergencyAvailable || paragraphChallengeAvailable,
                            tag = "lock-surface-failsafe-button",
                            onClick = {
                                if (emergencyAvailable) {
                                    onEmergencyUnbrick()
                                } else if (paragraphChallengeAvailable) {
                                    onOpenParagraphChallenge()
                                }
                            }
                        )
                        state.unlockPresets.forEach { preset ->
                            LockMenuRow(
                                title = preset.title,
                                detail = "${preset.durationSeconds}s",
                                enabled = activeSessionIsBlocking(state),
                                onClick = { onActivateUnlockPreset(preset) }
                            )
                        }
                    }
                }
            }
        }

        Column(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(18.dp)
                .width(260.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            launchedLockSurface?.let { launch ->
                Surface(
                    shape = RoundedCornerShape(20.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.38f))
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            "Blocked target: ${launch.targetLabel ?: launch.packageName}",
                            modifier = Modifier.testTag("lock-surface-target")
                        )
                        Text(
                            "Mode: ${launch.modeName ?: modeName} · Anchor: ${launch.anchorName ?: anchorName}",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.testTag("lock-surface-launch-session")
                        )
                        Text(
                            "Intercepted for session ${launch.sessionId ?: "active"} since ${launch.sessionStartedAt ?: "this block started"}.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.testTag("lock-surface-target-details")
                        )
                    }
                }
            }
            if (isWrongAnchor) {
                Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.errorContainer) {
                    Text(
                        "Wrong anchor scanned. The same session is still blocking and can be retried with $anchorName.",
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                            .testTag("wrong-anchor-feedback"),
                        color = MaterialTheme.colorScheme.onErrorContainer
                    )
                }
            }
            feedbackMessage?.let { message ->
                Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.secondaryContainer) {
                    Text(
                        text = message,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                            .testTag("lock-surface-feedback"),
                        color = MaterialTheme.colorScheme.onSecondaryContainer
                    )
                }
            }
        }
    }
}

@Composable
private fun LockMenuRow(
    title: String,
    detail: String,
    enabled: Boolean,
    tag: String? = null,
    onClick: () -> Unit
) {
    Column(
        modifier =
            (if (tag == null) Modifier else Modifier.testTag(tag))
                .fillMaxWidth()
                .clickable(enabled = enabled, onClick = onClick)
                .padding(vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = title,
            color =
                if (enabled) MaterialTheme.colorScheme.onSurface
                else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            style = MaterialTheme.typography.titleMedium
        )
        Text(
            text = detail,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            style = MaterialTheme.typography.bodySmall
        )
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.32f))
}

@Composable
private fun AnclaSheetDialog(
    title: String,
    onDismissRequest: () -> Unit,
    confirmLabel: String? = null,
    confirmEnabled: Boolean = true,
    confirmTag: String? = null,
    onConfirm: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Dialog(
        onDismissRequest = onDismissRequest,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier =
                Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background.copy(alpha = 0.98f))
                    .padding(horizontal = 12.dp, vertical = 12.dp)
        ) {
            Surface(
                shape = RoundedCornerShape(30.dp),
                color = MaterialTheme.colorScheme.background,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .fillMaxHeight(0.94f)
                        .align(Alignment.BottomCenter)
            ) {
                Column(modifier = Modifier.fillMaxSize()) {
                    Box(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .padding(top = 16.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Surface(
                            shape = RoundedCornerShape(999.dp),
                            color = MaterialTheme.colorScheme.outline.copy(alpha = 0.6f),
                            modifier = Modifier.size(width = 40.dp, height = 4.dp)
                        ) {}
                    }
                    Box(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 32.dp, vertical = 24.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            SheetHeaderButton(
                                text = "Cancel",
                                onClick = onDismissRequest
                            )
                            if (confirmLabel != null && onConfirm != null) {
                                SheetHeaderButton(
                                    text = confirmLabel,
                                    onClick = onConfirm,
                                    enabled = confirmEnabled,
                                    primary = true,
                                    tag = confirmTag
                                )
                            } else {
                                Spacer(modifier = Modifier.size(width = 74.dp, height = 38.dp))
                            }
                        }
                        Text(
                            text = title,
                            style = MaterialTheme.typography.titleLarge,
                            modifier = Modifier.align(Alignment.Center)
                        )
                    }
                    Column(
                        modifier =
                            Modifier
                                .weight(1f)
                                .verticalScroll(rememberScrollState())
                                .padding(horizontal = 32.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(20.dp),
                        content = content
                    )
                }
            }
        }
    }
}

@Composable
private fun SheetHeaderButton(
    text: String,
    onClick: () -> Unit,
    enabled: Boolean = true,
    primary: Boolean = false,
    tag: String? = null
) {
    val modifier =
        (if (tag == null) Modifier else Modifier.testTag(tag))
            .height(38.dp)

    if (primary) {
        Button(
            onClick = onClick,
            enabled = enabled,
            modifier = modifier,
            contentPadding = PaddingValues(horizontal = 14.dp, vertical = 0.dp),
            shape = RoundedCornerShape(14.dp),
            colors =
                ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary
                )
        ) {
            Text(text)
        }
    } else {
        Surface(
            onClick = onClick,
            enabled = enabled,
            modifier = modifier,
            shape = RoundedCornerShape(14.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.75f))
        ) {
            Box(
                modifier = Modifier.padding(horizontal = 14.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun SheetSectionLabel(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Composable
private fun SheetTextField(
    title: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    textStyle: androidx.compose.ui.text.TextStyle = MaterialTheme.typography.bodyLarge,
    minLines: Int = 1,
    modifier: Modifier = Modifier
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SheetSectionLabel(title)
        TextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = {
                Text(
                    text = placeholder,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                    style = textStyle
                )
            },
            modifier = modifier.fillMaxWidth(),
            minLines = minLines,
            textStyle = textStyle.copy(color = MaterialTheme.colorScheme.onSurface),
            colors =
                TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    disabledContainerColor = Color.Transparent,
                    errorContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    disabledIndicatorColor = Color.Transparent,
                    errorIndicatorColor = Color.Transparent,
                    cursorColor = MaterialTheme.colorScheme.onSurface
                )
        )
        SheetDivider()
    }
}

@Composable
private fun SheetDivider() {
    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
}

@Composable
private fun SheetSelectionCard(
    title: String,
    detail: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(18.dp),
        color =
            if (selected) MaterialTheme.colorScheme.surface
            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
        border =
            BorderStroke(
                width = 1.dp,
                color =
                    if (selected) MaterialTheme.colorScheme.primary.copy(alpha = 0.55f)
                    else MaterialTheme.colorScheme.outline.copy(alpha = 0.75f)
            ),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Icon(
                imageVector = if (selected) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
                contentDescription = null,
                tint =
                    if (selected) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

private fun paragraphChallengeAccuracyPercent(expected: String, actual: String): Int {
    if (expected.isEmpty()) {
        return 0
    }
    val comparedCount = minOf(expected.length, actual.length)
    val matching =
        expected.take(comparedCount)
            .zip(actual.take(comparedCount))
            .count { (lhs, rhs) -> lhs == rhs }
    val penalty = kotlin.math.abs(expected.length - actual.length)
    val score = (matching - penalty).coerceAtLeast(0)
    return ((score.toDouble() / expected.length.toDouble()) * 100.0).toInt()
}

@Composable
private fun ParagraphChallengeDialog(
    challenge: ParagraphChallenge?,
    validationMessage: String?,
    onDismiss: () -> Unit,
    onSubmit: (String) -> Unit
) {
    var typedPassage by rememberSaveable { mutableStateOf("") }
    val accuracy = paragraphChallengeAccuracyPercent(challenge?.passage.orEmpty(), typedPassage)

    AnclaSheetDialog(
        title = "Failsafe Challenge",
        confirmLabel = "Unlock",
        confirmEnabled = challenge != null && typedPassage.isNotBlank(),
        confirmTag = "submit-paragraph-challenge",
        onDismissRequest = onDismiss,
        onConfirm = { onSubmit(typedPassage) }
    ) {
        challenge?.let {
            Text(
                text = it.title,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.labelMedium
            )
        }
        Text(
            text = challenge?.passage ?: "No paragraph challenge is available for this session.",
            modifier = Modifier.testTag("paragraph-challenge-passage")
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Exact punctuation required",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = "$accuracy%",
                color =
                    if (accuracy == 100 && typedPassage.isNotBlank()) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    }
            )
        }
        Surface(
            shape = RoundedCornerShape(20.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.55f)),
            modifier =
                Modifier
                    .fillMaxWidth()
                    .testTag("paragraph-challenge-input-surface")
        ) {
            TextField(
                value = typedPassage,
                onValueChange = { typedPassage = it },
                placeholder = {
                    Text(
                        text = "Type the passage exactly",
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                    )
                },
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .testTag("paragraph-challenge-input"),
                minLines = 8,
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
                colors =
                    TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        disabledContainerColor = Color.Transparent,
                        errorContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        disabledIndicatorColor = Color.Transparent,
                        errorIndicatorColor = Color.Transparent,
                        cursorColor = MaterialTheme.colorScheme.onSurface
                    )
            )
        }
        validationMessage?.let {
            Text(
                text = it,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.testTag("paragraph-challenge-validation-message")
            )
        }
    }
}

@Composable
private fun HistoryEntryCard(entry: SessionHistoryEntry) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(entry.modeName, style = MaterialTheme.typography.titleMedium)
            Text(
                historyDurationLabel(entry),
                color = MaterialTheme.colorScheme.primary,
                style = MaterialTheme.typography.labelMedium
            )
        }
        Text(
            historySubtitle(entry),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.testTag("history-release-method")
        )
        Text(
            "Session ${entry.sessionId}",
            modifier = Modifier.testTag("history-session-id"),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            style = MaterialTheme.typography.bodySmall
        )
    }
    HorizontalDivider()
}

private fun historyContextLabel(entry: SessionHistoryEntry): String =
    when (entry.releaseMethod) {
        ReleaseMethod.ANCHOR -> "Released via ${entry.anchorName}"
        ReleaseMethod.SCHEDULE -> "Ended on schedule for ${entry.anchorName}"
        ReleaseMethod.EMERGENCY_UNBRICK -> "Emergency unbrick for ${entry.anchorName}"
        ReleaseMethod.PARAGRAPH_CHALLENGE -> "Failsafe challenge for ${entry.anchorName}"
    }

private fun historyDurationLabel(entry: SessionHistoryEntry): String {
    val seconds = java.time.Duration.between(entry.armedAt, entry.releasedAt).seconds.coerceAtLeast(0)
    if (seconds < 60) {
        return "${seconds}s"
    }

    val minutes = seconds / 60
    if (minutes < 60) {
        return "${minutes}m"
    }

    val hours = minutes / 60
    val remainingMinutes = minutes % 60
    return if (remainingMinutes == 0L) {
        "${hours}h"
    } else {
        "${hours}h ${remainingMinutes}m"
    }
}

private fun historySubtitle(entry: SessionHistoryEntry): String =
    "${historyContextLabel(entry)} • ${historyTimestampLabel(entry.releasedAt)}"

private fun historyTimestampLabel(instant: Instant): String =
    DateTimeFormatter.ofPattern("MMM d, h:mm a")
        .withZone(ZoneId.systemDefault())
        .format(instant)

@Composable
private fun AnclaMark(
    size: androidx.compose.ui.unit.Dp,
    tint: Color
) {
    Icon(
        painter = painterResource(R.drawable.ancla_mark),
        contentDescription = null,
        tint = tint,
        modifier = Modifier.size(size)
    )
}

private fun Context.isAnclaAccessibilityEnabled(): Boolean {
    val accessibilityManager =
        getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager ?: return false
    val enabledServices =
        accessibilityManager.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_ALL_MASK
        )
    return enabledServices.any {
        it.resolveInfo?.serviceInfo?.packageName == packageName &&
            it.resolveInfo?.serviceInfo?.name == "${packageName}.platform.AnclaAccessibilityService"
    }
}

private fun Context.isBlockingAuthorizationGranted(): Boolean =
    MainActivity.accessibilityAuthorizationProviderOverride?.invoke(this)
        ?: isAnclaAccessibilityEnabled()

private fun Context.openNfcSettings() {
    val fallbackIntent = Intent(Settings.ACTION_WIRELESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    val nfcIntent = Intent(Settings.ACTION_NFC_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try {
        startActivity(nfcIntent)
    } catch (_: ActivityNotFoundException) {
        startActivity(fallbackIntent)
    }
}

data class LockSurfaceLaunch(
    val packageName: String?,
    val targetLabel: String?,
    val modeName: String?,
    val anchorName: String?,
    val sessionId: String?,
    val sessionState: String?,
    val sessionStartedAt: String?
) {
    val isComplete: Boolean
        get() =
            !packageName.isNullOrBlank() &&
                !targetLabel.isNullOrBlank() &&
                !modeName.isNullOrBlank() &&
                !anchorName.isNullOrBlank() &&
                !sessionId.isNullOrBlank() &&
                !sessionState.isNullOrBlank()
}

internal fun Intent.toLockSurfaceLaunch(): LockSurfaceLaunch? {
    val launch =
        LockSurfaceLaunch(
            packageName = getStringExtra(MainActivity.EXTRA_LOCK_SURFACE_PACKAGE),
            targetLabel = getStringExtra(MainActivity.EXTRA_LOCK_SURFACE_TARGET_LABEL),
            modeName = getStringExtra(MainActivity.EXTRA_LOCK_SURFACE_MODE_NAME),
            anchorName = getStringExtra(MainActivity.EXTRA_LOCK_SURFACE_ANCHOR_NAME),
            sessionId = getStringExtra(MainActivity.EXTRA_LOCK_SURFACE_SESSION_ID),
            sessionState = getStringExtra(MainActivity.EXTRA_LOCK_SURFACE_SESSION_STATE),
            sessionStartedAt = getStringExtra(MainActivity.EXTRA_LOCK_SURFACE_SESSION_STARTED_AT)
        )
    return launch.takeIf { it.isComplete }
}

@Composable
private fun AnchorRow(
    anchor: PairedAnchor,
    isActive: Boolean,
    onRename: () -> Unit,
    onRemove: () -> Unit
) {
    var menuExpanded by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 14.dp)
            .testTag("anchor-${anchor.id}")
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                text = anchor.displayName,
                style = MaterialTheme.typography.titleMedium,
                color = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = if (isActive) "This anchor releases the current block." else "Ready to start or release blocks on this Android phone.",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top
        ) {
            Text(
                text = if (isActive) "Active" else "Paired",
                color = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.labelMedium
            )
            Box {
                RowMenuButton(onClick = { menuExpanded = true })
                DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                    DropdownMenuItem(
                        text = { Text("Rename anchor") },
                        onClick = {
                            menuExpanded = false
                            onRename()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Remove anchor") },
                        onClick = {
                            menuExpanded = false
                            onRemove()
                        }
                    )
                }
            }
        }
    }
    HorizontalDivider()
}

@Composable
private fun ModeCard(
    mode: BlockMode,
    isSelected: Boolean,
    isActive: Boolean,
    onSelect: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    var menuExpanded by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 14.dp)
            .testTag("mode-card-${mode.name}"),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        Row(
            modifier =
                Modifier
                    .weight(1f)
                    .clickable(onClick = onSelect),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(mode.name, style = MaterialTheme.typography.titleMedium)
                Text(modeSummary(mode), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                if (isActive) {
                    Text("Active", color = MaterialTheme.colorScheme.tertiary, modifier = Modifier.testTag("active-mode-indicator"))
                }
                ModeSelectionIndicator(
                    isSelected = isSelected,
                    modifier = Modifier.testTag("selected-mode-indicator")
                )
            }
        }
        Box {
            RowMenuButton(onClick = { menuExpanded = true })
            DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                DropdownMenuItem(
                    text = { Text("Edit mode") },
                    onClick = {
                        menuExpanded = false
                        onEdit()
                    }
                )
                DropdownMenuItem(
                    text = { Text("Delete mode") },
                    onClick = {
                        menuExpanded = false
                        onDelete()
                    }
                )
            }
        }
    }
    HorizontalDivider()
}

@Composable
private fun ModeSelectionIndicator(
    isSelected: Boolean,
    modifier: Modifier = Modifier
) {
    Icon(
        imageVector = if (isSelected) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
        contentDescription = null,
        tint =
            if (isSelected) MaterialTheme.colorScheme.primary
            else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.62f),
        modifier = modifier.size(18.dp)
    )
}

@Composable
private fun RowMenuButton(onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = Color.Transparent,
        modifier = Modifier.size(28.dp)
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = Icons.Filled.MoreHoriz,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class)
@Composable
private fun ModeEditorDialog(
    existingMode: BlockMode?,
    repository: AppRepository,
    onDismiss: () -> Unit
) {
    val state by repository.state.collectAsState()
    var name by remember(existingMode) { mutableStateOf(existingMode?.name.orEmpty()) }
    var isDefault by remember(existingMode) { mutableStateOf(existingMode?.isDefault ?: state.modes.isEmpty()) }
    var blockScope by remember(existingMode) { mutableStateOf(existingMode?.scope ?: BlockScope.ONLY_SELECTED) }
    var selectedTargets by remember(existingMode) {
        mutableStateOf(existingMode?.targets?.map { it.id }?.toSet().orEmpty())
    }
    var searchQuery by remember(existingMode) { mutableStateOf("") }
    var validationMessage by remember { mutableStateOf<String?>(null) }
    val availableTargets = remember(repository) { repository.availableBlockingTargets() }
    val availableTargetsById = remember(availableTargets) { availableTargets.associateBy(BlockingTarget::id) }
    val filteredTargets =
        remember(availableTargets, searchQuery) {
            val needle = searchQuery.trim().lowercase()
            if (needle.isEmpty()) {
                availableTargets
            } else {
                availableTargets.filter {
                    it.label.lowercase().contains(needle) || it.packageName.lowercase().contains(needle)
                }
            }
        }
    val missingTargets =
        remember(existingMode, availableTargetsById) {
            existingMode?.targets?.filterNot { it.id in availableTargetsById }.orEmpty()
        }
    val scope = rememberCoroutineScope()

    AnclaSheetDialog(
        title = if (existingMode == null) "New Mode" else "Edit Mode",
        confirmLabel = "Save",
        confirmTag = "save-mode-dialog",
        onDismissRequest = onDismiss,
        onConfirm = {
            scope.launch {
                when (
                    val result =
                        repository.saveMode(
                            ModeDraft(
                                id = existingMode?.id,
                                name = name,
                                scope = blockScope,
                                selectedTargetIds = selectedTargets,
                                isDefault = isDefault
                            )
                        )
                ) {
                    is ModeDraftResult.Saved -> onDismiss()
                    is ModeDraftResult.ValidationError -> validationMessage = result.message
                }
            }
        }
    ) {
        SheetTextField(
            title = "MODE",
            value = name,
            onValueChange = { name = it },
            placeholder = "Mode name",
            textStyle = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.testTag("mode-name-field")
        )
        Text(
            text = "Name the block ready next.",
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        SheetDivider()
        SheetSectionLabel("SCOPE")
        Text(
            text = "Choose whether this mode blocks only selected apps, every app except selected ones, or all installed apps.",
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SheetSelectionCard(
                title = "Only selected apps",
                detail = "Block only the apps chosen below.",
                selected = blockScope == BlockScope.ONLY_SELECTED,
                onClick = { blockScope = BlockScope.ONLY_SELECTED }
            )
            SheetSelectionCard(
                title = "All except selected",
                detail = "Block every installed app except the apps chosen below.",
                selected = blockScope == BlockScope.ALL_EXCEPT_SELECTED,
                onClick = { blockScope = BlockScope.ALL_EXCEPT_SELECTED }
            )
            SheetSelectionCard(
                title = "All installed apps",
                detail = "Block every installed app except Ancla and Android-critical surfaces.",
                selected = blockScope == BlockScope.ALL_APPS,
                onClick = { blockScope = BlockScope.ALL_APPS }
            )
        }
        SheetDivider()
        if (blockScope == BlockScope.ALL_APPS) {
            Text(
                text = "All installed apps will be blocked except Ancla and Android-critical surfaces like the launcher, Settings, installer, and default communication apps.",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } else {
            SheetSectionLabel(if (blockScope == BlockScope.ONLY_SELECTED) "BLOCK THESE APPS" else "EXCLUDE THESE APPS")
            Text(
                text =
                    if (blockScope == BlockScope.ONLY_SELECTED) {
                        "Search installed apps and choose what this mode should block."
                    } else {
                        "Search installed apps and choose what should stay available while everything else is blocked."
                    },
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            SheetTextField(
                title = "SEARCH",
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = "Find an installed app",
                modifier = Modifier.testTag("mode-target-search")
            )
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                filteredTargets.forEach { target ->
                    FilterChip(
                        selected = target.id in selectedTargets,
                        onClick = {
                            selectedTargets =
                                if (target.id in selectedTargets) {
                                    selectedTargets - target.id
                                } else {
                                    selectedTargets + target.id
                                }
                        },
                        label = { Text(target.label) },
                        modifier = Modifier.testTag(blockingTargetTag(target))
                    )
                }
            }
            if (missingTargets.isNotEmpty()) {
                SheetDivider()
                SheetSectionLabel("NOT INSTALLED")
                Text(
                    text = "These apps were selected earlier but are not installed on this phone right now.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    missingTargets.forEach { target ->
                        FilterChip(
                            selected = true,
                            onClick = { selectedTargets = selectedTargets - target.id },
                            label = { Text("${target.label} (missing)") }
                        )
                    }
                }
            }
        }
        SheetDivider()
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Set as primary")
                Text(
                    "Prioritize this mode globally.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Switch(
                checked = isDefault,
                onCheckedChange = { isDefault = it },
                modifier = Modifier.testTag("mode-default-checkbox")
            )
        }
        validationMessage?.let {
            Text(
                text = it,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.testTag("mode-validation-message")
            )
        }
    }
}

private fun blockingTargetTag(target: BlockingTarget): String =
    "target-" + target.label.lowercase().replace(Regex("[^a-z0-9]+"), "-").trim('-')

private enum class AnchorScanMode {
    PAIR,
    ARM,
    RELEASE
}

private enum class AnchorScanStatus {
    STARTING,
    WAITING,
    UNAVAILABLE,
    FAILURE
}

private data class AnchorScanSheetState(
    val mode: AnchorScanMode,
    val status: AnchorScanStatus = AnchorScanStatus.STARTING,
    val message: String? = null,
    val diagnosticsSessionId: Long = System.currentTimeMillis()
)

private fun processAnchorScanResult(
    mode: AnchorScanMode,
    scannedUid: String,
    state: AppState,
    repository: AppRepository
): String =
    when (mode) {
        AnchorScanMode.PAIR -> {
            val sizeBefore = state.anchors.size
            repository.pairAnchor(uid = scannedUid)
            if (repository.state.value.anchors.size > sizeBefore) {
                "${repository.state.value.anchors.last().displayName} paired."
            } else {
                "That NFC anchor is already paired."
            }
        }

        AnchorScanMode.ARM -> {
            when (val result = repository.armSession(scannedUid)) {
                SessionActionResult.Started -> {
                    val currentModeName = activeMode(repository.state.value)?.name ?: "Current mode"
                    val anchorName = activeAnchor(repository.state.value)?.displayName ?: "paired anchor"
                    "Paired anchor confirmed. \"$currentModeName\" is active with $anchorName."
                }

                SessionActionResult.Released -> "Session released with the bound anchor."
                is SessionActionResult.ValidationError -> result.message
            }
        }

        AnchorScanMode.RELEASE -> {
            when (val result = repository.releaseSession(scannedUid)) {
                SessionActionResult.Started -> {
                    val currentModeName = activeMode(repository.state.value)?.name ?: "Current mode"
                    val anchorName = activeAnchor(repository.state.value)?.displayName ?: "paired anchor"
                    "Paired anchor confirmed. \"$currentModeName\" is active with $anchorName."
                }

                SessionActionResult.Released -> "Session released with the bound anchor."
                is SessionActionResult.ValidationError -> result.message
            }
        }
    }

@Composable
private fun RenameAnchorDialog(
    anchor: PairedAnchor?,
    onDismiss: () -> Unit,
    onConfirm: (PairedAnchor, String) -> Unit
) {
    if (anchor == null) {
        onDismiss()
        return
    }
    var name by remember(anchor) { mutableStateOf(anchor.displayName) }
    AnclaSheetDialog(
        title = "Rename Anchor",
        confirmLabel = "Save",
        confirmTag = "rename-anchor-save",
        onDismissRequest = onDismiss,
        onConfirm = { onConfirm(anchor, name) }
    ) {
        SheetTextField(
            title = "ANCHOR NAME",
            value = name,
            onValueChange = { name = it },
            placeholder = "Display name",
            modifier = Modifier.testTag("rename-anchor-field")
        )
    }
}

@Composable
private fun AnchorScanDialog(
    anchors: List<PairedAnchor>,
    dialogState: AnchorScanSheetState,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    AnclaSheetDialog(
        title =
            when (dialogState.mode) {
                AnchorScanMode.PAIR -> "Pair Anchor"
                AnchorScanMode.ARM -> "Start Block"
                AnchorScanMode.RELEASE -> "Release Block"
            },
        onDismissRequest = onDismiss
    ) {
        Text(
            when (dialogState.mode) {
                AnchorScanMode.PAIR -> "Hold your Android phone near the NFC anchor you want to pair."
                AnchorScanMode.ARM -> "Hold your Android phone near a paired anchor to bind and start this session."
                AnchorScanMode.RELEASE -> "Hold your Android phone near the bound anchor. Only the active anchor will release the session."
            },
            modifier = Modifier.testTag("anchor-scan-dialog")
        )
        if (dialogState.mode != AnchorScanMode.PAIR && anchors.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                anchors.forEach { anchor ->
                    Text(
                        text = anchor.displayName,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.testTag("scan-anchor-${anchor.id}")
                    )
                }
            }
        }
        when (dialogState.status) {
            AnchorScanStatus.STARTING, AnchorScanStatus.WAITING -> {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    Text(
                        text = "Waiting for an NFC tag…",
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }

            AnchorScanStatus.UNAVAILABLE -> {
                AnchorScanStatusCard(
                    title = "NFC unavailable",
                    detail = dialogState.message ?: "NFC is unavailable on this Android phone.",
                    accent = MaterialTheme.colorScheme.error,
                    tag = "anchor-scan-unavailable"
                )
                SetupActionRow(
                    icon = Icons.Outlined.Settings,
                    title = "Open NFC settings",
                    detail = "Enable NFC on this Android phone, then try again.",
                    tag = "anchor-scan-open-nfc-settings",
                    onClick = { context.openNfcSettings() }
                )
            }

            AnchorScanStatus.FAILURE -> {
                AnchorScanStatusCard(
                    title = "Scan failed",
                    detail = dialogState.message ?: "Anchor scan failed.",
                    accent = MaterialTheme.colorScheme.error,
                    tag = "anchor-scan-failure"
                )
            }
        }
    }
}

@Composable
private fun AnchorScanStatusCard(
    title: String,
    detail: String,
    accent: Color,
    tag: String
) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.92f),
        border = BorderStroke(1.dp, accent.copy(alpha = 0.28f)),
        modifier = Modifier.fillMaxWidth().testTag(tag)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = title,
                color = accent,
                style = MaterialTheme.typography.titleMedium
            )
            Text(
                text = detail,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun StatusDot(status: ReadinessStatus) {
    val color =
        when (status) {
            ReadinessStatus.READY -> Color(0xFF2E7D32)
            ReadinessStatus.ACTION_REQUIRED -> Color(0xFFF9A825)
            ReadinessStatus.BLOCKED -> Color(0xFFC62828)
        }
    Box(
        modifier = Modifier
            .size(10.dp)
            .background(color = color, shape = CircleShape)
    )
}

@Preview(showBackground = true)
@Composable
private fun AnclaAppPreview() {
    AnclaTheme {
        AnclaApp()
    }
}
