package org.covelight.spike.kiosk

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** No behavior beyond logging — the actual policy calls live in
 * [MainActivity.applyKioskPolicies], run once Device Owner is confirmed
 * active, not from this receiver's callbacks. */
class KioskAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        Log.i(TAG, "device admin enabled")
    }

    override fun onDisabled(context: Context, intent: Intent) {
        Log.i(TAG, "device admin disabled")
    }

    companion object {
        private const val TAG = "KioskSpike"
    }
}
