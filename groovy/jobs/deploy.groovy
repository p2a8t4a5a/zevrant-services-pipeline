
node {

    stage("SCM Checkout") {
        git credentialsId: 'jenkins-git',
                url: "git@github.com:zevrant/${REPOSITORY}.git"
    }

    stage("Deploy Database") {
        sh "set +e; kubectl apply -n zevrant-home-services-$ENVIRONMENT -f ./database.yml; set -e; kubectl rollout status deployment.v1.apps/$REPOSITORY-db-deployment"
    }

    stage("Deploy") {
        sh "VERSION=$VERSION envsubst < deployment.yml | ENVIRONMENT=$ENVIRONMENT envsubst | kubectl apply -n zevrant-home-services-$ENVIRONMENT -f -"
        sh "kubectl rollout status deployment.v1.apps/$REPOSITORY-deployment"
    }
}