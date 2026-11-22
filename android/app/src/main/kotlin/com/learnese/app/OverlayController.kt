package com.learnese.app

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.core.content.ContextCompat
import kotlin.math.roundToInt

/**
 * Native TYPE_APPLICATION_OVERLAY floating save button owned by [RecordingService].
 * Lifetime is strictly bound to the active session: dragging onto the X dismiss zone
 * removes the overlay and terminates the session via [onDismissSession].
 */
class OverlayController(
    private val context: Context,
    private val onSaveRequested: (onSaveComplete: (success: Boolean) -> Unit) -> Unit,
    private val onDismissSession: () -> Unit,
) {
    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val tapDebouncer = TapDebouncer()
    private val density = context.resources.displayMetrics.density
    private val touchSlopPx = ViewConfiguration.get(context).scaledTouchSlop.toFloat()

    private val buttonSizePx = dp(BUTTON_SIZE_DP)
    private val edgeMarginPx = dp(EDGE_MARGIN_DP)
    private val topInsetPx = dp(TOP_INSET_DP)
    private val bottomInsetPx = dp(BOTTOM_INSET_DP)
    private val dismissSizePx = dp(DISMISS_SIZE_DP)
    private val dismissBottomMarginPx = dp(DISMISS_BOTTOM_MARGIN_DP)
    private val dismissHitRadiusPx = dp(DISMISS_HIT_RADIUS_DP).toFloat()

    private var bubbleRoot: FrameLayout? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var bubbleBackground: GradientDrawable? = null
    private var iconView: ImageView? = null
    private var recordingDot: View? = null
    private var dotPulseAnimator: ObjectAnimator? = null
    private var snapAnimator: ValueAnimator? = null

    private var dismissRoot: FrameLayout? = null
    private var dismissParams: WindowManager.LayoutParams? = null
    private var isDismissVisible = false
    private var isHoveringDismiss = false
    private var isShown = false

    private val resetFeedbackRunnable = Runnable { restoreIdleAppearance() }

    fun show(): Boolean {
        if (isShown) return true
        if (!Settings.canDrawOverlays(context)) return false

        val (screenW, screenH) = currentScreenSize()
        val initialX = OverlayGeometry.snapXToEdge(
            currentX = screenW,
            buttonWidthPx = buttonSizePx,
            screenWidthPx = screenW,
            edgeMarginPx = edgeMarginPx,
        )
        val initialY = OverlayGeometry.clampY(
            rawY = (screenH * 0.35f).roundToInt(),
            buttonHeightPx = buttonSizePx,
            screenHeightPx = screenH,
            topInsetPx = topInsetPx,
            bottomInsetPx = bottomInsetPx,
        )

        val root = buildBubbleView()
        val params = WindowManager.LayoutParams(
            buttonSizePx,
            buttonSizePx,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = initialX
            y = initialY
        }

        val dismissView = buildDismissView()
        val dParams = WindowManager.LayoutParams(
            dismissSizePx,
            dismissSizePx,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (screenW - dismissSizePx) / 2
            y = screenH - dismissSizePx - dismissBottomMarginPx
        }

        try {
            windowManager.addView(root, params)
            bubbleRoot = root
            bubbleParams = params
            dismissRoot = dismissView
            dismissParams = dParams
            isShown = true
            startRecordingDotPulse()
            return true
        } catch (_: Throwable) {
            hide()
            return false
        }
    }

    fun hide() {
        mainHandler.removeCallbacks(resetFeedbackRunnable)
        dotPulseAnimator?.cancel()
        dotPulseAnimator = null
        snapAnimator?.cancel()
        snapAnimator = null
        tapDebouncer.reset()

        hideDismissTarget()
        bubbleRoot?.let { view ->
            try {
                windowManager.removeViewImmediate(view)
            } catch (_: Throwable) {
                // Already detached.
            }
        }
        bubbleRoot = null
        bubbleParams = null
        bubbleBackground = null
        iconView = null
        recordingDot = null
        dismissRoot = null
        dismissParams = null
        isShown = false
    }

    fun reclampToScreen() {
        val root = bubbleRoot ?: return
        val params = bubbleParams ?: return
        val (screenW, screenH) = currentScreenSize()

        params.x = OverlayGeometry.snapXToEdge(
            currentX = params.x,
            buttonWidthPx = buttonSizePx,
            screenWidthPx = screenW,
            edgeMarginPx = edgeMarginPx,
        )
        params.y = OverlayGeometry.clampY(
            rawY = params.y,
            buttonHeightPx = buttonSizePx,
            screenHeightPx = screenH,
            topInsetPx = topInsetPx,
            bottomInsetPx = bottomInsetPx,
        )
        try {
            windowManager.updateViewLayout(root, params)
        } catch (_: Throwable) {
            // View may have been detached concurrently.
        }

        dismissParams?.let { dParams ->
            dParams.x = (screenW - dismissSizePx) / 2
            dParams.y = screenH - dismissSizePx - dismissBottomMarginPx
            if (isDismissVisible) {
                dismissRoot?.let { dView ->
                    try {
                        windowManager.updateViewLayout(dView, dParams)
                    } catch (_: Throwable) {
                        // Ignore.
                    }
                }
            }
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun buildBubbleView(): FrameLayout {
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(ContextCompat.getColor(context, R.color.overlay_surface))
            setStroke(
                dp(1.5f),
                ContextCompat.getColor(context, R.color.overlay_border),
            )
        }
        bubbleBackground = bg

        val container = FrameLayout(context).apply {
            background = bg
            elevation = dp(6f).toFloat()
            contentDescription = "Save audio replay clip"
        }

        val icon = ImageView(context).apply {
            setImageResource(R.drawable.ic_overlay_save)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
        }
        val iconSize = dp(24f)
        container.addView(
            icon,
            FrameLayout.LayoutParams(iconSize, iconSize, Gravity.CENTER),
        )
        iconView = icon

        val dotSize = dp(8f)
        val dot = View(context).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(ContextCompat.getColor(context, R.color.learnese_recording_dot))
            }
        }
        container.addView(
            dot,
            FrameLayout.LayoutParams(dotSize, dotSize, Gravity.TOP or Gravity.END).apply {
                topMargin = dp(6f)
                marginEnd = dp(6f)
            },
        )
        recordingDot = dot

        attachTouchHandler(container)
        return container
    }

    private fun buildDismissView(): FrameLayout {
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(ContextCompat.getColor(context, R.color.overlay_dismiss_bg))
        }
        val container = FrameLayout(context).apply {
            background = bg
            elevation = dp(8f).toFloat()
            contentDescription = "Drop here to end recording session"
        }
        val icon = ImageView(context).apply {
            setImageResource(R.drawable.ic_overlay_dismiss)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
        }
        val iconSize = dp(26f)
        container.addView(
            icon,
            FrameLayout.LayoutParams(iconSize, iconSize, Gravity.CENTER),
        )
        return container
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun attachTouchHandler(container: FrameLayout) {
        var initialWindowX = 0
        var initialWindowY = 0
        var downRawX = 0f
        var downRawY = 0f
        var dragging = false

        container.setOnTouchListener { _, event ->
            val params = bubbleParams ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    snapAnimator?.cancel()
                    initialWindowX = params.x
                    initialWindowY = params.y
                    downRawX = event.rawX
                    downRawY = event.rawY
                    dragging = false
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downRawX
                    val dy = event.rawY - downRawY
                    if (!dragging && !OverlayGeometry.isTapGesture(dx, dy, touchSlopPx)) {
                        dragging = true
                        showDismissTarget()
                    }
                    if (dragging) {
                        val (screenW, screenH) = currentScreenSize()
                        params.x = (initialWindowX + dx.roundToInt())
                            .coerceIn(0, maxOf(0, screenW - buttonSizePx))
                        params.y = OverlayGeometry.clampY(
                            rawY = initialWindowY + dy.roundToInt(),
                            buttonHeightPx = buttonSizePx,
                            screenHeightPx = screenH,
                            topInsetPx = topInsetPx,
                            bottomInsetPx = dp(8f),
                        )
                        try {
                            windowManager.updateViewLayout(container, params)
                        } catch (_: Throwable) {
                            // Ignore if detached mid-drag.
                        }
                        updateDismissHoverState(params)
                    }
                    true
                }

                MotionEvent.ACTION_UP -> {
                    if (!dragging) {
                        handleTap()
                    } else {
                        val shouldDismiss = isHoveringDismiss
                        hideDismissTarget()
                        if (shouldDismiss) {
                            hide()
                            onDismissSession()
                        } else {
                            snapBubbleToNearestEdge()
                        }
                    }
                    true
                }

                MotionEvent.ACTION_CANCEL -> {
                    if (dragging) {
                        hideDismissTarget()
                        snapBubbleToNearestEdge()
                    }
                    true
                }

                else -> false
            }
        }
    }

    private fun handleTap() {
        val now = SystemClock.elapsedRealtime()
        if (!tapDebouncer.shouldAccept(now)) return

        bubbleRoot?.animate()
            ?.scaleX(0.88f)
            ?.scaleY(0.88f)
            ?.setDuration(75L)
            ?.withEndAction {
                bubbleRoot?.animate()?.scaleX(1f)?.scaleY(1f)?.setDuration(90L)?.start()
            }
            ?.start()

        onSaveRequested { success ->
            mainHandler.post {
                if (!isShown) return@post
                showSaveFeedback(success)
            }
        }
    }

    private fun showSaveFeedback(success: Boolean) {
        mainHandler.removeCallbacks(resetFeedbackRunnable)
        val bg = bubbleBackground ?: return
        val icon = iconView ?: return

        if (success) {
            bg.setColor(ContextCompat.getColor(context, R.color.overlay_save_flash))
            icon.setImageResource(R.drawable.ic_overlay_check)
            mainHandler.postDelayed(resetFeedbackRunnable, SAVE_FEEDBACK_DURATION_MS)
        } else {
            bg.setColor(ContextCompat.getColor(context, R.color.overlay_dismiss_bg))
            mainHandler.postDelayed(resetFeedbackRunnable, ERROR_FEEDBACK_DURATION_MS)
        }
    }

    private fun restoreIdleAppearance() {
        if (!isShown) return
        bubbleBackground?.setColor(ContextCompat.getColor(context, R.color.overlay_surface))
        iconView?.setImageResource(R.drawable.ic_overlay_save)
    }

    private fun showDismissTarget() {
        if (isDismissVisible) return
        val dView = dismissRoot ?: return
        val dParams = dismissParams ?: return
        val (screenW, screenH) = currentScreenSize()
        dParams.x = (screenW - dismissSizePx) / 2
        dParams.y = screenH - dismissSizePx - dismissBottomMarginPx
        try {
            dView.alpha = 0f
            dView.scaleX = 0.85f
            dView.scaleY = 0.85f
            windowManager.addView(dView, dParams)
            isDismissVisible = true
            isHoveringDismiss = false
            dView.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(140L).start()
        } catch (_: Throwable) {
            isDismissVisible = false
        }
    }

    private fun hideDismissTarget() {
        isHoveringDismiss = false
        bubbleRoot?.alpha = 1f
        if (!isDismissVisible) return
        dismissRoot?.let { dView ->
            try {
                windowManager.removeViewImmediate(dView)
            } catch (_: Throwable) {
                // Already removed.
            }
        }
        isDismissVisible = false
    }

    private fun updateDismissHoverState(currentBubbleParams: WindowManager.LayoutParams) {
        val dParams = dismissParams ?: return
        val hovering = OverlayGeometry.isInsideDismissZone(
            buttonCenterX = currentBubbleParams.x + (buttonSizePx / 2f),
            buttonCenterY = currentBubbleParams.y + (buttonSizePx / 2f),
            dismissCenterX = dParams.x + (dismissSizePx / 2f),
            dismissCenterY = dParams.y + (dismissSizePx / 2f),
            hitRadiusPx = dismissHitRadiusPx,
        )
        if (hovering == isHoveringDismiss) return
        isHoveringDismiss = hovering

        val targetScale = if (hovering) 1.18f else 1.0f
        dismissRoot?.animate()?.scaleX(targetScale)?.scaleY(targetScale)?.setDuration(100L)?.start()
        bubbleRoot?.alpha = if (hovering) 0.72f else 1f
    }

    private fun snapBubbleToNearestEdge() {
        val root = bubbleRoot ?: return
        val params = bubbleParams ?: return
        val (screenW, screenH) = currentScreenSize()

        val targetX = OverlayGeometry.snapXToEdge(
            currentX = params.x,
            buttonWidthPx = buttonSizePx,
            screenWidthPx = screenW,
            edgeMarginPx = edgeMarginPx,
        )
        val clampedY = OverlayGeometry.clampY(
            rawY = params.y,
            buttonHeightPx = buttonSizePx,
            screenHeightPx = screenH,
            topInsetPx = topInsetPx,
            bottomInsetPx = bottomInsetPx,
        )
        params.y = clampedY

        snapAnimator?.cancel()
        snapAnimator = ValueAnimator.ofInt(params.x, targetX).apply {
            duration = SNAP_DURATION_MS
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                if (!isShown) return@addUpdateListener
                params.x = anim.animatedValue as Int
                try {
                    windowManager.updateViewLayout(root, params)
                } catch (_: Throwable) {
                    cancel()
                }
            }
            start()
        }
    }

    private fun startRecordingDotPulse() {
        val dot = recordingDot ?: return
        dotPulseAnimator?.cancel()
        dotPulseAnimator = ObjectAnimator.ofFloat(dot, View.ALPHA, 1f, 0.35f).apply {
            duration = 850L
            repeatMode = ValueAnimator.REVERSE
            repeatCount = ValueAnimator.INFINITE
            start()
        }
    }

    private fun currentScreenSize(): Pair<Int, Int> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            Pair(bounds.width(), bounds.height())
        } else {
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealMetrics(metrics)
            Pair(metrics.widthPixels, metrics.heightPixels)
        }
    }

    private fun dp(value: Float): Int = (value * density).roundToInt()

    companion object {
        private const val BUTTON_SIZE_DP = 52f
        private const val EDGE_MARGIN_DP = 12f
        private const val TOP_INSET_DP = 36f
        private const val BOTTOM_INSET_DP = 48f
        private const val DISMISS_SIZE_DP = 64f
        private const val DISMISS_BOTTOM_MARGIN_DP = 56f
        private const val DISMISS_HIT_RADIUS_DP = 56f
        private const val SNAP_DURATION_MS = 180L
        private const val SAVE_FEEDBACK_DURATION_MS = 600L
        private const val ERROR_FEEDBACK_DURATION_MS = 320L
    }
}
