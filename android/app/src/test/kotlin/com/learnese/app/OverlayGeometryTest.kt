package com.learnese.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OverlayGeometryTest {
    @Test
    fun snapXToEdgeSnapsLeftWhenCenterIsLeftOfMidpoint() {
        val snapped = OverlayGeometry.snapXToEdge(
            currentX = 200,
            buttonWidthPx = 100,
            screenWidthPx = 1080,
            edgeMarginPx = 24,
        )
        assertEquals(24, snapped)
    }

    @Test
    fun snapXToEdgeSnapsRightWhenCenterIsAtOrRightOfMidpoint() {
        val snapped = OverlayGeometry.snapXToEdge(
            currentX = 500,
            buttonWidthPx = 100,
            screenWidthPx = 1080,
            edgeMarginPx = 24,
        )
        // center = 550 >= 540 -> right edge = 1080 - 100 - 24 = 956
        assertEquals(956, snapped)
    }

    @Test
    fun clampYKeepsButtonWithinTopAndBottomInsets() {
        assertEquals(
            80,
            OverlayGeometry.clampY(
                rawY = -50,
                buttonHeightPx = 100,
                screenHeightPx = 2000,
                topInsetPx = 80,
                bottomInsetPx = 120,
            ),
        )
        assertEquals(
            1780,
            OverlayGeometry.clampY(
                rawY = 1950,
                buttonHeightPx = 100,
                screenHeightPx = 2000,
                topInsetPx = 80,
                bottomInsetPx = 120,
            ),
        )
        assertEquals(
            640,
            OverlayGeometry.clampY(
                rawY = 640,
                buttonHeightPx = 100,
                screenHeightPx = 2000,
                topInsetPx = 80,
                bottomInsetPx = 120,
            ),
        )
    }

    @Test
    fun isInsideDismissZoneChecksRadialHitArea() {
        assertTrue(
            OverlayGeometry.isInsideDismissZone(
                buttonCenterX = 540f,
                buttonCenterY = 1800f,
                dismissCenterX = 540f,
                dismissCenterY = 1820f,
                hitRadiusPx = 100f,
            ),
        )
        // Exact boundary (distance == radius)
        assertTrue(
            OverlayGeometry.isInsideDismissZone(
                buttonCenterX = 640f,
                buttonCenterY = 1800f,
                dismissCenterX = 540f,
                dismissCenterY = 1800f,
                hitRadiusPx = 100f,
            ),
        )
        // Just outside radius
        assertFalse(
            OverlayGeometry.isInsideDismissZone(
                buttonCenterX = 641f,
                buttonCenterY = 1800f,
                dismissCenterX = 540f,
                dismissCenterY = 1800f,
                hitRadiusPx = 100f,
            ),
        )
        // Non-positive radius never matches
        assertFalse(
            OverlayGeometry.isInsideDismissZone(
                buttonCenterX = 540f,
                buttonCenterY = 1800f,
                dismissCenterX = 540f,
                dismissCenterY = 1800f,
                hitRadiusPx = 0f,
            ),
        )
    }

    @Test
    fun isTapGestureDistinguishesTapFromDrag() {
        assertTrue(OverlayGeometry.isTapGesture(dx = 6f, dy = 8f, touchSlopPx = 10f))
        assertFalse(OverlayGeometry.isTapGesture(dx = 8f, dy = 8f, touchSlopPx = 10f))
    }

    @Test
    fun tapDebouncerAbsorbsAccidentalDoubleTapAndAllowsRapidPresses() {
        val debouncer = TapDebouncer(debounceMs = 250L)

        assertTrue(debouncer.shouldAccept(nowElapsedMs = 1_000L))
        assertFalse(debouncer.shouldAccept(nowElapsedMs = 1_100L))
        assertFalse(debouncer.shouldAccept(nowElapsedMs = 1_249L))
        assertTrue(debouncer.shouldAccept(nowElapsedMs = 1_250L))
        assertFalse(debouncer.shouldAccept(nowElapsedMs = 1_400L))

        debouncer.reset()
        assertTrue(debouncer.shouldAccept(nowElapsedMs = 1_410L))
    }
}
