plugins {
    id("com.google.gms.google-services") version "4.4.1" apply false
}

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

subprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("2.1.10")
            }
        }
    }
}

subprojects {
    if (project.name == "telephony") {
        val fixNamespace = Action<Project> {
            if (project.hasProperty("android")) {
                val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
                if (android.namespace == null) {
                    android.namespace = "com.shounakmulay.telephony"
                }
            }
        }
        if (project.state.executed) {
            fixNamespace.execute(project)
        } else {
            project.afterEvaluate(fixNamespace)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
