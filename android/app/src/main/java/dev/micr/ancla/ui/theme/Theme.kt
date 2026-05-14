package dev.micr.ancla.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColors = lightColorScheme(
    primary = AccentFill,
    onPrimary = CtaText,
    background = Background,
    onBackground = PrimaryText,
    surface = Panel,
    onSurface = PrimaryText,
    surfaceVariant = PanelInteractive,
    onSurfaceVariant = SecondaryText,
    primaryContainer = PanelRaised,
    onPrimaryContainer = PrimaryText,
    secondaryContainer = PanelInteractive,
    onSecondaryContainer = PrimaryText,
    tertiaryContainer = LivePanel,
    onTertiaryContainer = PrimaryText,
    error = ErrorText,
    onError = PrimaryText,
    errorContainer = LivePanelRaised,
    onErrorContainer = PrimaryText,
    outline = PanelStroke
)

private val DarkColors = darkColorScheme(
    primary = AccentFill,
    onPrimary = CtaText,
    background = Background,
    onBackground = PrimaryText,
    surface = Panel,
    onSurface = PrimaryText,
    surfaceVariant = PanelInteractive,
    onSurfaceVariant = SecondaryText,
    primaryContainer = PanelRaised,
    onPrimaryContainer = PrimaryText,
    secondaryContainer = PanelInteractive,
    onSecondaryContainer = PrimaryText,
    tertiaryContainer = LivePanel,
    onTertiaryContainer = PrimaryText,
    error = ErrorText,
    onError = PrimaryText,
    errorContainer = LivePanelRaised,
    onErrorContainer = PrimaryText,
    outline = PanelStroke
)

@Composable
fun AnclaTheme(
    darkTheme: Boolean = false,
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = Typography,
        content = content
    )
}
