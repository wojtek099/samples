# data-jobs-terraform
### assumptions and considerations:
  - *common* module contains resources used in all environments
  - Batch Queues can contain many Compute Environments
  - Compute Environment can be added in multiple Queues
  - Queue must have at least one Compute Environment (AWS Batch API doesn't allow removing last one even if the response is correct)
  - keys of *compute_environments* map shouldn't be changed without removing resource reference from *queues* map
  - Event Rule for ECS errors (in *common* module) catches errors for all ECS containers in particular region
