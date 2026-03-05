# output/identity.tf
# AWS IAM, Cognito, and Identity mappings are heavily simplified in DevStack.
# In OpenStack, instances use Keystone Application Credentials or metadata for API access.
# Since DevStack is being used with the default 'admin' and 'demo' tenants,
# IAM logic is fundamentally removed here to prevent over-complicating the minimal deployment footprint.
# Security relies on Neutron Security Groups (configured in security.tf).
