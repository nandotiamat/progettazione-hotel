## Goal
Run a final `terraform validate` after completing all prior steps to ensure the full configuration is syntactically and structurally valid.

## Rationale
Validating at the end catches any cross-file dependency issues introduced while executing the plan sequentially.

## Alternatives
- Skip the final validate because per-step validates already passed: rejected because the process explicitly requires a final validation.
