package dev.micr.ancla

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoundationSetupModesTraceabilityTest {
    private val artifactFile = File("../../tmp/android-foundation-setup-modes/traceability.json")

    @Test
    fun foundationArtifactExistsAndDeclaresOnlyFoundationScope() {
        assertTrue("missing artifact at ${artifactFile.absolutePath}", artifactFile.exists())
        val text = artifactFile.readText()

        assertTrue(text.contains("\"featureId\": \"rerun-foundation-setup-readiness-and-modes-traceable\""))
        assertTrue(text.contains("\"setup gating\""))
        assertTrue(text.contains("\"readiness diagnostics\""))
        assertTrue(text.contains("\"manual setup acknowledgment persistence\""))
        assertTrue(text.contains("\"mode CRUD/defaulting/selection\""))
        assertTrue(text.contains("\"start gating\""))
        assertTrue(text.contains("\"selected-vs-active mode presentation\""))
        assertTrue(text.contains("\"active-mode deletion cleanup\""))
    }

    @Test
    fun foundationArtifactExplicitlyExcludesLaterMilestoneFlows() {
        val text = artifactFile.readText()

        assertTrue(text.contains("\"excludedScope\": ["))
        assertTrue(text.contains("\"schedules\""))
        assertTrue(text.contains("\"unlock presets\""))
        assertTrue(text.contains("\"failsafes\""))
        assertTrue(text.contains("\"history\""))
        assertTrue(text.contains("\"blocking lock-surface release flows\""))
        assertFalse(text.contains("\"history or recent-session surfaces\""))
    }
}
