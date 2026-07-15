// T2.1 (docs/plan/03-phase2-kiosk.md): the Tier 1 Android kiosk wrapper.
// A plain Kotlin host app depending on the stock Godot Android engine
// library (org.godotengine:godot, published to Maven Central -- NOT
// Godot's own self-contained export/custom-build pipeline) so this stays
// a normal, auditable Gradle project that T2.2's Device Owner code can
// build on directly.
//
// Versions (AGP/Kotlin/compileSdk/Gradle) are pinned to exactly what the
// org.godotengine:godot 4.7.1.stable artifact was itself built and
// published with (godotengine/godot's own
// platform/android/java/app/config.gradle + gradle-wrapper.properties at
// tag 4.7-stable), not chosen independently -- mismatched AGP/Kotlin
// versions against a precompiled AAR is a real source of silent ABI/build
// breakage.
import org.gradle.api.artifacts.component.ModuleComponentIdentifier

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "org.covelight.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "org.covelight.app"
        // CLAUDE.md / docs/plan/03-phase2-kiosk.md T2.1: Android 8.0 floor.
        // Godot 4.7's own engine floor is API 24 (non-Vulkan GL
        // Compatibility renderer, which is what /shell uses -- see
        // shell/README.md) -- 26 is safely above that, not a conflict.
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Godot's project files (shell.pck) ship as an asset; the Android
    // Android Studio / gradle default asset packaging ignores dotfiles and
    // some patterns Godot project directories can contain. Mirrors the
    // exact pattern from the Godot Android library docs
    // (docs.godotengine.org/en/stable/tutorials/platform/android/android_library.html).
    androidResources {
        ignoreAssetsPattern = "!.svn:!.git:!.gitignore:!.ds_store:!*.scc:<dir>_*:!CVS:!thumbs.db:!picasa.ini:!*~"
    }

    packaging {
        jniLibs {
            // Matches Godot's own default for minSdk <= 29 (config.gradle's
            // shouldUseLegacyPackaging): uncompressed/extracted native libs
            // on very old API levels have had real compatibility issues.
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    // The stock Godot Android engine library -- zero Google dependencies
    // in its own published dependency graph (verified against Maven
    // Central's .module metadata for this exact version: only
    // kotlin-stdlib, androidx.fragment, androidx.documentfile).
    implementation("org.godotengine:godot:4.7.1.stable")
    // org.godotengine:godot declares this as a runtime-only dependency, so
    // it's present at run time but NOT on the compile classpath -- yet
    // GodotActivity's own public supertype is FragmentActivity. Godot's own
    // sample apps add it explicitly too; version matches
    // godotengine/godot's platform/android/java/app/config.gradle at
    // 4.7-stable exactly (same rationale as the AGP/Kotlin/compileSdk pins
    // above).
    implementation("androidx.fragment:fragment-ktx:1.8.6")
}

// CLAUDE.md #9: zero Google Play Services / Firebase dependencies,
// enforced by CI, not discipline (docs/plan/03-phase2-kiosk.md T2.1
// acceptance criterion). Walks every resolved runtime/compile
// configuration's dependency graph and fails the build the moment a
// forbidden group shows up anywhere in the tree, including transitively --
// a dependency added three levels deep by some future library is exactly
// the case discipline alone would miss.
val forbiddenDependencyGroups = listOf(
    "com.google.android.gms",
    "com.google.firebase",
    "com.google.android.play",
    "com.android.billingclient",
)

// Only the configurations that actually ship in a built app -- not
// test/androidTest/lint configurations, which can be legitimately
// unresolvable in a minimal project (no test deps declared yet) without
// that being a dependency-audit concern.
val auditedConfigurationNames = listOf(
    "debugCompileClasspath",
    "debugRuntimeClasspath",
    "releaseCompileClasspath",
    "releaseRuntimeClasspath",
)

tasks.register("assertNoGoogleDependencies") {
    group = "verification"
    description = "Fails if any Google Play Services / Firebase / Play Billing dependency appears anywhere in the resolved dependency tree (CLAUDE.md #9)."

    doLast {
        val offenders = mutableListOf<String>()
        auditedConfigurationNames
            .mapNotNull { name -> configurations.findByName(name) }
            .forEach { configuration ->
                // ResolutionResult resolves dependency-graph metadata (group/name/version),
                // not artifact files -- it doesn't throw on configurations that
                // can't fully resolve actual jars/aars, so a single misconfigured
                // configuration can't take down the whole audit.
                configuration.incoming.resolutionResult.allComponents.forEach { component ->
                    val id = component.id
                    if (id is ModuleComponentIdentifier) {
                        if (forbiddenDependencyGroups.any { forbidden -> id.group == forbidden || id.group.startsWith("$forbidden.") }) {
                            offenders += "${id.group}:${id.module}:${id.version} (via configuration '${configuration.name}')"
                        }
                    }
                }
            }

        if (offenders.isNotEmpty()) {
            throw GradleException(
                "Forbidden Google/Play dependency found (CLAUDE.md #9 -- no Play Services deps):\n" +
                    offenders.distinct().joinToString("\n") { "  - $it" },
            )
        }
    }
}

tasks.named("preBuild") {
    dependsOn("assertNoGoogleDependencies")
}
