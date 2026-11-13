# 3rd-tier-custom-infra

ECS Fargate stack with separate frontend and API services behind one ALB.

- `/api/*` -> API service
- everything else -> frontend service

Images are pulled from public Docker Hub repositories (`frontend_image`, `api_image` in
`terraform.tfvars`, e.g. `slyytata/realmile-web:latest`). The app repo's CD pushes new
images there and deploys them by commit-SHA tag. Note: anonymous Docker Hub pulls are
rate-limited per IP (all tasks share the NAT gateway's IP).

State: `s3://slyy-tata-bck-remote/three-tier-ecs-fargate/terraform.tfstate`

## Layout

| File | Contents |
|---|---|
| `provider.tf` | Terraform/provider versions, S3 backend |
| `variables.tf` | Input variables |
| `network.tf` | VPC, subnets, IGW, NAT, route tables |
| `security_groups.tf` | ALB, frontend and API security groups |
| `alb.tf` | ALB, target groups, listeners, `/api` routing rule |
| `iam.tf` | ECS task execution role (+ SSM read), app CD deploy role (OIDC) |
| `ecs.tf` | ECS cluster, task definitions, services |
| `outputs.tf` | Outputs |

Create a `terraform.tfvars` (git-ignored) with values for the variables in `variables.tf`.

## Security

### Security tests in the pipeline
Every pull request and push to `main` runs a **Security scan** job first, with no AWS
credentials. `terraform plan` / `apply` only run if every check passes.

| Check | Tool | Catches |
|-------|------|---------|
| Secrets in git history | Gitleaks | Committed passwords, access keys, tokens |
| Terraform misconfiguration | Checkov | Open security groups, admin IAM policies, public resources, missing encryption |
| Terraform misconfiguration (HIGH/CRITICAL) | Trivy | Second rule set for the same class of problems |
| Pipeline security | zizmor | Unpinned actions, credential leaks, script injection in workflows |

Run the same checks locally before pushing:
```bash
docker run --rm -v "$PWD":/repo zricethezav/gitleaks:v8.30.1 git /repo --redact --no-banner
docker run --rm -v "$PWD":/tf bridgecrew/checkov:3.4.5 --directory /tf --framework terraform --skip-path .terraform --compact --quiet
docker run --rm -v "$PWD":/tf aquasec/trivy:0.76.2 config --skip-dirs /tf/.terraform --severity HIGH,CRITICAL --exit-code 1 /tf
docker run --rm -v "$PWD":/repo ghcr.io/zizmorcore/zizmor:1.32.0 --offline /repo/.github/workflows
```

### Hardening in place
- Security groups allow only the traffic the app needs: internet to the ALB on 80/443,
  ALB to the containers on their ports, containers out on 443 (AWS services) and the API
  out on 5432 (Neon). Every rule has a description.
- The VPC's default security group has all rules removed.
- Workflow actions are pinned to full commit SHAs, and checkout does not keep the token.

### Accepted findings
These are skipped inline in the `.tf` files (`#checkov:skip=` / `#trivy:ignore:`), each
with its reason. Anything new that is not on this list fails the pipeline.

| Finding | Why it is accepted |
|---------|--------------------|
| ALB is internet-facing, port 80 open | It is the public website; port 80 only redirects to HTTPS |
| ALB to container traffic is HTTP | TLS ends at the ALB; that traffic stays inside the private VPC |
| Egress to `0.0.0.0/0` on 443 / 5432 | AWS endpoints and Neon have no fixed IPs; ports are restricted |
| No logging (container logs, VPC flow logs, ALB access logs) | Intentionally disabled for now; see note below |
| No ALB deletion protection | It would block the routine `terraform destroy` of this stack |

### Future upgrades (deferred for cost)
- AWS WAF in front of the ALB (~$5+/month)
- VPC endpoint for SSM, so secret lookups no longer go through the NAT
- Logging, when needed again: CloudWatch log groups + `logConfiguration` on the ECS containers,
  VPC flow logs and ALB access logs

> **Note:** there are no container logs. If a deploy fails (e.g. the `migrate` container
> exits with an error), ECS only shows the exit code and stopped reason
> (`aws ecs describe-tasks`), not the error message.
