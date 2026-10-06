package dev.anais.tshop.composeuitests

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ImeVisibilityTest {
    @Test
    fun gridStaysVisibleAboveMinimumLeftoverHeight() {
        assertTrue(gridRemainsVisible(remainingHeight = 200f, minVisible = 80f))
        assertFalse(gridRemainsVisible(remainingHeight = 20f, minVisible = 80f))
    }
}
