## Goal
Define the Nova-side primitives needed for instances: a custom flavor and a generated SSH keypair whose private key is written to `~/.ssh/hotel-key.pem`.

## Rationale
Creating `hotel_flavor` ensures instance sizing matches the nested virtualization constraints. Generating the SSH keypair in Terraform keeps the stack self-contained while still meeting the requirement that the private key is written locally with restrictive permissions.

## Alternatives
- Use an existing flavor: rejected because DevStack environments vary and the requirement explicitly asks for a custom `hotel_flavor`.
- Require the user to supply an existing public key: rejected because the requirement asks Terraform to generate `hotel-keypair` and store the private key locally.
