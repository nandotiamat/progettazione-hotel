# step_4_artifacts

## Goal

Implement the provider configuration and variable inputs needed to run the OpenStack port in a typical DevStack environment.

## Rationale

Step 4 in `PLAN.md` is where we turn assumptions into explicit variables and provider wiring, so later resources can be implemented without hardcoding environment-specific details.

## Alternatives

- Use only environment variables / `clouds.yaml` and skip explicit variables: convenient locally, but makes the module harder to reuse and validate.
- Inline credentials in provider config: insecure and not acceptable for committed Terraform.
