# step_3

## Goal

Define the target OpenStack Terraform root module file structure (by concern) that the next steps will implement.

## Rationale

Keeping the same "by domain" grouping as the existing repo (network/security/compute/storage) makes the migration readable and limits cross-file coupling. It also aligns with typical Terraform root-module conventions.

## Alternatives

- Single-file root module: less file overhead but harder to maintain and review.
- Overly granular per-resource files: reduces merge conflicts but makes navigation and dependency reasoning harder for this size stack.
