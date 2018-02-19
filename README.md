## ecs-deploy-ruby
Currently the tool supports update of ECS service with new docker image of container. It requires a config file in YML format. AN example config file:

```
:defaults: &defaults
  :services:
    - service1
    - service2
  :exclude_containers:
    -
  :image_repo: '<AWS account id>.dkr.ecr.<AWS region>.amazonaws.com/<repository_name>'

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

# How to run

```
bundle exec bin/ecs_deploy.rb --env perf --config <path to config file> --revision <revision to deploy> --action update
```
