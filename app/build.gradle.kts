// Tier 1 (CLAUDE.md): Android kiosk wrapper. Root build script only
// declares plugin versions -- see app/build.gradle.kts for the actual
// module configuration.
plugins {
    id("com.android.application") version "8.6.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.21" apply false
}
