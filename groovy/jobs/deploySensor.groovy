import groovy.json.JsonSlurper


node {
    currentBuild.displayName = "Deploying $REPOSITORY version $VERSION"

    withCredentials([sshUserPrivateKey(credentialsId: 'jenkins-git', keyFileVariable: 'key', passphraseVariable: 'password', usernameVariable: 'username')]) {
        // some block

        String[] sensorLocations = ["192.168.1.20"];
        String baseSSHCommand = "ssh -i $key zevrant-sensor-service@" as String;
        for (String sensorLocation : sensorLocations) {
            stage("Download Artifact") {
                sh "${baseSSHCommand}${sensorLocation} 'aws s3 cp s3://zevrant-artifact-store/com/zevrant/services/${REPOSITORY}/${version}/${REPOSITORY}-${version}.jar .'"
                sh "${baseSSHCommand}${sensorLocation} 'ln -sf ${REPOSITORY}-${version}.jar ${REPOSITORY}.jar"
            }

            stage("Start Service") {
                sh "${baseSSHCommand}${sensorLocation} 'sudo systemctl restart zevrant-sensor-service"
                for (def int i = 0; i < 10; i++) {
                    try {
                        def response = sh returnStdout: true, script: "curl https://${sensorLocation}:9006/zevrant-sensor-service/actuator/health"

                        def jsonString = sh returnStdout: true, script: "aws ssm get-parameter --name ${REPOSITORY}-VERSION";
                        JsonSlurper slurper = new JsonSlurper();
                        Map parsedJson = slurper.parseText(jsonString);
                        def status = parsedJson.get("status");
                        if(status.equals("UP")) {
                            break;
                        }
                    } catch (Exception ex) {
                        Thread.sleep(5000)
                    }
                }
            }
        }

    }
}