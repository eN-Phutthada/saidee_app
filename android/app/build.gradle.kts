import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val envProperties = Properties()
val envFile = project.file("../../.env")
if (envFile.exists()) {
    envProperties.load(FileInputStream(envFile))
}

android {
    namespace = "com.example.saidee_app" 
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.saidee_app"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = envProperties.getProperty("GOOGLE_MAPS_API_KEY") ?: "NOT_FOUND"
    }

    buildTypes {
        release {
            // สำหรับการทดสอบเบื้องต้นใช้ debug key ไปก่อน
            signingConfig = signingConfigs.getByName("debug")
            
            // ในอนาคตเมื่อจะลง Store ต้องมาตั้งค่า SigningConfig ที่นี่
            // isMinifyEnabled = true
            // isShrinkResources = true
        }
    }
}

flutter {
    source = "../.."
}