plugins {
        id("com.android.application")
            id("dev.flutter.flutter-gradle-plugin")
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
                                                            versionCode = flutter.versionCode.ToInt()
                                                                    versionName = flutter.versionName
                                                                            multiDexEnabled = true
                        }

                            signingConfigs {
                                        create("release") {
                                                        storeFile = file("debug.keystore")
                                                                    storePassword = "android"
                                                                                keyAlias = "androiddebugkey"
                                                                                            keyPassword = "android"
                                        }
                            }

                                buildTypes {
                                            release {
                                                            signingConfig = signingConfigs.getByName("release")
                                            }
                                }

                                    kotlin {
                                                compilerOptions {
                                                                jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                                                }
                                    }

                                        flutter {
                                                    source = "../.."
                                        }
}
                                        }
                    }
}