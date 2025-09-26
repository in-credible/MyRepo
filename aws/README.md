AWS Scripts Toolkit

Overview
- Curated Bash scripts to manage AWS resources quickly from this repo.
- Uses repo-local AWS CLI config via `aws/aws-login.sh` so profiles and regions are consistent.

Setup
- Requirements: AWS CLI v2, jq, bash; docker (for ECR login), zip (for Lambda zips).
- Configure local credentials and config:
  - Edit `aws/credentials` and `aws/config` with your profiles.
  - Source the helper to point the CLI at these files: `source aws/aws-login.sh <profile> [region]`.
  - Verify: `aws sts get-caller-identity`.

Interactive Launcher
- Run `./aws/new.sh` to select a category and script.
- It asks for a default profile/region and passes them to the chosen script.

Directory Structure
- `aws/identity`: Role/MFA sessions and IAM helpers
  - `assume-role.sh`, `mfa-session.sh`, `iam-role-lambda.sh`, `access-key-rotate.sh`
- `aws/networking`: VPC, security groups, load balancers
  - `vpc-create.sh`, `sg-create-web.sh`, `alb-create.sh`
- `aws/compute`: Lambda helpers
  - `lambda-deploy-zip.sh`
- `aws/containers`: ECR/ECS helpers
  - `ecr-repo-create.sh`, `ecs-fargate-service.sh`
- `aws/storage`: S3 bucket creators and policies
  - `s3-create-*.sh`, `s3-website-policy.sh`, `s3-lifecycle-archive.sh`, `s3-lib.sh`
- `aws/observability`: CloudTrail and CloudWatch alarms
  - `cloudtrail.sh`, `cloudtrail-create-org.sh`, `cloudwatch-alarms-basic.sh`
- `aws/security`: Security services
  - `guardduty-enable.sh`
- `aws/data`: Athena and Glue
  - `athena-setup.sh`, `glue-crawler-create.sh`
- `aws/cdn`: CloudFront helpers
  - `cloudfront-oac-s3.sh`
- `aws/ops`: Cost, backup, and operations
  - `cost-explorer-report.sh`, `backup-plan-basic.sh`

Common Usage
- Point CLI at repo-local config (one-time per shell):
  - `source aws/aws-login.sh myprofile us-east-1`
- Use the launcher:
  - `./aws/new.sh` → choose a script and follow prompts.
- Run a script directly (examples):
  - Create versioned S3 bucket: `./aws/storage/s3-create-versioned.sh -p myprofile -r us-east-1 my-unique-bucket`
  - Deploy Lambda from ZIP: `./aws/compute/lambda-deploy-zip.sh -p myprofile -r us-east-1 --name fn --runtime python3.11 --handler app.handler --zip build.zip --role-arn arn:aws:iam::123:role/lambda`
  - Create VPC: `./aws/networking/vpc-create.sh -p myprofile -r us-east-1 --cidr 10.0.0.0/16 --name my-vpc`

SSO (IAM Identity Center)
- Add an SSO profile in `aws/config` (e.g., `sso_session`, `sso_account_id`, `sso_role_name`).
- `source aws/aws-login.sh <sso-profile> us-east-1` then `aws sso login --profile <sso-profile>`.

Notes & Conventions
- Scripts prompt interactively for missing required inputs; `-p/--profile` and `-r/--region` skip prompts.
- S3 create scripts handle `us-east-1` LocationConstraint rules and wait for bucket creation.
- Policies that open public access are opt-in and confirm before changes.
- Many scripts output resource IDs/ARNs for quick copy-paste.

Troubleshooting
- Missing `jq`: install with Homebrew `brew install jq` or your package manager.
- Permission errors: ensure your profile/role has required IAM permissions for the action.
- Region mismatches: pass `-r <region>` or set in `aws/config` for the selected profile.

