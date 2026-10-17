plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 从环境变量读取签名配置，支持优雅降级
fun getEnvOrProperty(name: String): String? {
    return System.getenv(name) ?: project.findProperty(name) as String?
}

android {
    namespace = "run.daodao.chatmcp"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion
    // ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // 签名配置 - 优先使用环境变量签名，未配置时自动降级使用内置稳定签名以确保每次构建签名一致
    signingConfigs {
        val defaultStore = file("keystore/default_release.jks")

        create("release") {
            val envStorePath = getEnvOrProperty("SIGNING_STORE_PATH")
            val storeFile = envStorePath?.let { file(it) }
            val keyAlias = getEnvOrProperty("SIGNING_KEY_ALIAS")
            val storePassword = getEnvOrProperty("SIGNING_STORE_PASSWORD")
            val keyPassword = getEnvOrProperty("SIGNING_KEY_PASSWORD")

            // 只有在所有必要配置都存在时才设置自定义签名
            if (storeFile != null && storeFile.exists() &&
                !keyAlias.isNullOrEmpty() &&
                !storePassword.isNullOrEmpty() &&
                !keyPassword.isNullOrEmpty()) {
                this.storeFile = storeFile
                this.keyAlias = keyAlias
                this.storePassword = storePassword
                this.keyPassword = keyPassword
                println("✅ Release signing config loaded from environment/secrets")
            } else if (defaultStore.exists()) {
                // 使用仓库内置的稳定签名，解决每次 CI 随机 debug 签名导致无法覆盖安装更新的问题
                this.storeFile = defaultStore
                this.keyAlias = "chatmcp"
                this.storePassword = "chatmcp123"
                this.keyPassword = "chatmcp123"
                println("✅ Release signing config using default consistent keystore")
            } else {
                println("⚠️ Release signing config incomplete or missing, will use debug signing")
            }
        }

        getByName("debug") {
            if (defaultStore.exists()) {
                this.storeFile = defaultStore
                this.keyAlias = "chatmcp"
                this.storePassword = "chatmcp123"
                this.keyPassword = "chatmcp123"
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "run.daodao.chatmcp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // minSdk = flutter.minSdkVersion
        minSdkVersion(24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 智能选择签名配置
            val releaseSigningConfig = signingConfigs.getByName("release")
            val hasValidSigning = try {
                releaseSigningConfig.storeFile != null &&
                releaseSigningConfig.storeFile!!.exists() &&
                !releaseSigningConfig.keyAlias.isNullOrEmpty() &&
                !releaseSigningConfig.storePassword.isNullOrEmpty() &&
                !releaseSigningConfig.keyPassword.isNullOrEmpty()
            } catch (e: Exception) {
                false
            }

            signingConfig = if (hasValidSigning) {
                println("✅ Using release signing config")
                releaseSigningConfig
            } else {
                println("⚠️ Using debug signing config")
                signingConfigs.getByName("debug")
            }

            // 开启代码压缩和混淆（仅在使用自定义私有签名时，避免缺省签名环境下混淆影响调试）
            val isCustomSigned = !getEnvOrProperty("SIGNING_STORE_PATH").isNullOrEmpty()
            isMinifyEnabled = isCustomSigned
            isShrinkResources = isCustomSigned
            if (isCustomSigned) {
                proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            }
        }

        debug {
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}
