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

    // The app speaks English and Italian (lib/l10n). Both must be in the
    // APK as resources: Android hands the app the phone's languages only as
    // far as the app declares them, so an app with no Italian resources is
    // told the phone is in English. res/values-it holds the Italian one;
    // the filter keeps the libraries' other translations out of the APK.
    androidResources {
        localeFilters += listOf("en", "it", "es", "fr")
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
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
