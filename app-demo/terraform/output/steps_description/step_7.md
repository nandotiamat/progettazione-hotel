# step_7

## Goal

Verify each step's Terraform is correctly formatted and syntactically valid.

## Rationale

`terraform fmt` ensures consistent HCL style and `terraform validate` catches structural errors early before attempting to plan/apply against DevStack.

## Alternatives

- Run `terraform plan`: would validate deeper provider interactions, but requires live OpenStack credentials and a reachable DevStack API.
