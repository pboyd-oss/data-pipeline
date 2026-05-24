@Library('jenkins-library') _

microservicePipeline(
    test: {
        container('golang') {
            sh 'go test ./... -v'
        }
    }
)
