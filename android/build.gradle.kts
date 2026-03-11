allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Configuração de diretório de build
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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

// --- CORREÇÃO DE NAMESPACE (VERSÃO SEGURA) ---
subprojects {
    // Em vez de afterEvaluate, aplicamos a lógica assim que o plugin Android é detectado
    plugins.withType<com.android.build.gradle.api.AndroidBasePlugin> {
        val android = extensions.findByType<com.android.build.gradle.BaseExtension>()
        android?.apply {
            if (namespace == null) {
                namespace = project.group.toString()
            }
        }
    }
}