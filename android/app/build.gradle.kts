import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.luigir86.low_end"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // The app speaks English, Italian, Spanish and French (lib/l10n). They
    // must be in the APK as resources: Android hands the app the phone's
    // languages only as far as the app declares them, so an app with no
    // Italian resources is told the phone is in English. res/values-it,
    // -es and -fr hold them; the filter keeps the libraries' other
    // translations out of the APK.
    androidResources {
        localeFilters += listOf("en", "it", "es", "fr")
    }

    defaultConfig {
        // Permanent: Play knows the app by this id.
        applicationId = "com.luigir86.low_end"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The upload key stays out of the repository: android/key.properties
    // (git-ignored) says where the keystore is and holds its passwords.
    val keyProperties = Properties()
    val keyPropertiesFile = rootProject.file("key.properties")
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { keyProperties.load(it) }
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties a release build must fail: signed with
            // the debug key it would build and run, but could not be updated
            // by the Play Store version (see the check below).
            signingConfig = signingConfigs.findByName("release")
        }
    }

    // The Kotlin side (sharing, saving, "Open with Low End") has unit tests
    // in src/test, run on the computer with Robolectric: CI runs them with
    // ./gradlew :app:testDebugUnitTest. They read the app's real manifest
    // and resources, so they also check the provider and intent filters.
    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
}

// Debug and test builds need no key; only a release build does.
gradle.taskGraph.whenReady {
    val releaseBuild = allTasks.any { it.name.contains("Release", ignoreCase = true) }
    if (releaseBuild && !rootProject.file("key.properties").exists()) {
        throw GradleException(
            "android/key.properties is missing: a release build must be signed " +
                "with the upload key (see store/README.md).",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("androidx.test:core:1.6.1")
    constraints {
        // Guava comes in through the Player's ExoPlayer (AndroidX Media3,
        // brought by just_audio), which asks for 33.0.0-android. That
        // version has a known advisory (GHSA-xxph-c9ww-hj94, fixed in
        // 33.7.2): this raises it for the whole app without touching the
        // plugins. Remove it once just_audio brings a fixed Guava itself.
        implementation("com.google.guava:guava:33.7.2-android") {
            because("GHSA-xxph-c9ww-hj94: Guava before 33.7.2 is affected")
        }
    }
}

// The unit tests read the app's merged assets, into which the Flutter plugin
// copies its own (copyFlutterAssets<Variant>) without telling Gradle: say
// it, or Gradle 9 refuses to run them.
tasks.matching { it.name.startsWith("package") && it.name.endsWith("UnitTestForUnitTest") }
    .configureEach {
        val variant = name.removePrefix("package").removeSuffix("UnitTestForUnitTest")
        dependsOn("copyFlutterAssets$variant")
    }
