# Spring Boot → Amazon ECR via GitHub Actions OIDC

## Repository structure

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline
├── iam/
│   ├── trust-policy.json       # IAM role trust policy (GitHub OIDC)
│   └── permissions-policy.json # IAM role permissions (least privilege)
├── src/                        # Spring Boot application source
├── pom.xml                     # Maven build config
├── Dockerfile                  # Multi-stage Docker build
└── .dockerignore
```

## AWS setup (one-time, before first push)

### 1. Create the ECR repository

```bash
aws ecr create-repository \
  --repository-name spring-app \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true
```

### 2. Add GitHub as an OIDC identity provider in IAM

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

> Skip this step if the provider already exists in your account.

### 3. Create the IAM role

Replace placeholders in `iam/trust-policy.json` first:
- `YOUR_ACCOUNT_ID` → your 12-digit AWS account ID
- `YOUR_GITHUB_USERNAME` → your GitHub username or org
- `YOUR_REPO_NAME` → this repository name

```bash
aws iam create-role \
  --role-name github-ecr-push-role \
  --assume-role-policy-document file://iam/trust-policy.json
```

### 4. Attach the permissions policy

Replace `YOUR_ACCOUNT_ID` in `iam/permissions-policy.json`, then:

```bash
aws iam put-role-policy \
  --role-name github-ecr-push-role \
  --policy-name ECRPushPolicy \
  --policy-document file://iam/permissions-policy.json
```

### 5. Update the workflow file

In `.github/workflows/deploy.yml`, replace:
- `YOUR_ACCOUNT_ID` → your 12-digit AWS account ID

### 6. Push to main

```bash
git add .
git commit -m "Initial commit"
git push origin main
```

The GitHub Actions workflow will trigger automatically and push the image to ECR.

## Image tag

The image is tagged as: `shema alphonse_spring-app`

## Security design

- No AWS credentials stored in GitHub Secrets
- GitHub Actions authenticates via OIDC — short-lived JWT tokens only
- IAM role scoped to one specific GitHub repository and branch
- IAM permissions scoped to one specific ECR repository
- Container runs as non-root user (`appuser`)
- Multi-stage Docker build — no build tools in final image
