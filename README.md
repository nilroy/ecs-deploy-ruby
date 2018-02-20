## ecs-deploy-ruby

### Prerequisites
The tool use aws-sdk version 3.
Clone the repo and run 

```
bundle install
```
Set following AWS environmental variables

- AWS\_ACCESS\_KEY\_ID
- AWS\_SECRET\_KEY
- AWS\_SECRET\_ACCESS\_KEY

## Supported actions

Currently the tool supports following actions:

- update of ECS service/ multiple ECS services with new docker image of container running in a task (Supports FARGATE)
- create a ecs-cluster

## Sample config.yml file

The tool requires a config file in YML format. An example config file:

```
:defaults: &defaults
  :exclude_container:
    -
  :exclude_service:
    -
  :image_repo: '<docker_image_repo>'
  :services:
    -
      service_name: service1
    -
      service_name: service2

:staging:
  <<: *defaults
  :ecs_cluster: 'staging-cluster'

:perf:
  <<: *defaults
  :ecs_cluster: 'perf-cluster'

:production:
  <<: *defaults
  :ecs_cluster: 'production-cluster'

```

# Operations
## Create ecs-cluster
```
bundle exec bin/ecs_deploy.rb --env perf --config <path to config file> --action create-cluster
```
## Updating image of a running task

```
bundle exec bin/ecs_deploy.rb --env perf --config <path to config file> --revision <revision to deploy> --action update-image
```

# Future development
In future the tool will be able to do more stuff. The example directory contains a reference config.yml file that contains stuff which will be used in future releases of the tool.
