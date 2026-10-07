plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val automatedStoreFile = System.getenv("ANDROID_SIGNING_STORE_FILE")
val automatedStorePassword = System.getenv("ANDROID_SIGNING_STORE_PASSWORD")
val automatedKeyAlias = System.getenv("ANDROID_SIGNING_KEY_ALIAS")
val automatedKeyPassword = System.getenv("ANDROID_SIGNING_KEY_PASSWORD")
val hasAutomatedSigning = listOf(
    automatedStoreFile,
    automatedStorePassword,
    automatedKeyAlias,
    automatedKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "com.codexmonitor.tablet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        if (hasAutomatedSigning) {
            create("automatedRelease") {
                storeFile = file(automatedStoreFile!!)
                storePassword = automatedStorePassword
                keyAlias = automatedKeyAlias
                keyPassword = automatedKeyPassword
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.codexmonitor.tablet"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Use the persistent Actions key for automated releases, and keep
            // the existing local debug key for development builds.
            signingConfig = if (hasAutomatedSigning) {
                signingConfigs.getByName("automatedRelease")
            } else {
                signingConfigs.getByName("debug")
            }
        }
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
