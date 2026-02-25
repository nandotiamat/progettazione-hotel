# Step 10: Skip — CloudFront (`frontend_distribution.tf`)

## Goal

Document the absence of a CDN equivalent in OpenStack. No Terraform resources are created for this step.

## Rationale

OpenStack has **no CDN service**. The original `frontend_distribution.tf` provided:

- CloudFront distribution with S3 origin
- Default cache behavior (GET/HEAD caching, HTTPS redirect)
- Custom error responses for SPA routing (403/404 → index.html with 200)
- Geo-restriction configuration
- SSL certificate (CloudFront default)

In the OpenStack migration, frontend static files are served directly from Swift (with the public read ACL set in Step 6). The key functional gaps are:

1. **CDN caching/edge distribution** — Not available. Swift serves directly from the region. Acceptable for a development environment.
2. **SPA error routing** — Swift does not rewrite 404s to index.html. The frontend would need to be served via Nginx on a VM for this behavior, or the SPA could use hash-based routing.
3. **HTTPS termination** — Would need to be handled by the load balancer or a reverse proxy.

No `frontend_distribution.tf` file is produced in the output directory.

## Alternatives

1. **Nginx on a VM serving static files** — Would provide SPA routing (try_files), caching, and HTTPS. The most complete replacement. Rejected for this step to keep the migration scope manageable, but recommended for production.
2. **Swift static web middleware** — Swift has optional staticweb middleware that can serve index.html and error pages. However, it requires specific Swift configuration that may not be enabled in a default DevStack. Rejected due to uncertainty of availability.
3. **Caddy or Traefik as a frontend server** — Modern web servers with automatic HTTPS. Rejected as out of scope for the infrastructure migration.
