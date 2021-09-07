@Library('CommonUtils') _

import com.zevrant.services.GitHubReleaseRequest

BRANCH_NAME = BRANCH_NAME.tokenize("/")
BRANCH_NAME = BRANCH_NAME[BRANCH_NAME.size() - 1];
currentBuild.displayName = "$REPOSITORY merging to $BRANCH_NAME"
String version = ""
String variant = (BRANCH_NAME == "master") ? "release" : 'develop'
String avdName = "jenkins-android-test-$BUILD_ID"
String junitFileName = 'app/build/outputs/**/connected/TEST-*.xml'
pipeline {
    agent {
        label 'master'
    }
    stages {
        stage("Get Version") {
            steps {
                script {
                    def json = readJSON text: (sh(returnStdout: true, script: "aws ssm get-parameter --name ${repository}-VERSION"))
                    version = json['Parameter']['Value']
                }
            }
        }


        stage("SCM Checkout") {
            steps {
                script {
                    git credentialsId: 'jenkins-git', branch: BRANCH_NAME,
                            url: "git@github.com:zevrant/${REPOSITORY}.git"
                }
            }
        }

        stage("Unit Test") {
            steps {
                script {
//                    sh "bash gradlew clean testDevelopTest --no-daemon"
                    sh "echo skipping..."
                }
            }
        }

        stage("Integration Test Setup") {
            steps {
                script {
                    if (!fileExists('snapshot')) {
                        sh """
    aws s3 cp s3://zevrant-artifact-store/pixel4-snapshot.zip snapshot.zip  --endpoint-url https://s3-accelerate.amazonaws.com
    unzip snapshot.zip  -d snapshot
    folder=`ls snapshot`
    cp -r snapshot/\$folder/* snapshot
    rm snapshot.zip
    rm -r snapshot/\$folder/""".stripIndent()
                    }
                    String startEmulator = "/opt/android/android-sdk/emulator/emulator -sysdir /var/lib/jenkins/.android/avd/${avdName}.avd/ -avd $avdName -no-window -no-boot-anim -no-snapshot-save -snapshot snapshot/"
                    sh "echo no | /opt/android/android-sdk/cmdline-tools/5.0/bin/avdmanager create avd -n $avdName --abi google_apis_playstore/x86_64 --package \'system-images;android-30;google_apis_playstore;x86_64\'"
//                    sh "aws s3 cp s3://zevrant-artifact-store/userdata-qemu.img /var/lib/jenkins/.android/avd/${avdName}.avd/userdata.img  --endpoint-url https://s3-accelerate.amazonaws.com\n"
//                    sh "aws s3 cp s3://zevrant-artifact-store/userdata-qemu.img.qcow2 /var/lib/jenkins/.android/avd/${avdName}.avd/userdata.img  --endpoint-url https://s3-accelerate.amazonaws.com\n"
                    sh "rm -r /var/lib/jenkins/.android/avd/${avdName}.avd/ && cp -r /var/lib/jenkins/build-cache/avd-image/ /var/lib/jenkins/.android/avd/${avdName}.avd/"
                    sh "nohup $startEmulator > nohup.out &"
                    sh """
    set +x
    secretsInitializer=`aws secretsmanager get-secret-value --region us-east-1 --secret-id android-secrets-initializer | jq .SecretString`
    secretsInitializer=`echo \$secretsInitializer | cut -c 2-\$((\${#secretsInitializer}-1))`
    echo \$secretsInitializer | base64 --decode > app/src/androidTest/java/com/zevrant/services/zevrantandroidapp/secrets/SecretsInitializer.java
                    """
                    echo "waiting for emulator to come online"
                    String offline = "offline"
                    while (offline.contains("offline")) {
                        sh 'sleep 5'
                        offline = sh returnStdout: true, script: '/opt/android/android-sdk/platform-tools/adb devices'
                        echo offline
                    }
                    echo 'restarting adb to keep device from showing as unauthorized'
                    int status = sh 'set -e /opt/android/android-sdk/platform-tools/adb kill-server && /opt/android/android-sdk/platform-tools/adb start-server'
                    int i = 0;
                    while(status != 0 && i < 10) {
                        sleep 3
                        status = sh returnStatus: true, script: 'set -e /opt/android/android-sdk/platform-tools/adb kill-server && /opt/android/android-sdk/platform-tools/adb start-server'
                        println "status is " + status
                        i++
                    }
                    if(i == 10) {
                        echo "Failed to restart adb"
                        throw RuntimeException("Failed to restart ADB")
                    }
                }
            }
            post {
                failure {
                    script {
                        String pid = sh returnStdout: true, script: 'pgrep qemu-system-x86'
                        if (pid != "" && pid != null) {
                            echo "killing emulator with pid $pid"
                            sh "kill -9 $pid"
                            echo "deleting avd with name $avdName"
                            sh "/opt/android/android-sdk/cmdline-tools/5.0/bin/avdmanager delete avd -n $avdName"
                        }
                        archiveArtifacts artifacts: 'nohup.out', followSymlinks: false
                    }
                }
            }
        }

        stage("Integration Test") {
            steps {
                script {
                    sh 'bash gradlew clean connectedDevelopTest'
                }
            }
            post {
                always {
                    script {
                        if (fileExists(junitFileName)) {
                            junit junitFileName
                        }
                        String pid = sh returnStdout: true, script: 'pgrep qemu-system-x86'
                        if (pid != "" && pid != null) {
                            echo "killing emulator with pid $pid"
                            sh "kill -9 $pid"
                            echo "deleting avd with name $avdName"
                            sh "/opt/android/android-sdk/cmdline-tools/5.0/bin/avdmanager delete avd -n $avdName"
                        }
                        archiveArtifacts artifacts: 'nohup.out', followSymlinks: false
                    }
                }
            }
        }


        stage("Release Version Update") {
            when { expression { variant == 'release' } }
            steps {
                script {
                    def splitVersion = version.tokenize(".");
                    def majorVersion = splitVersion[0]
                    majorVersion = majorVersion.toInteger() + 1
                    def newVersion = "${majorVersion}.0.0";
                    sh "aws ssm put-parameter --name ${REPOSITORY}-VERSION --value $version --type String --overwrite"
                }
            }
        }

        stage("Development Version Update") {
            when { expression { variant != 'release' } }
            steps {
                script {
                    def splitVersion = version.tokenize(".");
                    def minorVersion = splitVersion[2]
                    minorVersion = minorVersion.toInteger() + 1
                    version = "${splitVersion[0]}.${splitVersion[1]}.${minorVersion}"
                    sh "aws ssm put-parameter --name ${REPOSITORY}-VERSION --value $version --type String --overwrite"
                }
            }
        }

        stage("Build Artifact") {
            steps {
                script {
                    def json = readJSON text: (sh(returnStdout: true, script: "aws secretsmanager get-secret-value --secret-id /android/signing/keystore"))
                    String keystore = json['SecretString']; writeFile file: './zevrant-services.txt', text: keystore
                    sh "base64 -d ./zevrant-services.txt > ./zevrant-services.p12"
                    json = readJSON text: (sh(returnStdout: true, script: "aws secretsmanager get-secret-value --secret-id /android/signing/password"))
                    String password = json['SecretString']
                    sh " SIGNING_KEYSTORE=\'${env.WORKSPACE}/zevrant-services.p12\' " + 'KEYSTORE_PASSWORD=\'' + password + "\' bash gradlew clean assemble${variant.capitalize()} --no-daemon"
                    //for some reason gradle isn't signing like it's suppost to so we do it manually
                    sh "keytool -v -importkeystore -srckeystore zevrant-services.p12 -srcstoretype PKCS12 -destkeystore zevrant-services.jks -deststoretype JKS -srcstorepass \'$password\' -deststorepass \'$password\' -noprompt"

                    sh "zipalign -p -f -v 4 app/build/outputs/apk/$variant/app-${variant}.apk zevrant-services-unsigned.apk"
                    sh "apksigner sign --ks zevrant-services.jks --in ./zevrant-services-unsigned.apk --out ./zevrant-services.apk --ks-pass \'pass:$password\'"
                    sh "apksigner verify -v zevrant-services.apk"
                }
            }
        }

        stage("Release") {
            when { expression { BRANCH_NAME == 'develop' || BRANCH_NAME == 'master' } }
            steps {
                script {
                    sh "aws s3 cp ./zevrant-services.apk s3://zevrant-apk-store/$variant/$version/zevrant-services.apk"
                }
            }
        }
    }

}
