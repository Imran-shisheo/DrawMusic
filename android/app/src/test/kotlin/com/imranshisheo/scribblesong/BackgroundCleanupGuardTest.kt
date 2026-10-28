package com.imranshisheo.scribblesong

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicInteger

class BackgroundCleanupGuardTest {
    @Test fun pendingImportRecoveryOrVideoNeverGrantsCleanup() {
        val guard = BackgroundCleanupGuard()
        assertFalse(guard.acquire("startup", true))
        assertFalse(guard.isLocked())
        guard.release("startup")
        assertFalse(guard.acquire("hot-restart", false))
    }
    @Test fun ownerLeaseBlocksOtherWorkAndOnlyTheOwnerReleasesIt() {
        val guard = BackgroundCleanupGuard()
        assertTrue(guard.acquire("owner", false))
        assertTrue(guard.isLocked())
        assertFalse(guard.acquire("other", false))
        guard.release("other")
        assertTrue(guard.isLocked())
        guard.release("owner")
        assertFalse(guard.isLocked())
    }
    @Test fun completedStartupNeverReacquiresAfterDartHotRestart() {
        val guard = BackgroundCleanupGuard()
        assertTrue(guard.acquire("first", false))
        guard.release("first")
        assertFalse(guard.acquire("second", false))
    }
    @Test fun concurrentAttemptsHaveExactlyOneNativeOwner() {
        val guard = BackgroundCleanupGuard()
        val start = CountDownLatch(1)
        val acquired = AtomicInteger()
        val threads = (0 until 12).map { index -> Thread {
            start.await()
            if (guard.acquire("owner-$index", false)) acquired.incrementAndGet()
        }.apply { start() } }
        start.countDown()
        threads.forEach { it.join() }
        assertEquals(1, acquired.get())
        assertTrue(guard.isLocked())
    }
}
