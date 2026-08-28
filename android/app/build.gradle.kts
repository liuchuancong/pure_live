import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services") apply false
    id("dev.flutter.flutter-gradle-plugin")
}

apply(plugin = "com.google.gms.google-services")

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

extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
    namespace = "com.mystyle.purelive"
    compileSdk = 37
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

    defaultConfig {
        applicationId = "com.mystyle.purelive"
        minSdk = 26
        multiDexEnabled = true
        targetSdk = 37
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
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
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

dependencies {
    implementation("androidx.activity:activity-ktx:1.10.1")
}

flutter {
    source = "../.."
}

tasks.matching {
    it.name.contains("flutter", ignoreCase = true) || it.name.startsWith("assemble")
}.configureEach {
    notCompatibleWithConfigurationCache(
        "Flutter Gradle tasks are not yet compatible with AGP Built-in Kotlin state"
    )
}