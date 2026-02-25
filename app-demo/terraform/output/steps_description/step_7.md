# Step 7: Database (`storage.tf`, part 2)

## Goal

Replace AWS RDS (managed PostgreSQL) with a self-managed PostgreSQL instance running on an OpenStack compute VM, since Trove (DBaaS) is not available in DevStack.

## Rationale

The plan explicitly decided on a dedicated VM with `user_data` for a "closer architectural match to RDS." The VM is placed in a private subnet with a fixed IP (via `cidrhost`), protected by the database security group that only allows port 5432 from compute instances — mirroring the RDS isolation pattern.

The `user_data` script handles the full PostgreSQL lifecycle: installation, configuration for network access, creation of the database and user. PostgreSQL is configured to listen on all interfaces and accept MD5-authenticated connections from the internal 10.0.0.0/16 CIDR, which covers both private subnets where the backend instances reside.

The `null_resource` with `local-exec` from the original design (for schema loading via `psql`) was not replicated because it required a local psql client connected to LocalStack's port-mapped database. In the OpenStack design, schema loading would be done via application migrations or a separate provisioning step.

## Alternatives

1. **null_resource with local-exec and SSH** — Running psql via SSH into the DB VM. Rejected because it requires SSH key setup and adds fragility; `user_data` is self-contained.
2. **Docker container on the DevStack host** — Simpler, closer to the LocalStack approach. Rejected per the plan's decision to use a VM for architectural parity with RDS.
3. **Cinder volume for persistent data** — Attaching a block storage volume for the PostgreSQL data directory. Considered for production but rejected for DevStack simplicity — the ephemeral disk is sufficient for development.
