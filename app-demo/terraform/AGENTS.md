# Agent Instructions: Terraform & LocalStack Environment

Welcome to the AWS LocalStack Terraform project. As an AI coding agent, please follow the guidelines established in this document to maintain consistency, reliability, and security within the repository.

## 1. Core Workflow & Environment

This project uses **Terraform** to provision AWS infrastructure. However, all AWS services are mapped to a local emulator, **LocalStack**, to allow local development without incurring AWS costs or requiring remote network access. 

- You must configure the AWS provider to point to LocalStack endpoints (`http://localhost:4566`).
- Use the `tflocal` wrapper CLI instead of standard `terraform` whenever possible to automatically inject LocalStack configurations. Standard `terraform` with overridden endpoints in `main.tf` is also valid and currently used in this project.
- Always review the `endpoints` block inside the AWS provider in `main.tf` to ensure new services are properly routed to localhost.

## 2. Build, Lint, and Test Commands

### Initialization and Validation
Before working on the codebase, ensure the providers and modules are properly initialized.
```bash
# Initialize the working directory (downloads providers)
terraform init

# Or, if tflocal is preferred in the current context
tflocal init

# Validate the configuration files for syntax and internal consistency
terraform validate
```

### Formatting and Linting
Formatting is strictly enforced via built-in Terraform tools. Do not commit unformatted code.
```bash
# Format all files recursively
terraform fmt -recursive

# Check formatting without modifying files (useful for CI or verification)
terraform fmt -check -recursive
```
If `tflint` is available in your environment, use it to enforce AWS provider best practices:
```bash
tflint --init
tflint
```

### Planning and Applying (Testing Infrastructure)
Testing Terraform primarily revolves around validating plans against the LocalStack environment.
```bash
# Generate and review an execution plan
terraform plan -out=tfplan
# or
tflocal plan -out=tfplan

# Apply the execution plan to LocalStack
terraform apply "tfplan"

# To quickly tear down the local test environment
terraform destroy -auto-approve
```

### Running a Single Test
If the repository adopts the native `terraform test` framework (Terraform 1.6+):
```bash
# Run all tests in the repository
terraform test

# Run a specific test file (useful for targeted validation)
terraform test -filter="tests/setup.tftest.hcl"
```
*Note: Because this is a LocalStack environment, ensure LocalStack is actively running (`localstack start -d`) before executing plans or integration tests.*

## 3. Code Style Guidelines

### 3.1. Formatting and Syntax
- **Indentation:** Use 2 spaces for indentation. Never use tabs.
- **Alignment:** Let `terraform fmt` handle the alignment of equal signs (`=`). Do not manually align blocks unless executing the format command.
- **Quotes:** Use double quotes (`"`) for strings. Single quotes are not valid HCL string delimiters.
- **Block Formatting:** Always put a blank line between resource blocks to improve readability.

### 3.2. Naming Conventions
- **Resource/Data Names:** Always use `snake_case` for resource names, data source names, variable names, and outputs.
  - Good: `aws_s3_bucket.app_data`
  - Bad: `aws_s3_bucket.AppData`, `aws_s3_bucket.app-data`
- **Avoid Redundancy:** Do not include the resource type in the resource name.
  - Good: `resource "aws_security_group" "web_server" {}`
  - Bad: `resource "aws_security_group" "web_server_sg" {}`
- **Variable Names:** Prefer descriptive variable names. Use `_id` or `_arn` suffixes where appropriate to clarify the data being passed.

### 3.3. Project Structure
The project separates concerns into multiple `.tf` files to avoid a bloated `main.tf`. Respect this separation:
- `main.tf`: Provider configuration, backend configuration, and required providers.
- `variables.tf`: Input variables.
- `outputs.tf`: Output values.
- `network.tf`: VPC, Subnets, Route Tables, IGW.
- `compute.tf`: EC2 instances, Auto Scaling Groups, ECS clusters.
- `storage.tf`: S3 buckets, RDS databases, DynamoDB.
- `security.tf`: IAM roles, policies, and Security Groups.
- `gateway.tf` / `identity.tf`: specific service resources like API Gateway or Cognito.

### 3.4. Variable Typing and Documentation
Always define the `type` and `description` for every variable.
```hcl
variable "environment_name" {
  description = "The name of the environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}
```
- Avoid using the `any` type unless absolutely necessary.
- Use complex types like `list(string)` or `map(string)` instead of generic objects when applicable.

### 3.5. Error Handling & Validation
Terraform allows preventative error handling through variable validation blocks. Use these to restrict inputs to valid formats.
```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  validation {
    condition     = can(regex("^t[23].(micro|small)$", var.instance_type))
    error_message = "Instance type must be a t2 or t3 micro/small."
  }
}
```

### 3.6. Lifecycle Rules
For critical resources, explicitly define lifecycle rules to prevent accidental deletion or to manage zero-downtime updates.
```hcl
resource "aws_instance" "app" {
  # ... configuration ...
  lifecycle {
    create_before_destroy = true
    # prevent_destroy = true (Use with caution!)
  }
}
```

### 3.7. Security and Secrets (LocalStack Context)
- **No Real Credentials:** This is a LocalStack project. The provider configuration in `main.tf` must use mock credentials (e.g., `access_key = "test"`, `secret_key = "test"`). 
- Never commit real AWS credentials (`AKIA...`) to this repository.
- Avoid committing `.tfstate` files. They should be ignored via `.gitignore`.
- Keep `skip_credentials_validation = true` and `skip_metadata_api_check = true` in the AWS provider block.

### 3.8. Documentation and Comments
- Use `#` for single-line comments.
- Use `/* ... */` for multi-line block comments.
- Comment the *why*, not the *what*. HCL is generally declarative and self-documenting.

## 4. Closing Notes for Agents
When modifying this repository:
1. Identify the domain of your change (network, compute, storage, etc.) and edit the appropriate `.tf` file.
2. Read `variables.tf` to see if a variable already exists.
3. Always verify changes using `terraform fmt` and `terraform validate`.
