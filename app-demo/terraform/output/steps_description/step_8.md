# Step 8: Identity (`identity.tf`)

## Goal

Create Keystone resources (project, role, user, role assignment) as a structural mapping of the AWS Cognito User Pool, groups, and client — acknowledging that Keystone is not a functional replacement for Cognito.

## Rationale

Keystone is the only identity service available in OpenStack. While it cannot replicate Cognito's user pool features (self-registration, JWT issuance, password policies, SRP auth), it provides the closest structural mapping:

- `openstack_identity_project_v3` maps to the User Pool as a logical container
- `openstack_identity_role_v3` ("OWNERS") maps to the Cognito group "OWNERS"
- `openstack_identity_user_v3` provides a service user for backend operations
- `openstack_identity_role_assignment_v3` links the role to the user on the project

This gives the infrastructure a recognizable identity structure even though the application would need significant modification to use Keystone tokens instead of Cognito JWTs.

## Alternatives

1. **Keycloak on a VM** — Full-featured identity provider with JWT support, OAuth2/OIDC flows, and self-registration. Would be a much closer Cognito replacement functionally. Rejected because it's outside the scope of this infrastructure migration (requires additional VM, Java runtime, and application configuration).
2. **Skipping identity entirely** — Since Keystone can't truly replace Cognito. Rejected because the plan explicitly calls for a structural mapping, and having the project/role/user structure documents the intended identity model.
3. **Using Keystone application credentials** — For machine-to-machine auth. Considered but not used as the primary mechanism since the plan focuses on user/role mapping.
