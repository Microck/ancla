package dev.micr.ancla.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import dev.micr.ancla.R

private val AnclaFontFamily =
    FontFamily(
        Font(R.font.google_sans_flex_400, FontWeight.Normal),
        Font(R.font.google_sans_flex_500, FontWeight.Medium),
        Font(R.font.google_sans_flex_600, FontWeight.SemiBold),
        Font(R.font.google_sans_flex_700, FontWeight.Bold)
    )

val Typography =
    Typography(
        headlineMedium =
            TextStyle(
                fontFamily = AnclaFontFamily,
                fontWeight = FontWeight.SemiBold,
                fontSize = 34.sp,
                lineHeight = 38.sp
            ),
        headlineSmall =
            TextStyle(
                fontFamily = AnclaFontFamily,
                fontWeight = FontWeight.SemiBold,
                fontSize = 22.sp,
                lineHeight = 26.sp
            ),
        titleLarge =
            TextStyle(
                fontFamily = AnclaFontFamily,
                fontWeight = FontWeight.SemiBold,
                fontSize = 18.sp,
                lineHeight = 22.sp
            ),
        titleMedium =
            TextStyle(
                fontFamily = AnclaFontFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 15.sp,
                lineHeight = 20.sp
            ),
        bodyLarge =
            TextStyle(
                fontFamily = AnclaFontFamily,
                fontWeight = FontWeight.Normal,
                fontSize = 16.sp,
                lineHeight = 22.sp
            ),
        bodyMedium =
            TextStyle(
                fontFamily = AnclaFontFamily,
                fontWeight = FontWeight.Normal,
                fontSize = 13.sp,
                lineHeight = 19.sp
            ),
        bodySmall =
            TextStyle(
                fontFamily = AnclaFontFamily,
                fontWeight = FontWeight.Normal,
                fontSize = 12.sp,
                lineHeight = 16.sp
            ),
        labelLarge =
            TextStyle(
                fontFamily = AnclaFontFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 13.sp,
                lineHeight = 16.sp
            ),
        labelMedium =
            TextStyle(
                fontFamily = AnclaFontFamily,
                fontWeight = FontWeight.Medium,
                fontSize = 12.sp,
                lineHeight = 14.sp
            ),
        labelSmall =
            TextStyle(
                fontFamily = AnclaFontFamily,
                fontWeight = FontWeight.SemiBold,
                fontSize = 10.sp,
                lineHeight = 12.sp,
                letterSpacing = 0.6.sp
            )
    )
