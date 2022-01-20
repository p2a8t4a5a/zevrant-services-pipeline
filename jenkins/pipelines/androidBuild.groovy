@Library('CommonUtils') _


import com.lesfurets.jenkins.unit.global.lib.Library
import com.zevrant.services.TaskLoader
import com.zevrant.services.pojo.Version

import com.zevrant.services.services.VersionTasks


BRANCH_NAME = BRANCH_NAME.tokenize("/")
BRANCH_NAME = BRANCH_NAME[BRANCH_NAME.size() - 1];
String REPOSITORY = scm.getUserRemoteConfigs()[0].getUrl().tokenize('/').last().split("\\.")[0]
currentBuild.displayName = "$REPOSITORY merging to $BRANCH_NAME"
Version version = null
String variant = (BRANCH_NAME == "master") ? "release" : 'develop'
String avdName = "jenkins-android-test-$BUILD_ID"
VersionTasks versionTasks = TaskLoader.load(binding, VersionTasks) as VersionTasks
byte[] b = new byte[2000];
Version versionCode = null;
boolean runTests = env.RUN_TESTS ? Boolean.parseBoolean(RUN_TESTS as String) : true
pipeline {
    agent {
        kubernetes {
            inheritFrom 'android'
        }
    }
    stages {

        stage("Unit Test") {
            when { expression { runTests } }
            steps {
                container('android-emulator') {
                    script {
                        sh "bash gradlew clean testDevelopTestUnitTest"
                    }
                }
            }
        }

        stage("Integration Test Setup") {
            when { expression { runTests } }
            environment {
                AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
                AWS_DEFAULT_REGION = "us-east-1"
            }
            steps {
                container('android-emulator') {
                    script {
                        String startEmulator = "emulator -avd $avdName -no-window -no-boot-anim -no-snapshot-save -no-snapshot-load"
                        sh "echo no | avdmanager create avd -n $avdName --package 'system-images;android-31;google_apis;x86_64'"
                        sh "nohup $startEmulator > nohup-${avdName}.out &"
                        sh script: "aws secretsmanager get-secret-value --region us-east-1 --secret-id android-secrets-initializer > secret.txt"
                        String secret = readJSON(file: 'secret.txt')["SecretString"]
                        sh 'rm secret.txt'
                        secret = secret.replaceAll("\\n", "")
                        writeFile(file: "secret.txt", text: secret)
                        writeFile(file: 'bashScript.sh', text: """
#!/bin/bash
cat secret.txt | base64 --decode > app/src/androidTest/java/com/zevrant/services/zevrantandroidapp/secrets/SecretsInitializer.java
""")
                        sh "bash bashScript.sh && rm secret.txt"
                        echo "waiting for emulator to come online"
                        String offline = "offline"
                        while (offline.contains("offline")) {
                            sh 'sleep 5'
                            offline = sh returnStdout: true, script: 'adb devices'
                            echo offline
                            if(!offline.contains("device") && !offline.contains('emulator')) {
                                throw new RuntimeException("Emulator did not start check nohup output")
                            }
                        }
                        echo 'restarting adb to keep device from showing as unauthorized'
                        int status = sh 'set -e adb kill-server && adb start-server'
                        int i = 0;
                        while (status != 0 && i < 10) {
                            sleep 3
                            status = sh returnStatus: true, script: 'set -e adb kill-server && adb start-server'
                            println "status is " + status
                            i++
                        }
                        if (i == 10) {
                            echo "Failed to restart adb"
                            throw RuntimeException("Failed to restart ADB")
                        }
                        offline = "offline"
                        while (offline.contains("offline")) {
                            sh 'sleep 5'
                            offline = sh returnStdout: true, script: 'adb devices'
                            echo offline
                        }
                    }
                }
            }
            post {
                failure {
                    container('android-emulator') {

                        script {
                            if (runTests) {
                                String pid = sh returnStdout: true, script: ' set -e pgrep qemu-system-x86'
                                if (pid != "" && pid != null) {
                                    echo "killing emulator with pid $pid"
                                    sh "kill -9 $pid"
                                    echo "deleting avd with name $avdName"
                                    sh "avdmanager delete avd -n $avdName"
                                }
                                archiveArtifacts artifacts: "nohup-${avdName}.out", followSymlinks: false
                            }
                        }
                    }
                }
            }
        }

        stage("Integration Test") {
            when { expression { runTests } }
            environment {
                AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
                AWS_DEFAULT_REGION = "us-east-1"
            }
            steps {
                container('android-emulator') {

                    script {
                        sh 'adb devices'
                        sh 'echo $ANDROID_HOME'
                        sh 'bash gradlew clean connectedDevelopTest'
                    }
                }
            }
            post {
                always {
                    container('android-emulator') {
                        script {

                            if (runTests) {
                                archiveArtifacts artifacts: "nohup-${avdName}.out", followSymlinks: false

                                if (fileExists("app/build/reports/androidTests/connected/index.html")) {
                                    publishHTML(target: [
                                            allowMissing         : false,
                                            alwaysLinkToLastBuild: false,
                                            keepAll              : true,
                                            reportDir            : 'app/build/reports/androidTests/connected/',
                                            reportFiles          : "**/*",
                                            reportName           : 'JUnit Test Report',
                                            reportTitles         : 'JUnit Test Report'
                                    ]
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        stage("Get Version") {
            environment {
                AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
                AWS_DEFAULT_REGION = "us-east-1"
            }
            steps {
                container('android-emulator') {
                    script {
                        version = versionTasks.getVersion(REPOSITORY as String)
                        versionCode = versionTasks.getVersionCode("${REPOSITORY.toLowerCase()}")
                        currentBuild.displayName = "Building version ${version.toVersionCodeString()}, version code ${versionCode.toVersionCodeString()}"
                    }
                }
            }
        }
        stage("Version Update") {
            environment {
                AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
                AWS_DEFAULT_REGION = "us-east-1"
            }
            steps {
                container('android-emulator') {
                    script {
                        versionTasks.incrementVersion(REPOSITORY as String, version)
                        versionTasks.incrementVersionCode(REPOSITORY as String, versionCode)
                    }
                }
            }
        }

        stage("Build Artifact") {
            environment {
                AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
                AWS_DEFAULT_REGION = "us-east-1"
            }
            steps {
                container('android-emulator') {
                    script {
                        def json = readJSON text: (sh(returnStdout: true, script: "aws secretsmanager get-secret-value --secret-id /android/signing/keystore")) as String
                        String keystore = json['SecretString'];
                        writeFile file: './zevrant-services.txt', text: keystore
                        sh "base64 -d ./zevrant-services.txt > ./zevrant-services.p12"
                        json = readJSON text: (sh(returnStdout: true, script: "aws secretsmanager get-secret-value --secret-id /android/signing/password")) as String
                        String password = json['SecretString']

                        sh "bash gradlew clean bundle${variant.capitalize()} -PprojVersion='${version.toVersionCodeString()}' -PversionCode='${versionCode.toVersionCodeString()}'"
                        //for some reason gradle isn't signing like it's supposed to so we do it manually

                        sh "jarsigner -verbose -sigalg SHA512withRSA -digestalg SHA-512 -keystore zevrant-services.p12 app/build/outputs/bundle/$variant/app-${variant}.aab -storepass \'$password\' key0"
                        sh "jarsigner -verify -verbose app/build/outputs/bundle/$variant/app-${variant}.aab zevrant-services-unsigned.aab"
                        sh 'mv app/build/outputs/bundle/release/app-release.aab app-release.aab'
                        archiveArtifacts(artifacts: "app-release.aab")
                    }
                }
            }
        }
        stage("Trigger Internal Testing Release") {
            steps {
                script {
                    String[] repositorySplit = REPOSITORY.split("-")
                    build(
                            job: "Android/${repositorySplit[0].capitalize()} ${repositorySplit[1].capitalize()} ${repositorySplit[2].capitalize()}/${repositorySplit[0].capitalize()}-${repositorySplit[1].capitalize()}-${repositorySplit[2].capitalize()}-Release-To-Internal-Testing" as String, parameters: [
                    ],
                            wait: false
                    )
                }
            }
        }

    }
}
