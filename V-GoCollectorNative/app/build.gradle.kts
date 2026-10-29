plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Native, dependency-free rebuild of the Flutter collector. Play Protect blocked the
// Flutter build on the company phones; the same setup as VIP Relay (plain Kotlin,
// no libraries, debug key) installs on them, so this mirrors it on purpose.
android {
    namespace = "com.almobarmg.vgo.collector"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.almobarmg.vgo.collector"
        minSdk = 26
        targetSdk = 35
        versionCode = 6
        versionName = "1.3.1"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}
