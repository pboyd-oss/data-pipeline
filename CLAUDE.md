# CLAUDE.md

## Purpose

A demo team microservice (team-b) that combines a Go HTTP worker process with Terraform-managed AWS infrastructure. The Go binary is a lightweight job processor that listens on `:8080/healthz`; the Terraform code provisions an S3 input bucket (with versioning, AES-256 SSE, and public-access block) and an SQS queue wired to receive S3 `ObjectCreated` notifications for `.json` files. It exercises the platform's full build-integrity and release pipeline, including multi-environment infrastructure promotion.

## Stack

- Language: Go 1.22 (stdlib only)
- Infrastructure: Terraform with the AWS provider (~5.x), S3 + SQS resources
- Container base: `harbor.tuxgrid.com/docker.io/alpine:3.20` (runtime, runs as non-root `app` user), `golang:1.22-alpine` (build)
- Skaffold for image build orchestration (kaniko in-cluster, pushes to `harbor.tuxgrid.com/team-b/data-pipeline`)
- Terraform state stored in S3 bucket `tuxgrid-terraform-state` (eu-west-1), key injected at plan time

## Structure

- `src/main.go` - Go entry point, single `/healthz` handler, listens on `:8080`
- `main.tf` - Terraform: AWS provider, S3 bucket (input), SQS queue (jobs), S3-to-SQS notification
- `variables.tf` - `env` (required) and `aws_region` (default `eu-west-1`)
- `outputs.tf` - Terraform outputs
- `environments/staging.tfvars`, `environments/production-us.tfvars` - per-environment variable files
- `Dockerfile` - two-stage build with a non-root runtime user
- `skaffold.yaml` - kaniko build config targeting Harbor
- `Jenkinsfile` - `microservicePipeline` with an explicit `test:` hook running `go test ./... -v` in a golang container
- `Jenkinsfile.release` - delegates to `platform/team-b/release` Jenkins job, passing `UPSTREAM_JOB`, `UPSTREAM_BUILD`, and `ENVIRONMENT` parameters
- `.gitignore` - excludes Terraform state and `.terraform/` directories
- `go.mod` - module declaration

## How it fits in the platform

data-pipeline is team-b's representative workload. Its `Jenkinsfile` uses `microservicePipeline` with a custom `test:` closure (a scripted hook that runs inside the library's declarative scaffolding), demonstrating the team-code runtime-tracing capability of the platform audit service. `Jenkinsfile.release` shows the multi-environment promotion pattern - it calls the platform release job which checks attestations via Cedar before applying Terraform and pushing to a target environment. The infra (S3 + SQS) models a real data-ingestion pipeline triggered by object uploads.

## Build and deploy

1. Jenkins (via `jenkins-library::microservicePipeline`) builds and pushes the container image to Harbor using kaniko, signs with cosign, and attests SLSA provenance.
2. `Jenkinsfile.release` triggers `platform/team-b/release` with the target environment (`staging` or `production-us`) and build reference. The release job validates attestations via the platform attest-coordinator and Cedar before promoting.
3. Terraform is applied by the platform release pipeline, using `-backend-config="key=team-b/<env>/terraform.tfstate"` with environment-specific `.tfvars`.
4. The container image is deployed to Kubernetes (namespace `team-b`) via skaffold apply.