import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

// ! Align Kotlin jvmTarget with each subproject's Java targetCompatibility so
//   plugins still targeting Java 1.8 (e.g. flutter_facebook_auth) do not fail
//   under JDK 21 + Kotlin 2.2 ("Inconsistent JVM-target compatibility").
subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        val javaTarget = tasks.withType<JavaCompile>().firstOrNull()?.targetCompatibility
        val targetVersion = when (javaTarget) {
            "1.8", "8" -> JvmTarget.JVM_1_8
            "11" -> JvmTarget.JVM_11
            "17" -> JvmTarget.JVM_17
            "21" -> JvmTarget.JVM_21
            else -> JvmTarget.JVM_17
        }
        compilerOptions {
            jvmTarget.set(targetVersion)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
