Execute the plan outlined in `@PLAN.md` strictly sequentially, step-by-step. 
Stay consistent with the chosen provider version(you will need `openstack` provider).
For each step in the plan, complete the following sequence before moving to the next:

1. **Code Generation:** Write the required Terraform scripts and save them directly into the `@output` directory. 
2. **Code Validation:** Use `terraform validate` command to validate the code you have written. If it outputs unexpected errors, solve them.
2. **Documentation:** Create a concise summary file named `step_[i].md` in the `@output/steps_description` folder (where `i` is the current step index, e.g., `step_1.md`).
3. **File Format:** The `step_[i].md` file must explicitly include three sections:
   - **Goal:** A brief description of what the step achieves.
   - **Rationale:** Why you chose this specific implementation approach.
   - **Alternatives:** Any alternative approaches you considered and why they were not chosen.

Do not skip steps or combine multiple steps into one output.
When a step is over, please let me review it before you proceed.
When all the steps are over, do a final `terraform validate` to make sure there are no errors.
