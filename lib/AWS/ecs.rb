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
      service_def = @ecs.describe_services(cluster: cluster, services: [service]).to_h[:services][0]
      status = service_def[:status]
      case status
      when 'ACTIVE'
        service_def
      when 'INACTIVE'
        raise AwsECS::EcsException, "Service #{service} is INACTIVE"
      end
    end

    def create_cluster(cluster_name:)
      @ecs.create_cluster(cluster_name: cluster_name)
    end

    def fetch_task_definition(task_definition:)
      @ecs.describe_task_definition(task_definition: task_definition).to_h
    end

    def register_task_definition(task_definition:)
      @ecs.register_task_definition(task_definition).to_h
    end

    def update_service(cluster:, service:, task_defintion_arn:)
      @ecs.update_service(cluster: cluster, service: service, task_definition: task_defintion_arn)
    end

    def list_tasks(cluster:, service:, desired_status: 'RUNNING')
      @ecs.list_tasks(cluster: cluster, service_name: service, desired_status: desired_status).to_h[:task_arns]
    end

    def get_task_status(cluster:, task_arn:)
      @ecs.describe_tasks(cluster: cluster, tasks: [task_arn]).to_h[:tasks][0][:last_status]
    end
  end
end
