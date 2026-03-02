# step_1

## Goal

Create a service-by-service inventory of the existing AWS(LocalStack) Terraform stack and explicitly call out what will not map 1:1 to the constrained DevStack target.

## Rationale

The migration is only tractable if we agree on what the source stack actually does (by file/concern) and which AWS-managed capabilities (Cognito, API Gateway, CloudFront, RDS, autoscaling, Route53) must be replaced, simplified, or omitted given the enabled DevStack services.

## Alternatives

- Inventory by resource-by-resource diff: more precise, but slower and noisy for a first pass.
- Start writing OpenStack Terraform immediately: likely to produce incorrect parity and rework because missing services (IdP/API GW/CDN/DBaaS/autoscaling/DNS) must be decided up front.
