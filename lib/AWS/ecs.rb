# frozen_string_literal: true

module AWS
  # Main class for ecs
  class ECS
    def initialize(env: nil, region: 'us-east-1')
      @log = LOGGER::ECSLog.instance.log
      @env = env
      @ecs = Aws::ECS::Client.new(region: region)
    end

    def fetch_service_definition(cluster:, service:)
      @ecs.describe_services(cluster: cluster, services: [service]).to_h
    end

    def fetch_task_definition(task_definition:)
      @ecs.describe_task_definition(task_definition: task_definition).to_h
    end

    def register_task_defintion(task_definition:)
      @ecs.register_task_defintion(task_definition).to_h
    end

    def update_service(cluster:, service:, task_defintion_arn:)
      @ecs.update_service(cluster: cluster, service: service, task_definition: task_defintion_arn)
    end
  end
end
