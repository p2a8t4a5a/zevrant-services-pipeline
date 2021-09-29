package com.zevrant.services.pojo

import java.util.regex.Pattern

class Version {

    private static final List<Pattern> acceptedPatterns = [
            Pattern.compile("\\d*\\.\\d*\\.\\d*")
    ]

    private int minor;
    private int median;
    private int major;

    Version(String version) {
        boolean patternMatches = false;
        for (Pattern pattern : acceptedPatterns) {
            patternMatches = patternMatches || pattern.matcher(version)
        }
        if (!patternMatches) {
            throw new RuntimeException("The supplied version doesnot match any of the supplied patterns");
        }
        String[] versionPieces = version.tokenize(".")
        minor = Integer.valueOf(versionPieces[0])
        median = Integer.valueOf(versionPieces[1])
        major = Integer.valueOf(versionPieces[2])
    }

    String toThreeStageVersionString() {
        return "${major}.${median}.${minor}"
    }

    int getMinor() {
        return minor
    }

    void setMinor(int minor) {
        this.minor = minor
    }

    int getMedian() {
        return median
    }

    void setMedian(int median) {
        this.median = median
    }

    int getMajor() {
        return major
    }

    void setMajor(int major) {
        this.major = major
    }
}