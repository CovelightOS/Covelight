package org.covelight.spike.kiosk

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.net.wifi.WifiManager
import android.os.Bundle
import android.os.UserManager
import android.util.Log
import android.view.View
import android.view.WindowManager

/**
 * The entire child-facing surface of this spike: a solid-colour View, full
 * screen, nothing else. No Godot, no shell, no content — this app exists to
 * answer one question (does Device Owner + lock task actually hold on real
 * hardware), not to be a kiosk product. See FINDINGS.md.
 */
class MainActivity : Activity() {

    private lateinit var dpm: DevicePolicyManager
    private lateinit var admin: ComponentName

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        admin = ComponentName(this, KioskAdminReceiver::class.java)

        goFullscreen()
        setContentView(View(this).apply { setBackgroundColor(Color.rgb(30, 144, 255)) })

        if (dpm.isDeviceOwnerApp(packageName)) {
            applyKioskPolicies()
        } else {
            // Not yet provisioned (e.g. installed but `dpm set-device-owner`
            // hasn't run) — draw the screen and stop. No policies, no lock
            // task attempt; startLockTask() without Device Owner backing is
            // a guaranteed crash.
            Log.w(TAG, "not device owner — run scripts/provision.sh first")
        }
    }

    override fun onResume() {
        super.onResume()
        // Defensive: re-enter lock task if something knocked us out of it.
        if (dpm.isDeviceOwnerApp(packageName) && !isInLockTaskMode()) {
            runCatching { startLockTask() }
                .onFailure { Log.w(TAG, "startLockTask on resume failed: $it") }
        }
    }

    /** Deliberately does nothing — there is no back destination and no exit
     * gesture in this spike. Whether the OS honours that at all (vs. e.g.
     * a vendor skin routing back to a home screen anyway) is itself a
     * finding to record. */
    override fun onBackPressed() {
        // no-op
    }

    private fun isInLockTaskMode(): Boolean =
        (getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager)
            .lockTaskModeState != android.app.ActivityManager.LOCK_TASK_MODE_NONE

    private fun goFullscreen() {
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                or WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
        )
    }

    /**
     * ARCHITECTURE §3.1's full policy set. Every call is wrapped and logged
     * rather than assumed — which of these actually stick, per device, is
     * what FINDINGS.md records. Nothing here is a product; it's a checklist
     * turned into code.
     */
    private fun applyKioskPolicies() {
        attempt("lock task packages") {
            dpm.setLockTaskPackages(admin, arrayOf(packageName))
        }
        attempt("lock task features (status bar / home / overview / notifications)") {
            dpm.setLockTaskFeatures(admin, DevicePolicyManager.LOCK_TASK_FEATURE_NONE)
        }
        attempt("keyguard disabled") {
            dpm.setKeyguardDisabled(admin, true)
        }
        attempt("persistent preferred HOME activity") {
            val homeFilter = IntentFilter(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                addCategory(Intent.CATEGORY_DEFAULT)
            }
            dpm.addPersistentPreferredActivity(
                admin,
                homeFilter,
                ComponentName(this, MainActivity::class.java)
            )
        }

        // User restrictions Device Owner is documented to enforce as actual
        // radio/state changes, not just "block the settings toggle."
        val restrictions = listOf(
            UserManager.DISALLOW_SAFE_BOOT,
            UserManager.DISALLOW_FACTORY_RESET,
            UserManager.DISALLOW_INSTALL_APPS,
            UserManager.DISALLOW_UNINSTALL_APPS,
            UserManager.DISALLOW_INSTALL_UNKNOWN_SOURCES,
            UserManager.DISALLOW_CONFIG_WIFI,
            UserManager.DISALLOW_BLUETOOTH,
            UserManager.DISALLOW_CONFIG_MOBILE_NETWORKS,
        )
        for (restriction in restrictions) {
            attempt("user restriction $restriction") {
                dpm.addUserRestriction(admin, restriction)
            }
        }

        // Wi-Fi: DISALLOW_CONFIG_WIFI above blocks the Settings toggle, but
        // doesn't necessarily turn an already-on radio off. Device Owner
        // apps are documented as exempt from the API 29+ restriction that
        // silently no-ops this call for ordinary apps — "documented as"
        // is doing a lot of work in that sentence, which is exactly why
        // this is a spike and not a merged feature. Record the real result.
        attempt("wifi disable") {
            (getSystemService(Context.WIFI_SERVICE) as WifiManager).isWifiEnabled = false
        }

        // Mobile data: deliberately NOT attempted programmatically. There is
        // no public, documented Device Owner API that reliably kills
        // cellular data across OEMs; the only private/reflection paths were
        // ruled out on purpose (CLAUDE.md: no hacky workarounds). The real
        // Tier 1 setup guide's SIM-removal step is the actual mitigation —
        // record in FINDINGS.md whether that remains necessary.

        Log.i(TAG, "kiosk policies applied, attempting startLockTask()")
        attempt("startLockTask") { startLockTask() }
    }

    private inline fun attempt(label: String, block: () -> Unit) {
        runCatching(block)
            .onSuccess { Log.i(TAG, "OK: $label") }
            .onFailure { Log.w(TAG, "FAILED: $label — $it") }
    }

    companion object {
        private const val TAG = "KioskSpike"
    }
}
