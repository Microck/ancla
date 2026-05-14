package dev.micr.ancla.model

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager

interface InstalledAppCatalog {
    fun availableTargets(): List<BlockingTarget>

    fun defaultExemptPackages(): Set<String>
}

class StaticInstalledAppCatalog(
    private val targets: List<BlockingTarget> = demoBlockingTargets(),
    private val exemptPackages: Set<String> = setOf("dev.micr.ancla")
) : InstalledAppCatalog {
    override fun availableTargets(): List<BlockingTarget> = targets

    override fun defaultExemptPackages(): Set<String> = exemptPackages
}

class AndroidInstalledAppCatalog(
    private val context: Context
) : InstalledAppCatalog {
    override fun availableTargets(): List<BlockingTarget> {
        val packageManager = context.packageManager
        val launcherIntent =
            Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
        val resolveInfos =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.queryIntentActivities(
                    launcherIntent,
                    PackageManager.ResolveInfoFlags.of(0L)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.queryIntentActivities(launcherIntent, 0)
            }

        return resolveInfos
            .mapNotNull { info ->
                val activityInfo = info.activityInfo ?: return@mapNotNull null
                val packageName = activityInfo.packageName ?: return@mapNotNull null
                if (packageName == context.packageName) {
                    return@mapNotNull null
                }
                BlockingTarget(
                    id = packageName,
                    label = info.loadLabel(packageManager)?.toString()?.trim().orEmpty().ifBlank { packageName },
                    packageName = packageName
                )
            }
            .distinctBy(BlockingTarget::packageName)
            .sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.label })
    }

    override fun defaultExemptPackages(): Set<String> {
        val packageManager = context.packageManager
        val packages = linkedSetOf(context.packageName)

        resolveActivityPackage(
            packageManager,
            Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
        )?.let(packages::add)
        resolveActivityPackage(packageManager, Intent(Settings.ACTION_SETTINGS))?.let(packages::add)
        resolveActivityPackage(packageManager, Intent(MediaStore.ACTION_IMAGE_CAPTURE))?.let(packages::add)
        resolveActivityPackage(packageManager, Intent(Intent.ACTION_OPEN_DOCUMENT))?.let(packages::add)
        resolveActivityPackage(packageManager, Intent(Intent.ACTION_INSTALL_PACKAGE))?.let(packages::add)

        val telecomManager = context.getSystemService(TelecomManager::class.java)
        telecomManager?.defaultDialerPackage?.let(packages::add)
        Telephony.Sms.getDefaultSmsPackage(context)?.let(packages::add)

        packages += setOf(
            "com.android.settings",
            "com.android.systemui",
            "com.android.documentsui",
            "com.google.android.documentsui",
            "com.android.packageinstaller",
            "com.google.android.packageinstaller",
            "com.android.permissioncontroller",
            "com.google.android.permissioncontroller"
        )
        return packages
    }

    private fun resolveActivityPackage(
        packageManager: PackageManager,
        intent: Intent
    ): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.resolveActivity(
                intent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
            )?.activityInfo?.packageName
        } else {
            @Suppress("DEPRECATION")
            packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
        }
}

fun demoBlockingTargets(): List<BlockingTarget> =
    listOf(
        BlockingTarget(id = "com.slack", label = "Slack", packageName = "com.slack"),
        BlockingTarget(id = "com.discord", label = "Discord", packageName = "com.discord"),
        BlockingTarget(id = "com.instagram.android", label = "Instagram", packageName = "com.instagram.android"),
        BlockingTarget(id = "com.android.chrome", label = "Chrome", packageName = "com.android.chrome"),
        BlockingTarget(id = "org.mozilla.firefox", label = "Firefox", packageName = "org.mozilla.firefox")
    )
