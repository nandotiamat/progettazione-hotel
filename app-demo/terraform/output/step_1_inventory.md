# Step 1 - Inventory What The AWS Stack Does

This captures what the existing AWS(LocalStack) Terraform provisions and highlights items that will not map 1:1 to the target constrained DevStack (Neutron+OVN, Swift, Octavia).

## Service-by-service inventory (by concern)

| Concern | Files | What it provisions |
| --- | --- | --- |
| Networking | `network.tf` | VPC, public/private subnets, IGW, route tables, Route53 private zone; also reads LocalStack "default" VPC/subnets/SG for debug wiring |
| Security | `security.tf` | SGs for ALB/EC2/DB; extra ingress rules on default SG for LocalStack port mapping |
| Compute | `compute.tf` | ALB + target group + listener; launch template + ASG; CloudWatch alarm + scaling policy; manual debug EC2 serving on port 8000 |
| Storage/CDN | `storage.tf`, `frontend_distribution.tf` | S3 website bucket (public); S3 media bucket; optional seed object upload (`seed_media/*`); CloudFront distribution with SPA-friendly errors |
| Database | `storage.tf` | RDS Postgres + subnet group; schema init via `null_resource` + `local-exec` running `psql` |
| Identity/API | `identity.tf`, `gateway.tf` | Cognito user pool/client/domain/group; API Gateway v2 HTTP API with JWT authorizer and HTTP proxy integration to backend:8000 |
| IAM | `iam.tf` | Backend IAM role/policy/profile allowing access to S3 media bucket |
| Local integration | `main.tf` | AWS provider pinned to LocalStack endpoints; writes `/config/localstack.env` with service endpoints and IDs |

## Things that cannot be replicated 1:1 in constrained DevStack

- Cognito user pools/groups and managed JWT authorizer behavior
- API Gateway v2 HTTP API (authorizers, routing, integrations)
- CloudFront CDN distribution
- Route53 private hosted zones (unless Designate is enabled)
- Managed Postgres (RDS) (unless Trove is enabled)
- Autoscaling based on alarms/policies (unless Senlin/Aodh are enabled)

## Mapping hints (full matrix is Step 2)

| AWS | DevStack/OpenStack (expected) |
| --- | --- |
| VPC/Subnets/Routes | Neutron network/subnet/router |
| Security groups | Neutron security groups/rules |
| ALB | Octavia load balancer |
| S3 | Swift containers |
| RDS | Postgres on Nova VM (or Trove if enabled) |
| Cognito + API Gateway | App-level auth + direct LB routing |
| Route53 | Omit (or Designate if enabled) |
| CloudFront | Omit (optional proxy/cache VM) |
| ASG/CloudWatch | Fixed instance count (manual scaling) |
