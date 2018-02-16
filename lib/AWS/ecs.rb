# frozen_string_literal: true

module ECS
  # Main class for ecs
  class ECS
    def initialize(env: nil, region: 'us-east-1')
      @log = ECS::ECSLog.instance.log
      @env = env
      @ecs = Aws::ECS::Client.new(region: region)
    end

    def fetch_service_definition(cluster:, service: [])
      ecs.describe_services(cluster: cluster, services: service).to_h
    end
  end
end
