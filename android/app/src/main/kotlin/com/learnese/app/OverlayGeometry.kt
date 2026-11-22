package com.learnese.app

/**
 * Pure JVM geometry and gesture helpers for [OverlayController], kept Android-free for JUnit tests.
 */
object OverlayGeometry {
    /**
     * Snaps the floating button horizontally to the left or right screen edge
     * depending on which side of the horizontal midpoint its center lies on.
     */
    fun snapXToEdge(
        currentX: Int,
        buttonWidthPx: Int,
        screenWidthPx: Int,
        edgeMarginPx: Int,
    ): Int {
        val maxX = maxOf(edgeMarginPx, screenWidthPx - buttonWidthPx - edgeMarginPx)
        val buttonCenterX = currentX + (buttonWidthPx / 2f)
        val screenMidX = screenWidthPx / 2f
        return if (buttonCenterX < screenMidX) edgeMarginPx else maxX
    }

    /**
     * Clamps the vertical window offset inside safe screen bounds.
     */
    fun clampY(
        rawY: Int,
        buttonHeightPx: Int,
        screenHeightPx: Int,
        topInsetPx: Int,
        bottomInsetPx: Int,
    ): Int {
        val maxY = maxOf(topInsetPx, screenHeightPx - buttonHeightPx - bottomInsetPx)
        return rawY.coerceIn(topInsetPx, maxY)
    }

    /**
     * Returns true when the dragged button center falls within [hitRadiusPx]
     * of the bottom dismiss target center.
     */
    fun isInsideDismissZone(
        buttonCenterX: Float,
        buttonCenterY: Float,
        dismissCenterX: Float,
        dismissCenterY: Float,
        hitRadiusPx: Float,
    ): Boolean {
        if (hitRadiusPx <= 0f) return false
        val dx = buttonCenterX - dismissCenterX
        val dy = buttonCenterY - dismissCenterY
        return (dx * dx + dy * dy) <= (hitRadiusPx * hitRadiusPx)
    }

    /**
     * Returns true when total pointer travel stays within [touchSlopPx].
     */
    fun isTapGesture(dx: Float, dy: Float, touchSlopPx: Float): Boolean {
        return (dx * dx + dy * dy) <= (touchSlopPx * touchSlopPx)
    }
}

/**
 * Prevents accidental double-taps on the overlay button while allowing deliberate rapid saves.
 */
class TapDebouncer(val debounceMs: Long = DEFAULT_DEBOUNCE_MS) {
    init {
        require(debounceMs >= 0L) { "debounceMs must be non-negative" }
    }

    private var lastAcceptedMs: Long = Long.MIN_VALUE

    @Synchronized
    fun shouldAccept(nowElapsedMs: Long): Boolean {
        if (lastAcceptedMs != Long.MIN_VALUE && (nowElapsedMs - lastAcceptedMs) < debounceMs) {
            return false
        }
        lastAcceptedMs = nowElapsedMs
        return true
    }

    @Synchronized
    fun reset() {
        lastAcceptedMs = Long.MIN_VALUE
    }

    companion object {
        const val DEFAULT_DEBOUNCE_MS = 250L
    }
}
