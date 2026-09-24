plugins {
            id("com.android.application")
                id("dev.flutter.flutter-gradle-plugin")
                    id("com.google.gms.google-services")
}

android {
            namespace = "com.example.reward_app_flutter"
                compileSdk = flutter.compileSdkVersion
                    ndkVersion = flutter.ndkVersion

                        compileOptions {
                                        sourceCompatibility = JavaVersion.VERSION_17
                                                targetCompatibility = JavaVersion.VERSION_17
                        }

                            defaultConfig {
                                        applicationId = "com.example.reward_app_flutter"
                                                minSdk = 24
                                                        targetSdk = flutter.targetSdkVersion
                                                                versionCode = flutter.versionCode
                                                                        versionName = flutter.versionName
                                                                                multiDexEnabled = true
                            }

                                buildTypes {
                                                release {
                                                                    // R8 minification OFF - yeh WorkManager/WorkDatabase crash fix karta hai
                                                                                // (androidx.work ki reflection-based classes R8 se toot rahi thi).
                                                                                            isMinifyEnabled = false
                                                                                                        isShrinkResources = false

                                                                                                                    // Abhi debug signing use ho rahi hai taaki missing-keystore
                                                                                                                                // error na aaye aur APK reliably build ho.
                                                                                                                                            // Play Store release ke waqt apna khud ka upload keystore
                                                                                                                                                        // banakar yahan use karein.
                                                                                                                                                                    signingConfig = signingConfigs.getByName("debug")
                                                }
                                }

                                    kotlin {
                                                compilerOptions {
                                                                    jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                                                }
                                    }
}

// IMPORTANT: yeh block android{} ke BAHAR hona chahiye, andar nahi.
flutter {
            source = "../.."
}

                                                }
                        }
}