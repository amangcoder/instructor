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

// Kotlin 2.x dropped support for languageVersion < 1.7. Force all plugin
// subprojects (e.g. sentry_flutter) that declare an older version to use 1.9.
subprojects {
    plugins.withType<org.jetbrains.kotlin.gradle.plugin.KotlinBasePlugin> {
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class).configureEach {
            compilerOptions {
                languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
