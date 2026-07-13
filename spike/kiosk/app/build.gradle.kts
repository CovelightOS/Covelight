import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "org.covelight.spike.kiosk"
    compileSdk = 36

    defaultConfig {
        applicationId = "org.covelight.spike.kiosk"
        // CLAUDE.md: Tier 1 targets Android 8+ broadly.
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "spike"
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_11)
        }
    }
}

// Deliberately zero dependencies beyond the Android platform SDK itself —
// this is throwaway code answering one question, not a product.
