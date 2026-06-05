plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.muhamed.smart_sheet"
    // تحديث إلى 36 لدعم البكجات الجديدة
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ تفعيل خاصية الـ Desugaring لدعم ميزات Java الحديثة
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.muhamed.smart_sheet"
        // minSdk = 21 مطلوب بواسطة flutter_foreground_task v9+
        minSdk = flutter.minSdkVersion
        targetSdk = 36 
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    lint {
        // تحذيرات مكتبات الطرف الثالث لا تعطل الـ Build
        abortOnError = false
        // تجاهل تحذيرات Java القديمة من camera_android_camerax
        disable += "ObsoleteLintCustomCheck"
    }
}

flutter {
    source = "../.."
}

dependencies {
    // المحافظة على نسخة Desugaring التي تعمل بها
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Force specific AndroidX versions to avoid SDK 36 requirements
// Keep this outside the `dependencies` block so it applies globally
configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
        force("androidx.core:core:1.13.1")
        force("androidx.core:core-ktx:1.13.1")
        force("androidx.activity:activity:1.9.3")
        force("androidx.activity:activity-ktx:1.9.3")
        force("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    }
}
