allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    if (project.name == "tflite_flutter") {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
                finalizeDsl { extension ->
                    extension.compileSdk = 36
                }
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
            }
        }
    }
}

allprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (
                requested.group == "org.tensorflow" &&
                requested.name in setOf(
                    "tensorflow-lite",
                    "tensorflow-lite-api",
                    "tensorflow-lite-gpu",
                    "tensorflow-lite-gpu-api"
                )
            ) {
                useVersion("2.16.1")
            }
        }
    }
}