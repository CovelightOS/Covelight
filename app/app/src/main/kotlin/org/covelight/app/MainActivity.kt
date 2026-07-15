package org.covelight.app

import android.os.Bundle
import android.view.View
import android.view.WindowManager
import org.godotengine.godot.GodotActivity

/**
 * T2.1 (docs/plan/03-phase2-kiosk.md): the Tier 1 host Activity. Embeds the
 * stock Godot engine (org.godotengine:godot) and points it at the shell
 * project's exported PCK, bundled as an asset.
 *
 * Deliberately thin: fullscreen immersive + keep-screen-on is everything
 * this task adds. Hardware back is already consumed by [GodotActivity]
 * itself -- it registers an always-on `OnBackPressedDispatcher` callback
 * that forwards the event into the running engine (`GodotLib.back()`)
 * instead of finishing the Activity (verified against
 * platform/android/java/lib/src/main/java/org/godotengine/godot/GodotActivity.kt
 * and Godot.kt at the 4.7-stable tag) -- no override needed here, and
 * adding one would only risk double-handling. Device Owner / lock-task
 * (radios, status bar, install blocking, boot persistence) is T2.2, not
 * this file.
 */
class MainActivity : GodotActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        applyImmersiveMode()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            applyImmersiveMode()
        }
    }

    override fun getCommandLine(): MutableList<String> {
        val args = super.getCommandLine()
        // shell.pck is built from /shell via `godot --export-pack "Android"`
        // (see /app/README.md) and bundled at assets/shell.pck. Path is
        // relative to the assets directory, per Godot's own Android
        // library docs.
        args.add("--main-pack")
        args.add("shell.pck")
        return args
    }

    @Suppress("DEPRECATION")
    private fun applyImmersiveMode() {
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
    }
}
