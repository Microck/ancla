package dev.micr.ancla.model

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertSame
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.ConscryptMode
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@ConscryptMode(ConscryptMode.Mode.OFF)
class AndroidDataStoreAppStateStorageTest {
    @After
    fun tearDown() {
        AndroidDataStoreAppStateStorage.resetSharedDataStoreForTests()
    }

    @Test
    fun wrappersReuseTheSameUnderlyingDataStore() {
        val context = ApplicationProvider.getApplicationContext<Context>()

        val first = AndroidDataStoreAppStateStorage.sharedDataStore(context)
        val second = AndroidDataStoreAppStateStorage.sharedDataStore(context)

        assertSame(first, second)
    }

    @Test
    fun repeatedStorageWrappersCanReadTheSamePreferencesFile() {
        runBlocking {
            val context = ApplicationProvider.getApplicationContext<Context>()
            val first = AndroidDataStoreAppStateStorage(context)
            val second = AndroidDataStoreAppStateStorage(context)

            first.save(AppState(blockingAuthorized = true))

            first.load()
            second.loadBlockingSnapshot()
        }
    }
}
