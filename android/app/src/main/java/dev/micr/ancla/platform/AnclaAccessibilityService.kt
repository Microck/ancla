package dev.micr.ancla.platform

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import dev.micr.ancla.MainActivity
import dev.micr.ancla.model.AccessibilityBlockingSnapshotPayload
import dev.micr.ancla.model.AndroidDataStoreAppStateStorage
import dev.micr.ancla.model.BlockingInterception
import java.util.UUID

open class AnclaAccessibilityService : AccessibilityService() {
    private var currentForegroundPackage: String? = null
    private var lastLockSurfacePackage: String? = null
    private var lastLockSurfaceSessionId: UUID? = null
    private var lastLockSurfaceSessionState: dev.micr.ancla.model.SessionState? = null
    private var lastLockSurfaceWindowId: Int? = null
    private var lastLockSurfaceEventType: Int? = null
    private var lockOverlayView: View? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val packageName = event?.packageName?.toString()?.takeIf { it.isNotBlank() } ?: return
        val previousForegroundPackage = currentForegroundPackage
        currentForegroundPackage = packageName
        if (packageName == ownPackageName()) {
            removeLockOverlay()
            return
        }
        val snapshot = loadBlockingSnapshot()
        val interception = snapshot.interceptionFor(packageName) ?: run {
            clearInterception(packageName)
            return
        }
        if (shouldSuppressDuplicate(interception, event, previousForegroundPackage)) return

        rememberInterception(
            packageName = packageName,
            sessionId = interception.sessionId,
            sessionState = interception.sessionState,
            windowId = event.windowId,
            eventType = event.eventType
        )
        startLockSurface(interception)
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        removeLockOverlay()
        super.onDestroy()
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInfo =
            serviceInfo?.apply {
                eventTypes =
                    AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                        AccessibilityEvent.TYPE_WINDOWS_CHANGED or
                        AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
                feedbackType = AccessibilityServiceInfo.FEEDBACK_ALL_MASK
                notificationTimeout = 50
                flags = flags or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            }
        resetInterceptionTracking()
    }

    protected open fun redirectBlockedAppToSafety() {
        performGlobalAction(GLOBAL_ACTION_HOME)
    }

    protected open fun startLockSurface(interception: BlockingInterception) {
        lastLockSurfacePackage = interception.packageName
        lastLockSurfaceSessionId = interception.sessionId
        lastLockSurfaceSessionState = interception.sessionState
        lastLockSurfaceWindowId = lastInterceptedWindowId
        lastLockSurfaceEventType = lastInterceptedWindowEventType
        redirectBlockedAppToSafety()
        showAccessibilityLockOverlay(interception)
        scheduleLockSurfaceLaunch(createLockSurfaceIntent(interception))
    }

    protected open fun loadBlockingSnapshot(): AccessibilityBlockingSnapshotPayload =
        resolveBlockingSnapshot(applicationContext)

    protected open fun showLockSurface(intent: Intent) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivity(intent)
            return
        }

        val creatorOptions =
            ActivityOptions.makeBasic().apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
                    setPendingIntentCreatorBackgroundActivityStartMode(
                        ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                    )
                }
            }
        val pendingIntent =
            PendingIntent.getActivity(
                this,
                LOCK_SURFACE_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                creatorOptions.toBundle()
            )
        val sendOptions =
            ActivityOptions.makeBasic().apply {
                setPendingIntentBackgroundActivityStartMode(
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                )
            }
        try {
            pendingIntent.send(
                this,
                0,
                null,
                null,
                null,
                null,
                sendOptions.toBundle()
            )
        } catch (_: PendingIntent.CanceledException) {
            startActivity(intent)
        }
    }

    protected open fun createLockSurfaceIntent(interception: BlockingInterception): Intent =
        lockSurfaceIntent(interception)

    protected open fun scheduleLockSurfaceLaunch(intent: Intent) {
        Handler(Looper.getMainLooper()).postDelayed(
            { showLockSurface(intent) },
            LOCK_SURFACE_LAUNCH_DELAY_MS
        )
    }

    protected open fun showAccessibilityLockOverlay(interception: BlockingInterception) {
        removeLockOverlay()
        val overlay =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(40, 56, 40, 56)
                background =
                    GradientDrawable(
                        GradientDrawable.Orientation.TOP_BOTTOM,
                        intArrayOf(Color.rgb(9, 12, 18), Color.rgb(16, 24, 32))
                    )
                isClickable = true
            }
        val mark =
            TextView(this).apply {
                text = "ANCLA"
                setTextColor(Color.rgb(238, 243, 233))
                textSize = 13f
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                letterSpacing = 0.12f
            }
        val title =
            TextView(this).apply {
                text = "You're anchored"
                setTextColor(Color.WHITE)
                textSize = 30f
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            }
        val detail =
            TextView(this).apply {
                text = "${interception.modeName} is active with ${interception.anchorName}."
                setTextColor(Color.rgb(189, 199, 190))
                textSize = 16f
                gravity = Gravity.CENTER
            }
        val blockedTarget =
            TextView(this).apply {
                text = "Blocked: ${interception.targetLabel ?: interception.packageName}"
                setTextColor(Color.rgb(229, 233, 222))
                textSize = 15f
                gravity = Gravity.CENTER
            }
        val openButton =
            Button(this).apply {
                text = "Open Ancla"
                setOnClickListener { showLockSurface(createLockSurfaceIntent(interception)) }
            }

        overlay.addView(mark, overlayTextParams(topMargin = 0, bottomMargin = 18))
        overlay.addView(title, overlayTextParams(topMargin = 0, bottomMargin = 12))
        overlay.addView(detail, overlayTextParams(topMargin = 0, bottomMargin = 24))
        overlay.addView(blockedTarget, overlayTextParams(topMargin = 0, bottomMargin = 28))
        overlay.addView(openButton, overlayButtonParams())

        val params =
            WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                android.graphics.PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }

        try {
            windowManager().addView(overlay, params)
            lockOverlayView = overlay
        } catch (_: RuntimeException) {
            lockOverlayView = null
        }
    }

    companion object {
        private const val LOCK_SURFACE_REQUEST_CODE = 4812
        private const val LOCK_SURFACE_LAUNCH_DELAY_MS = 120L
        private var lastInterceptedPackage: String? = null
        private var lastInterceptedSessionId: UUID? = null
        private var lastInterceptedSessionState: dev.micr.ancla.model.SessionState? = null
        private var lastInterceptedWindowId: Int? = null
        private var lastInterceptedWindowEventType: Int? = null

        internal var snapshotLoadOverride: ((Context) -> AccessibilityBlockingSnapshotPayload)? = null

        internal fun resolveBlockingSnapshot(context: Context): AccessibilityBlockingSnapshotPayload =
            snapshotLoadOverride?.invoke(context)
                ?: AndroidDataStoreAppStateStorage(context).loadBlockingSnapshot()

        internal fun lockSurfaceIntent(interception: BlockingInterception): Intent =
            Intent(Intent.ACTION_VIEW).apply {
                setClassName("dev.micr.ancla", MainActivity::class.java.name)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    addFlags(Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                }
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_PACKAGE, interception.packageName)
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_TARGET_LABEL, interception.targetLabel)
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_MODE_NAME, interception.modeName)
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_ANCHOR_NAME, interception.anchorName)
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_SESSION_ID, interception.sessionId.toString())
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_SESSION_STATE, interception.sessionState.name)
                putExtra(MainActivity.EXTRA_LOCK_SURFACE_SESSION_STARTED_AT, interception.sessionStartedAt.toString())
                putExtras(
                    Bundle().apply {
                        putString(MainActivity.EXTRA_LOCK_SURFACE_PACKAGE, interception.packageName)
                    }
                )
            }

        private fun ownPackageName(): String = "dev.micr.ancla"

        private fun resetInterceptionTracking() {
            lastInterceptedPackage = null
            lastInterceptedSessionId = null
            lastInterceptedSessionState = null
            lastInterceptedWindowId = null
            lastInterceptedWindowEventType = null
        }
    }

    private fun shouldSuppressDuplicate(
        interception: BlockingInterception,
        event: AccessibilityEvent,
        previousForegroundPackage: String?
    ): Boolean =
        interceptionMatchesLast(
            packageName = interception.packageName,
            sessionId = interception.sessionId,
            sessionState = interception.sessionState,
            windowId = event.windowId,
            eventType = event.eventType
        ) &&
            previousForegroundPackage == ownPackageName() &&
            lockSurfaceStillOwnsInterception(
                packageName = interception.packageName,
                sessionId = interception.sessionId,
                sessionState = interception.sessionState,
                windowId = event.windowId,
                eventType = event.eventType
            )

    private fun clearInterception(packageName: String) {
        if (lastInterceptedPackage == packageName || packageName == ownPackageName()) {
            resetInterceptionTracking()
        }
        if (lastLockSurfacePackage == packageName) {
            clearLockSurfaceTracking()
        }
        removeLockOverlay()
    }

    private fun clearLockSurfaceTracking() {
        lastLockSurfacePackage = null
        lastLockSurfaceSessionId = null
        lastLockSurfaceSessionState = null
        lastLockSurfaceWindowId = null
        lastLockSurfaceEventType = null
    }

    private fun rememberInterception(
        packageName: String,
        sessionId: UUID,
        sessionState: dev.micr.ancla.model.SessionState,
        windowId: Int,
        eventType: Int
    ) {
        lastInterceptedPackage = packageName
        lastInterceptedSessionId = sessionId
        lastInterceptedSessionState = sessionState
        lastInterceptedWindowId = windowId
        lastInterceptedWindowEventType = eventType
    }

    private fun interceptionMatchesLast(
        packageName: String,
        sessionId: UUID,
        sessionState: dev.micr.ancla.model.SessionState,
        windowId: Int,
        eventType: Int
    ): Boolean =
        lastInterceptedPackage == packageName &&
            lastInterceptedSessionId == sessionId &&
            lastInterceptedSessionState == sessionState &&
            lastInterceptedWindowId == windowId &&
            lastInterceptedWindowEventType == eventType

    private fun lockSurfaceStillOwnsInterception(
        packageName: String,
        sessionId: UUID,
        sessionState: dev.micr.ancla.model.SessionState,
        windowId: Int,
        eventType: Int
    ): Boolean =
        lastLockSurfacePackage == packageName &&
            lastLockSurfaceSessionId == sessionId &&
            lastLockSurfaceSessionState == sessionState &&
            lastLockSurfaceWindowId == windowId &&
        lastLockSurfaceEventType == eventType

    private fun removeLockOverlay() {
        val overlay = lockOverlayView ?: return
        try {
            windowManager().removeView(overlay)
        } catch (_: RuntimeException) {
        } finally {
            lockOverlayView = null
        }
    }

    private fun windowManager(): WindowManager =
        getSystemService(Context.WINDOW_SERVICE) as WindowManager

    private fun overlayTextParams(topMargin: Int, bottomMargin: Int): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            setMargins(0, topMargin, 0, bottomMargin)
        }

    private fun overlayButtonParams(): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
}
