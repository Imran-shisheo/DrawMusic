package com.devwithdelta.doodimo

/** Main-channel startup lease. An unsafe/native operation never races sweep. */
internal class BackgroundCleanupGuard {
    private var owner: String? = null
    private var sealed = false
    @Synchronized fun acquire(token: String, unsafe: Boolean): Boolean {
        if (sealed || unsafe || owner != null) return false
        owner = token
        return true
    }
    @Synchronized fun release(token: String) {
        if (owner == token) owner = null
        // The normal startup attempt permanently seals this native engine.
        // A Dart hot restart cannot collect while old native work may survive.
        sealed = true
    }
    @Synchronized fun isLocked(): Boolean = owner != null
}
