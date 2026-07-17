allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")

    val configureSubproject = {
        // Workaround for plugins missing the namespace property
        project.extensions.findByName("android")?.let { android ->
            try {
                val namespaceProperty = android.javaClass.getMethod("getNamespace").invoke(android) as? String
                if (namespaceProperty == null) {
                    android.javaClass.getMethod("setNamespace", String::class.java).invoke(android, project.group.toString())
                }
            } catch (e: Exception) {
                // Ignore, as it might not be a LibraryExtension or method doesn't exist
            }

            // Workaround for legacy plugins with compileSdkVersion < 30
            try {
                android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(android, 34)
            } catch (e: Exception) {
                try {
                    android.javaClass.getMethod("compileSdkVersion", String::class.java).invoke(android, "android-34")
                } catch (e2: Exception) {
                    // Ignore
                }
            }

            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                val javaVersion17 = JavaVersion.VERSION_17
                compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java).invoke(compileOptions, javaVersion17)
                compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java).invoke(compileOptions, javaVersion17)
            } catch (e: Exception) {
                // Ignore
            }
        }

        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    if (project.state.executed) {
        configureSubproject()
    } else {
        afterEvaluate {
            configureSubproject()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
