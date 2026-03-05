# Step 5: Identity and IAM Mappings

## Goal
Scrub AWS IAM, Roles, and Cognito dependencies.

## Rationale
Since the OpenStack equivalent (Keystone) behaves differently than AWS IAM, and the target DevStack environment relies mostly on project-level `admin` or `demo` users, detailed AWS IAM roles, policies, and Cognito configurations were discarded. A placeholder `identity.tf` is left behind noting that security relies natively on the Neutron implementation rather than IAM instance profiles.

## Alternatives
*   **Alternative considered:** Use Terraform to manage Keystone Projects, Users, and Roles matching the original AWS roles.
*   **Why it was not chosen:** Because DevStack deployments are highly constrained and typically meant for a single tenant, trying to provision multiple granular Keystone roles overcomplicates the environment without providing real security benefits in a local nested VM context.