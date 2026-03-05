# Step 2: IAM & Security (Keystone & Neutron)

## Goal
Provision the security foundation for the environment. This includes creating Keystone users and roles for application object storage access, generating an SSH keypair for instance access, and defining a strict set of Neutron Security Groups for network isolation between the Bastion, Frontend, Backend, and Database tiers.

## Rationale
- **Users/Roles**: Instead of using a monolithic admin credential for the application to access Swift, we provision least-privilege users (`app_frontend_reader` and `app_frontend_uploader`) and bind them to specific roles (`media_reader`, `media_uploader`).
- **Keypair**: We generate the SSH keypair dynamically via Terraform using the `tls` and `random` providers. This avoids checking private keys into version control while automatically writing the private key locally for developer use.
- **Security Groups**: We implement explicit tier isolation. The Bastion is the sole entry point for SSH. Frontend nodes only receive HTTP from anywhere and SSH from Bastion. Backend only receives traffic from Frontend, and Database only receives traffic from Backend. This drastically reduces the attack surface.

## Alternatives
- **Pre-existing Keypair**: We could have required the user to pass an existing public key string. Generating it dynamically provides a fully "batteries-included" experience out of the box.
- **Single Flat Security Group**: We could have used a single "default" SG allowing all internal traffic, but this violates the strict segmentation requirement mentioned in the plan.
