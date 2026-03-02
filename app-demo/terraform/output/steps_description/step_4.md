# step_4

## Goal

Define the required inputs, defaults, and environment assumptions for running the OpenStack Terraform against a typical DevStack deployment.

## Rationale

OpenStack deployments vary (regions, domains, external network names, available images/flavors). Explicit variables with conservative defaults reduce surprises while keeping secrets out of the repo.

## Alternatives

- Rely on `clouds.yaml` exclusively: convenient, but hard to validate and less explicit for this repo's consumers.
- Hardcode DevStack defaults (admin/secret, public/RegionOne, image names): fast for one machine, but brittle and unsafe to commit.
