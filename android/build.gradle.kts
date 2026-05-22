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

    // Override the Kotlin language/api version on every plugin subproject.
    // Why: the project uses Kotlin 2.2.20 (settings.gradle.kts), which
    // dropped support for `languageVersion = "1.6"`. Some Flutter plugins
    // (sentry_flutter 8.x → android/build.gradle:58) still hardcode that
    // older value, which fails the build with:
    //   "Language version 1.6 is no longer supported; please, use 1.8+."
    // Registered inside the first subprojects { } block so the hook lands
    // before the `evaluationDependsOn(":app")` block below triggers eager
    // evaluation. Safe to remove once every dependency declares
    // languageVersion >= 1.8.
    afterEvaluate {
        tasks
            .withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions {
                    languageVersion.set(
                        org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8,
                    )
                    apiVersion.set(
                        org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8,
                    )
                }
            }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
