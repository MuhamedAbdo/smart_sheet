plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.muhamed.smart_sheet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ 1. تفعيل خاصية الـ Desugaring
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.muhamed.smart_sheet"
        // ✅ تأكد أن الحد الأدنى لنسخة أندرويد لا يقل عن 21 (مطلوب لخدمة الخلفية)
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // تفعيل MultiDex إذا واجهت مشكلة في عدد الدوال
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // يمكنك إضافة خيارات التحسين هنا لاحقاً
        }
    }
}

flutter {
    source = "../.."
}

// ✅ 2. إضافة المكتبة المطلوبة في نهاية الملف
dependencies {
    // قم بتحديث الرقم من 2.0.3 إلى 2.1.4
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
