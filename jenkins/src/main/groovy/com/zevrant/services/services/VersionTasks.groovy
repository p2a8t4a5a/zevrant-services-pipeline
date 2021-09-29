package com.zevrant.services.services

import com.zevrant.services.pojo.Version
import groovy.json.JsonSlurper

public Version getVersion(String applicationName) {
    Object parametersResponse = new JsonSlurper().parseText(sh(returnStdout: true, script: 'aws ssm describe-parameters') as String);
    boolean containsParameter = false;
    for (Object parameter : parametersResponse.Parameters) {
        containsParameter = containsParameter || parameter.Name.contains("${applicationName}-VERSION")
    }
    String version = ""
    if (containsParameter) {
        version = sh(returnStdout: true, script: "aws ssm get-parameter ${applicationName}-VERSION")
    } else {
        version = "0.0.0"
    }
    return new Version(version)
}

Version majorVersionUpdate(String appName, Version currentVersion) {
    currentVersion.setMajor(currentVersion.getMajor() + 1)
    currentVersion.setMedian(0);
    currentVersion.setMinor(0)

    sh "aws ssm put-parameter --name ${appName}-VERSION --value ${currentVersion.toThreeStageVersionString()} --type String --overwrite"
    return currentVersion
}

Version medianVersionUpdate(String appName, Version currentVersion) {
    currentVersion.setMedian(currentVersion.getMedian() + 1);
    currentVersion.setMinor(0)

    sh "aws ssm put-parameter --name ${appName}-VERSION --value ${currentVersion.toThreeStageVersionString()} --type String --overwrite"
    return currentVersion
}

Version minorVersionUpdate(String appName, Version currentVersion) {
    currentVersion.setMinor(currentVersion.getMinor() + 1)

    sh "aws ssm put-parameter --name ${appName}-VERSION --value ${currentVersion.toThreeStageVersionString()} --type String --overwrite"
    return currentVersion
}