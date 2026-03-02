# step_5

## Goal

Implement the database initialization strategy for the OpenStack port without relying on local port-forwards or external tooling.

## Rationale

Cloud-init user-data is the most reliable approach in a constrained DevStack environment because it runs on the instance at first boot and does not require Terraform runner network reachability to the DB.

## Alternatives

- `remote-exec` over SSH: workable, but depends on SSH reachability and timing; more brittle in nested environments.
- `local-exec` from the Terraform runner: mirrors the LocalStack approach but often fails if the DB is not directly reachable from the runner.
