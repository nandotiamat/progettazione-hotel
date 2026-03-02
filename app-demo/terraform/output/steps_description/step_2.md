# step_2

## Goal

Define the AWS(LocalStack) -> OpenStack(DevStack) mapping and clearly label each capability as supported, workaround, or omitted based on enabled DevStack services.

## Rationale

This repository targets a constrained DevStack profile (Neutron+OVN, Swift, Octavia). Capturing the mapping up front prevents accidental attempts to recreate AWS-managed services (Cognito, API Gateway, CloudFront, RDS, Route53, autoscaling) that are not present.

## Alternatives

- Enable additional OpenStack services (Designate/Trove/Senlin/Aodh) to get closer parity: not assumed by the prompt; would materially change the environment.
- Implement a self-managed API gateway/IdP layer on VMs: possible, but would be a separate architecture choice and expands scope.
