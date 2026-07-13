package org.covelight.spike.kiosk

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Boot persistence (ARCHITECTURE §3.1): relaunch the kiosk activity after
 * reboot without waiting for a user tap. Whether this actually fires before
 * or after the vendor launcher on a given skin is exactly what this spike
 * exists to find out — see FINDINGS.md. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val launch = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(launch)
    }
}
