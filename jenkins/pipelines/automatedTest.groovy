node {
    stage("SCM Checkout") {
        git credentialsId: 'jenkins-git', branch: "master",
                url: "git@github.com:zevrant/zevrant-automation-tests.git"
    }

    stage("test") {
        sh "./gradlew clean test aggregate -Denvironment=develop --continue"
    }
}
