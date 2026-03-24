allprojects {
    // Add local Maven repository FIRST so cached artifacts are found before
    // trying to resolve from dl.google.com (which may be unreachable).
    // This covers buildscript classpath resolution for sub-projects like
    // permission_handler_android that declare their own buildscript block.
    buildscript {
        repositories {
            maven { url = uri("${rootDir}/local-repo") }
        }
    }
    repositories {
        maven { url = uri("${rootDir}/local-repo") }
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
