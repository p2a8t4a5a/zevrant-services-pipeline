package com.zevrant.services

class PipelineCollection {

    static Pipeline[] pipelines = new Pipeline[]{
            new Pipeline(
                    "spring-kubernetes-build-job",
                    "Pipeline in charge of building microservices intended for deployment onto the kubernetes cluster",
                    new PipelineParameter[]{
                        DefaultPipelineParameters.BRANCH_PARAMETER,
                        DefaultPipelineParameters.REPOSITORY_PARAMETER
                    },
                    "git@github.com:Zevrant/zevrant-services-pipeline.git",
                    "jenkins/pipelines/build.groovy",
                    "jenkins-git"
            ),
            new Pipeline(
                    "android-build-job",
                    "Pipeline to build android apps",
                    new PipelineParameter[] {
                        DefaultPipelineParameters.BRANCH_PARAMETER,
                        DefaultPipelineParameters.REPOSITORY_PARAMETER
                    },
                    "git@github.com:Zevrant/zevrant-services-pipeline.git",
                    "jenkins/pipelines/build.groovy",
                    "jenkins-git"
            )
    }
}