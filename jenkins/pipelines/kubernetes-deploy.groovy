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
                        def yamlDocs = readYaml(text: deploymentText)
                        println yamlDocs
                        println yamlDocs.spec.replicas
                        int timeout = 90;
                        if(yamlDocs.spec != null && yamlDocs.spec.replicas != null) {
                            timeout = (yamlDocs.spec.replicas as int) * 90
                        }
                        sh "kubectl apply -n zevrant-home-services-$ENVIRONMENT -f ./deployment.yml"
                        sh "kubectl rollout status deployments $REPOSITORY-deployment -n zevrant-home-services-$ENVIRONMENT --timeout=${timeout}s"
                    }
                }
            }
        }
    }
}