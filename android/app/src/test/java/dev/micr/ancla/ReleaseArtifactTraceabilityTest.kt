package dev.micr.ancla

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReleaseArtifactTraceabilityTest {
    private val fixtureRoot = File("src/testFixtures/release-traceability")
    private val fixtureReport = File(fixtureRoot, "release-candidate.json")
    private val mutableWorkspaceReport = File("../../tmp/android-release/release-candidate.json")

    @Test
    fun buildConfigExposesReleaseTraceFields() {
        assertEquals("unknown", BuildConfig.RELEASE_TRACE_COMMIT)
        assertEquals("local", BuildConfig.RELEASE_TRACE_RUN)
        assertTrue(BuildConfig.RELEASE_TRACE_BUILT_AT.isNotBlank())
    }

    @Test
    fun releaseOutputMetadataDeclaresUnsignedReleaseApk() {
        val text = releaseCandidateReport()

        assertTrue(text.contains("\"applicationId\": \"dev.micr.ancla\""))
        assertTrue(text.contains("\"variant\": \"release\""))
        assertTrue(text.contains("\"versionCode\": 1"))
        assertTrue(text.contains("\"versionName\": \"0.1.0\""))
        assertTrue(text.contains("\"outputFile\": \"app-release-unsigned.apk\""))
    }

    @Test
    fun releaseAppBundleCarriesGradleAppMetadata() {
        val text = releaseCandidateReport()
        assertTrue(text.contains("\"bundleAppMetadata\": {"))
        assertTrue(text.contains("\"appMetadataVersion\": \"1.1\""))
        assertTrue(text.contains("\"androidGradlePluginVersion\": \"8.8.0\""))
    }

    @Test
    fun releaseApkCarriesGradleAppMetadata() {
        val text = releaseCandidateReport()
        assertTrue(text.contains("\"appMetadata\": {"))
        assertTrue(text.contains("\"appMetadataVersion\": \"1.1\""))
        assertTrue(text.contains("\"androidGradlePluginVersion\": \"8.8.0\""))
    }

    @Test
    fun dockerGradleScriptDocumentsAcceptedContainerWarningsAndAapt2Dependency() {
        val script = File("../scripts/docker-gradle.sh")
        assertTrue(script.exists())

        val text = script.readText()
        assertTrue(text.contains("Using the checked-in ARM64 static AAPT2 override"))
        assertTrue(text.contains("non-blocking metrics/analytics warning"))
        assertTrue(text.contains("-Dcom.android.tools.analyticsOptOut="))
        assertFalse(text.contains("android.aapt2FromMavenOverride=/opt/android-sdk-aarch64/build-tools/aapt2"))
    }

    @Test
    fun releaseArtifactsScriptEmitsStructuredBundleMetadata() {
        val text = releaseCandidateReport()
        assertTrue(text.contains("\"bundleAppMetadata\": {"))
        assertTrue(text.contains("\"androidGradlePluginVersion\": \"8.8.0\""))
        assertFalse(text.contains("\"bundleAppMetadata\": \"appMetadataVersion=1.1"))
    }

    @Test
    fun checkedInFixtureUsesDeterministicCanonicalPathsInsteadOfWorkspaceArtifacts() {
        val text = releaseCandidateReport()

        assertTrue(text.contains("\"path\": \"/canonical/fixture/app-release-unsigned.apk\""))
        assertTrue(text.contains("\"path\": \"/canonical/fixture/app-release.aab\""))
        assertFalse(text.contains("/home/ubuntu/workspace/ancla/"))
    }

    @Test
    fun checkedInFixtureStaysIndependentFromMutableWorkspaceReleaseCandidate() {
        val checkedInFixtureText = releaseCandidateReport()

        assertFalse(checkedInFixtureText.contains("feature:fix-release-candidate-browserstack-proof-linkage"))
        if (mutableWorkspaceReport.exists()) {
            val mutableWorkspaceText = mutableWorkspaceReport.readText()
            assertTrue(mutableWorkspaceText.contains("\"traceRun\": "))
            assertFalse(mutableWorkspaceText.contains("\"traceRun\": \"fixture-trace-run\""))
            assertFalse(checkedInFixtureText == mutableWorkspaceText)
        }
    }

    private fun releaseCandidateReport(): String {
        assertTrue("fixture root missing at ${fixtureRoot.absolutePath}", fixtureRoot.exists())
        assertTrue("fixture report missing at ${fixtureReport.absolutePath}", fixtureReport.exists())
        return fixtureReport.readText()
    }
}
