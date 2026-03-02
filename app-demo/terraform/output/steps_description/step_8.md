# step_8

## Goal

Explicitly document which AWS features are not implemented in the OpenStack port and why.

## Rationale

This avoids mismatched expectations about identity (Cognito), API Gateway, DNS, CDN, and autoscaling in an environment where those services are not enabled.

## Alternatives

- Attempt feature parity by deploying extra services on VMs: possible but would be a different architecture and out of scope for this migration.
