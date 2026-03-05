# Agent Guide for Terraform Infrastructure Code

Welcome to the infrastructure-as-code repository. As an autonomous or assistive agent operating in this codebase, you must strictly adhere to the guidelines, commands, and conventions outlined in this document. Our goal is to maintain a high-quality, readable, and robust Terraform codebase designed for testing against LocalStack.

## 1. Project Context and Tooling

### LocalStack Environment
This repository is configured to deploy AWS infrastructure locally via **LocalStack**. 
- The AWS provider is configured in `main.tf` to bypass real AWS validation.
- All provider endpoints are mapped to `http://localhost:4566`.
- Dummy credentials (`test` / `test`) and a default region (`us-east-1`) are heavily enforced in `main.tf`.
- **Never** introduce real AWS credentials or change the provider configuration to point to production endpoints unless explicitly instructed.

### Core Commands

You will use standard Terraform CLI commands for building, validating, and testing the configuration.

#### Formatting and Linting
Always ensure code is formatted before presenting it to the user or making a commit.
- **Format code**: `terraform fmt` (Always run this after modifying `.tf` files)
- **Check formatting without modifying**: `terraform fmt -check`
- **Validate syntax and arguments**: `terraform validate`
- **Linting**: If `tflint` is installed, run `tflint` to catch provider-specific errors and enforce best practices.

#### Testing / Planning
Because there is no separate testing framework (like Terratest) configured by default, "testing" is done via validation and planning against the LocalStack instance.
- **Initialize**: `terraform init` (Downloads providers. Do this before validation/planning).
- **Plan**: `terraform plan` (Use this as your primary "test" to ensure resources compile and dependency graphs resolve correctly).
- **Run a single test (target resource)**: If the user asks to test a specific resource modification without planning everything, use targeting:
  `terraform plan -target=aws_s3_bucket.my_bucket`
- **Apply (if requested)**: `terraform apply -auto-approve` (Ensure LocalStack is running first).

## 2. Code Style Guidelines

### File Structure & Organization
- Keep resources grouped logically by domain or AWS service (e.g., `network.tf` for VPC/Subnets, `compute.tf` for EC2/ECS/Lambda, `security.tf` for WAF/KMS).
- Do not dump all resources into `main.tf`. `main.tf` is strictly for provider definitions and global configurations.
- Store input variables in `variables.tf` and outputs in `outputs.tf` (if applicable).

### Imports and Providers
- Hard-pin major versions of the AWS provider (e.g., `~> 5.0`).
- Use the `hashicorp/aws` source consistently.
- Do not define multiple providers unless dealing with multi-region setups (which is currently unsupported in this basic LocalStack setup).

### Formatting
- Strictly rely on `terraform fmt` for indentation, alignment of equals signs (`=`), and spacing. 
- Do not manually pad or format code block alignments; `terraform fmt` is the singular source of truth.
- Use empty lines to separate distinct resource blocks, data blocks, and variable definitions.

### Naming Conventions
- **Resource Names**: Use `snake_case` for all resource and data block names (e.g., `resource "aws_vpc" "main_network"`).
- **Variable Names**: Use `snake_case` for variable names. Prefix variables related to specific components if it helps clarity (e.g., `db_port`, `vpc_cidr_block`).
- **Descriptive Naming**: Choose names that describe the resource's role, not its AWS type. (Good: `aws_security_group.web_tier`, Bad: `aws_security_group.sg1`).
- **Tagging**: Every resource that supports tags MUST include standard tags. Often, a `Name` tag should match or resemble the Terraform resource name.

### Types and Variables
- **Strong Typing**: All variables in `variables.tf` MUST have a `type` defined (e.g., `type = string`, `type = list(string)`, `type = map(any)`).
- **Descriptions**: All variables MUST have a `description` attribute explaining what it does.
- **Defaults**: Provide `default` values for optional variables to keep the module easy to consume.
- **Validation**: Use variable `validation {}` blocks for complex inputs (e.g., ensuring a CIDR block matches a regex pattern) to catch errors early.

### Error Handling & Resiliency
Terraform is declarative, so error handling is about state resiliency and preventing failures during `apply`:
- **Dependencies**: Rely on implicit dependencies whenever possible (e.g., referencing `aws_vpc.main.id` automatically creates a dependency). Only use `depends_on = [...]` when implicit dependencies cannot be inferred (e.g., IAM role policies attaching before a Lambda function tries to use them).
- **Lifecycle**: Use `lifecycle` blocks cautiously. Use `create_before_destroy = true` for zero-downtime updates on critical resources like Auto Scaling Groups or Launch Templates. Use `prevent_destroy = true` for stateful data resources (like databases or S3 buckets) if dealing with production data (though less relevant for LocalStack, maintain the habit).
- **Data Sources**: Prefer using `data` sources to fetch IDs dynamically rather than hardcoding ARNs or IDs.

### Comments
- Use `#` for single-line comments. 
- Avoid `//` or `/* */` unless commenting out large blocks of code temporarily during debugging.
- Explain *why* a configuration is set a certain way, especially for obscure AWS settings, non-obvious workarounds, or LocalStack-specific quirks. Do not explain *what* the code does (Terraform is already declarative and readable).

## 3. Workflow for Agents

When requested to modify this infrastructure:
1. **Analyze**: Read `.tf` files to understand the current architecture.
2. **Modify**: Use file editing tools to add/update resources.
3. **Format**: Always run `terraform fmt` on your modified files.
4. **Validate**: Run `terraform validate` to catch typos or syntax errors.
5. **Verify**: Run `terraform plan` to ensure the AWS provider accepts the configuration against LocalStack parameters.
6. **Report**: Show the user the key parts of the plan or validation output to confirm success. Do not execute `terraform apply` unless specifically asked by the user.