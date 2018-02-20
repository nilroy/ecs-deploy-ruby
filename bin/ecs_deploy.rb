#!/usr/bin/env ruby
# frozen_string_literal: true

# Will deploy to ecs services
# Authors
# Nilanjan Roy <nilanjan.roy@nosto.com/nilanjan1.roy@gmail.com>

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib') unless $LOAD_PATH.include?(File.dirname(__FILE__) + '/../lib')

require 'requirements'

# Class for deploying to ECS
class EcsDeploy
  def initialize(env:, config:, revision:, region: 'us-east-1', action: 'update', timeout:, exclude_container: nil, exclude_service: nil)
    @env = env
    @config = YAML.load_file(config)[@env.to_sym]
    @exclude_container = exclude_container.split(',')
    @exclude_container << @config[:exclude_container]
    @exclude_container.flatten!
    @exclude_container.uniq!
    @exclude_service = exclude_service.split(',')
    @exclude_service << @config[:exclude_service]
    @exclude_service.flatten!
    @exclude_service.uniq!
    @service_task_map = gen_service_task_map
    @region = region
    @action = action
    @revision = revision
    @timeout = timeout
    @log = LOGGER::ECSLog.instance.log
    @ecs = AWS::ECS.new(env: @env, region: region)
  end

  def main
    case @action
    when 'update'
      ecs_update
    else
      puts 'Invalid action'
    end
  rescue AwsECS::EcsException => e
    @log.error(e.message)
  end

  def modify_container_definition(container_definitions:)
    new_container_definitions = []
    container_definitions.each do |container_definition|
      container_definition_clone = container_definition.clone
      next if @config[:exclude_containers].include?(container_definition_clone[:name])
      container_definition_clone[:image] = "#{@config[:image_repo]}:#{@revision}"
      @log.info { "Modified the image for container #{container_definition_clone[:name]} to use revision => #{@revision}" }
      new_container_definitions << container_definition_clone
    end
    new_container_definitions
  end

  def gen_task_definition(task_definition:, container_definitions:)
    task_defintion_clone = task_definition[:task_definition].clone
    %i[task_definition_arn container_definitions revision status compatibilities requires_attributes].each do |r|
      task_defintion_clone.delete(r)
    end
    task_defintion_clone[:container_definitions] = container_definitions
    task_defintion_clone
  end

  def register_task_definition(task_definition:)
    @ecs.register_task_definition(task_definition: task_definition)[:task_definition][:task_definition_arn]
  end

  def wait_for_task_deploy(service_name:, old_task_arns:)
    desired_count = @ecs.fetch_service_definition(cluster: @config[:ecs_cluster], service: service_name)[:desired_count]
    running_tasks = []
    newly_launched_running_tasks = []
    running_task_arns = @ecs.list_tasks(cluster: @config[:ecs_cluster], service: service_name, desired_status: 'RUNNING')
    running_task_arns.each do |task_arn|
      task_status = @ecs.get_task_status(cluster: @config[:ecs_cluster], task_arn: task_arn)
      running_tasks << task_arn if task_status == 'RUNNING'
    end
    newly_launched_tasks = running_task_arns - old_task_arns
    newly_launched_tasks.each do |task_arn|
      task_status = @ecs.get_task_status(cluster: @config[:ecs_cluster], task_arn: task_arn)
      newly_launched_running_tasks << task_arn if task_status == 'RUNNING'
    end
    newly_launched_tasks_running_count = newly_launched_running_tasks.count
    running_task_count = running_tasks.count

    Timeout.timeout(@timeout) do
      until newly_launched_tasks_running_count == desired_count
        remaining_tasks_to_start = desired_count - newly_launched_tasks_running_count
        @log.info { "Environment => #{@env}, Cluster => #{@config[:ecs_cluster]}, Service #{service_name} => { desired_count=> #{desired_count}, deployed_task_count => #{newly_launched_tasks_running_count}, remaining_tasks_to_deploy => #{remaining_tasks_to_start}, running_task_count => #{running_task_count} }" }
        running_tasks = []
        newly_launched_running_tasks = []
        running_task_arns = @ecs.list_tasks(cluster: @config[:ecs_cluster], service: service_name, desired_status: 'RUNNING')
        running_task_arns.each do |task_arn|
          task_status = @ecs.get_task_status(cluster: @config[:ecs_cluster], task_arn: task_arn)
          running_tasks << task_arn if task_status == 'RUNNING'
        end
        newly_launched_tasks = running_task_arns - old_task_arns
        newly_launched_tasks.each do |task_arn|
          task_status = @ecs.get_task_status(cluster: @config[:ecs_cluster], task_arn: task_arn)
          newly_launched_running_tasks << task_arn if task_status == 'RUNNING'
        end
        newly_launched_tasks_running_count = newly_launched_running_tasks.count
        running_task_count = running_tasks.count
        if newly_launched_tasks_running_count == desired_count
          @log.info { "Service #{service_name} is deployed" }
          break
        end
        sleep(10)
        desired_count = @ecs.fetch_service_definition(cluster: @config[:ecs_cluster], service: service_name)[:desired_count]
      end
    end
  end

  def wait_for_service_update_completion(service_info_maps:)
    threads = []
    service_info_maps.each do |service_info_map|
      service_name = service_info_map['service_name']
      old_task_arns = service_info_map['running_task_arns']
      t = Thread.new { wait_for_task_deploy(service_name: service_name, old_task_arns: old_task_arns) }
      threads << t
    end
    threads.each(&:join)
  end

  def update_service(service:, task_definition_arn:)
    @log.info { "New task defintion for service => #{service} is #{task_definition_arn}" }
    @ecs.update_service(cluster: @config[:ecs_cluster], service: service, task_defintion_arn: task_definition_arn)
  end

  def ecs_update
    services = @config[:services]
    service_info_maps = []
    services.each do |service|
      @log.info { "Updating service #{service} in #{@config[:ecs_cluster]}" }
      begin
        service_definition = @ecs.fetch_service_definition(cluster: @config[:ecs_cluster], service: service)
        service_info_map = {}
        service_info_map['service_name'] = service
        running_task_definition_arn = service_definition[:task_definition]
        running_task_arns = @ecs.list_tasks(cluster: @config[:ecs_cluster], service: service, desired_status: 'RUNNING')
        service_info_map['running_task_arns'] = running_task_arns
        @log.info { "Running task definition for service => #{service} is #{running_task_definition_arn}" }
        task_definition = @ecs.fetch_task_definition(task_definition: running_task_definition_arn)
        container_definitions = task_definition[:task_definition][:container_definitions]
        new_container_definitions = modify_container_definition(container_definitions: container_definitions)
        @log.info { "Generating new task definition for service => #{service}" }
        new_task_definition = gen_task_definition(task_definition: task_definition, container_definitions: new_container_definitions)
        new_task_definition_arn = register_task_definition(task_definition: new_task_definition)
        update_service(service: service, task_definition_arn: new_task_definition_arn)
        @log.info { "Service #{service} is updated..." }
        service_info_maps << service_info_map
      rescue AwsECS::EcsException => e
        msg = format('OOPs!! Update of service %{service} failed!! Reason: %{reason}', service: service, reason: e.message)
        raise AwsECS::EcsException, msg
      end
    end
    wait_for_service_update_completion(service_info_maps: service_info_maps)
    @log.info { "ECS cluster #{@config[:ecs_cluster]} is updated with latest revision" }
  end
end

if __FILE__ == $PROGRAM_NAME

  valid_actions = %w[update-image update-service update-task create-cluster create-task create-service create-all]
  valid_environments = %w[staging perf production external management]
  opts = Trollop.options do
    banner <<-HERE
    Usage:
       #{$PROGRAM_NAME} [options]
       where [options] are:
    HERE
    opt :region, 'Region', type: :string, default: 'us-east-1'
    opt :env, "Environment: #{valid_environments.join('/')}", type: :string, default: nil
    opt :config, 'Config file of the ecs cluster in YAML format', type: :string
    opt :revision, 'Revision of the docker image', type: :string, default: 'latest'
    opt :action, "Action: #{valid_actions.join('/')}", type: :string, default: nil
    opt :timeout, 'Timeout in seconds', type: :integer, default: 300
    opt :exclude_container, 'Comma separated list of containers to exclude from being updated', type: :string, default: nil
    opt :exclude_service, 'Comma separated list of services to exclude from being updated', type: :string, default: nil
  end

  Trollop.die :env, "Provide valid environment! Choose from : #{valid_environments.join('/')}" \
                unless valid_environments.include?(opts[:env])

  Trollop.die :action, "Wrong value for action! Choose from  : #{valid_actions.join('/')}" \
                unless valid_actions.include?(opts[:action])

  Trollop.die :revision, 'Provide docker image revision' \
                unless opts[:revision] || \
                       opts[:action] == 'update-image'

  Trollop.die :config, 'Provide config file path for the ecs cluster' \
                unless opts[:config]

  ecs = EcsDeploy.new(env: opts[:env], region: opts[:region], action: opts[:action],
                      config: opts[:config], revision: opts[:revision], timeout: opts[:timeout],
                      exclude_service: opts[:exclude_service], exclude_container: opts[:exclude_container])
  ecs.main
end
