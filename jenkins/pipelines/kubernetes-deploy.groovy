pipeline {
    agent {
        kubernetes {
            inheritFrom 'kubernetes'
        }
    }
    stages {
        stage("SCM Checkout") {
            steps {
                container('kubectl') {
                    script {
                        currentBuild.displayName = "Deploying Version $VERSION"
                        git credentialsId: 'jenkins-git', branch: 'master',
                                url: "git@github.com:zevrant/${REPOSITORY}.git" as String
                    }
                }
            }
        }
        stage("Deploy Database") {
            when { expression { fileExists('database.yml') } }
            environment {
                KUBECONFIG = credentials('jenkins-kubernetes')
            }
            steps {
                container('kubectl') {
                    script {
                        sh "sed -i 's/\$ENVIRONMENT/$ENVIRONMENT/g' ./database.yml"
                        withCredentials([file(credentialsId: 'jenkins-kubernetes', variable: 'kubeconfig')]) {
                            sh "kubectl apply -n zevrant-home-services-$ENVIRONMENT -f ./database.yml"
                            sh "kubectl rollout status deployments $REPOSITORY-db-deployment -n zevrant-home-services-$ENVIRONMENT --timeout=5m"
                        }
                    }
                }
            }
        }

        stage("Deploy") {
            when { expression { fileExists('deployment.yml') } }
            environment {
                KUBECONFIG = credentials('jenkins-kubernetes')
            }
            steps {
                container('kubectl') {
                    script {
                        sh "sed -i 's/\$ENVIRONMENT/$ENVIRONMENT/g' ./deployment.yml"
                        sh "sed -i 's/\$VERSION/$VERSION/g' ./deployment.yml"
                        String deploymentText = ((String) readFile(file: 'deployment.yml'))
                        println(deploymentText)
                        Map<String, Object> yamlDocs = readYaml(text: deploymentText)
                        println yamlDocs.keySet().toString()
                        int timeout = 90;
                        if(yamlDocs.size() > 1) {
                            timeout = yamlDocs[yamlDocs.size() - 1].spec.replicas
                        } else {
                            timeout = yamlDocs.spec.replicas * 90
                        }
                        sh "kubectl apply -n zevrant-home-services-$ENVIRONMENT -f ./deployment.yml"
                        sh "kubectl rollout status deployments $REPOSITORY-deployment -n zevrant-home-services-$ENVIRONMENT --timeout=${timeout}s"
                    }
                }
            }
        }
    }
}