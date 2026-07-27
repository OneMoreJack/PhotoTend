plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningEnvironment = mapOf(
    "storeFile" to System.getenv("PHOTOTEND_KEYSTORE_PATH"),
    "storePassword" to System.getenv("PHOTOTEND_KEYSTORE_PASSWORD"),
    "keyAlias" to System.getenv("PHOTOTEND_KEY_ALIAS"),
    "keyPassword" to System.getenv("PHOTOTEND_KEY_PASSWORD"),
)
val releaseSigningConfigured = releaseSigningEnvironment.values.all { !it.isNullOrBlank() }
val releaseTaskRequested =
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }

if (releaseTaskRequested && !releaseSigningConfigured) {
    throw GradleException(
        "Release signing requires PHOTOTEND_KEYSTORE_PATH, " +
            "PHOTOTEND_KEYSTORE_PASSWORD, PHOTOTEND_KEY_ALIAS, and " +
            "PHOTOTEND_KEY_PASSWORD.",
    )
}

android {
    namespace = "top.onemorejack.phototend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "top.onemorejack.phototend"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(releaseSigningEnvironment.getValue("storeFile")!!)
                storePassword = releaseSigningEnvironment.getValue("storePassword")
                keyAlias = releaseSigningEnvironment.getValue("keyAlias")
                keyPassword = releaseSigningEnvironment.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
