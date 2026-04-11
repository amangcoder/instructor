plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.layersiq.instructor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable core-library desugaring so java.time APIs work on API < 26
        // (required by flutter_local_notifications v18+).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.layersiq.instructor"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BoM — manages all Firebase library versions
    implementation(platform("com.google.firebase:firebase-bom:34.12.0"))
    implementation("com.google.firebase:firebase-analytics")
}

// Sentry 8.x pulls in sentry-compose-android by default. This app does not
// use Jetpack Compose, so exclude it to prevent ClassNotFoundException at
// runtime when Sentry tries to load Compose APIs.
configurations.all {
    exclude(group = "io.sentry", module = "sentry-compose-android")
}

flutter {
    source = "../.."
}
