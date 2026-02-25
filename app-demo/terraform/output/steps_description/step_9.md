# Step 9: Skip — API Gateway (`gateway.tf`)

## Goal

Document the absence of an API Gateway equivalent in OpenStack. No Terraform resources are created for this step.

## Rationale

OpenStack has **no native equivalent** to AWS API Gateway v2. The original `gateway.tf` provided:

- HTTP API with CORS configuration
- JWT authorizer (validating Cognito tokens)
- HTTP_PROXY integration to the backend
- Route-level authorization (public vs. protected routes)
- Request parameter injection (user identity headers)
- Auto-deploying stage

All of these functionalities must be handled at the application level or via a reverse proxy:

1. **CORS** — Handled by the backend application framework (e.g., FastAPI middleware, Express CORS)
2. **JWT validation** — Implemented in the backend middleware, using Keystone tokens instead of Cognito JWTs
3. **Routing** — The load balancer forwards all traffic to the backend, which handles its own routing
4. **Header injection** — The authentication middleware extracts user identity from tokens and injects headers
5. **Rate limiting / throttling** — Not available natively; would require Nginx or similar on a VM

No `gateway.tf` file is produced in the output directory.

## Alternatives

1. **Nginx reverse proxy on a VM** — Could replicate some API Gateway functionality (routing, rate limiting, basic auth). Rejected because it adds a VM and significant configuration complexity, and the plan explicitly says to handle this at the app level.
2. **Kong or Traefik on a VM** — Full API gateway software. Rejected for the same reasons as Nginx, plus additional software dependencies.
3. **Apache APISIX** — Open-source API gateway. Rejected as out of scope for this infrastructure migration.
