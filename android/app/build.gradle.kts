import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") apply false
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

apply(plugin = "com.google.gms.google-services")

// 加载签名配置
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use(::load)
    }
}
val releaseStoreFile = keystoreProperties.getProperty("storeFile")?.let(::file)
val hasReleaseSigning = listOf("keyAlias", "keyPassword", "storePassword").all {
    !keystoreProperties.getProperty(it).isNullOrBlank()
} && releaseStoreFile?.isFile == true
val requireReleaseSigning =
    providers.gradleProperty("pureLive.requireReleaseSigning").orNull.toBoolean() ||
        providers.gradleProperty("pureLiveRequireReleaseSigning").orNull.toBoolean()
if (requireReleaseSigning && !hasReleaseSigning) {
    throw GradleException("Release signing is required but android/key.properties is incomplete.")
}

android {
    namespace = "com.mystyle.purelive"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    lint {
        disable.add("NullSafeMutableLiveData")
        checkReleaseBuilds = true
        abortOnError = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.mystyle.purelive"
        minSdk = flutter.minSdkVersion 
        multiDexEnabled = true 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "纯粹直播"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
       release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("Release key not configured; using the local debug key for a test-only formal-package build.")
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                  getDefaultProguardFile("proguard-android-optimize.txt"),
                  file("proguard-rules.pro")
              )
        }
       debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}    
