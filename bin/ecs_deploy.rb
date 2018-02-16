#!/usr/bin/env ruby
# frozen_string_literal: true

# Will deploy to ecs services
# Authors
# Nilanjan Roy <nilanjan.roy@nosto.com/nilanjan1.roy@gmail.com>

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib') unless $LOAD_PATH.include?(File.dirname(__FILE__) + '/../lib')

require 'requirements'
require 'pry'

# Class for deploying to ECS
class EcsDeploy
  def initialize(env:, config:, revision:, region: 'us-east-1', action: 'update')
    @env = env
    @config = YAML.load_file(config)[@env.to_sym]
    @region = region
    @action = action
    @revision = revision
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
  rescue ECS::EcsException => e
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

  def update_service(service:, task_definition:)
    task_definition_arn = @ecs.register_task_definition(task_definition: task_definition)[:task_definition][:task_definition_arn]
    @log.info { "New task defintion for service => #{service} is #{task_definition_arn}" }
    @ecs.update_service(cluster: @config[:ecs_cluster], service: service, task_defintion_arn: task_definition_arn)
  end

  def ecs_update
    services = @config[:services]
    services.each do |service|
      binding.pry
      puts service
      next
      @log.info { "Updating service #{service}" }
      service_definition = @ecs.fetch_service_definition(cluster: @config[:ecs_cluster], service: service)
      running_task_definition_arn = service_definition[:services][0][:task_definition]
      @log.info { "Running task definition for service => #{service} is #{running_task_definition_arn}" }
      task_definition = @ecs.fetch_task_definition(task_definition: running_task_definition_arn)
      container_definitions = task_definition[:task_definition][:container_definitions]
      new_container_definitions = modify_container_definition(container_definitions: container_definitions)
      @log.info { "Generating new task definition for service => #{service}" }
      new_task_definition = gen_task_definition(task_definition: task_definition, container_definitions: new_container_definitions)
      update_service(service: service, task_definition: new_task_definition)
      @log.info { "Service #{service} is updated..." }
    end
  end
end

if __FILE__ == $PROGRAM_NAME

  valid_actions = %w[update]
  valid_environments = %w[staging perf production external management]
  opts = Trollop.options do
    banner <<-EOS
    Usage:
       #{$PROGRAM_NAME} [options]
       where [options] are:
    EOS
    opt :region, 'Region', type: :string, default: 'us-east-1'
    opt :env, "Environment: #{valid_environments.join('/')}", type: :string, default: nil
    opt :config, 'Config file of the ecs cluster in YAML format', type: :string
    opt :revision, 'Revision of the docker image', type: :string, default: 'latest'
    opt :action, "Action: #{valid_actions.join('/')}", type: :string, default: nil
  end

  Trollop.die :env, "Provide valid environment! Choose from : #{valid_environments.join('/')}" \
                unless valid_environments.include?(opts[:env])

  Trollop.die :action, "Wrong value for action! Choose from  : #{valid_actions.join('/')}" \
                unless valid_actions.include?(opts[:action])

  Trollop.die :revision, 'Provide docker image revision' \
                unless opts[:revision]

  Trollop.die :config, 'Provide config file path for the ecs cluster' \
                unless opts[:config]

  ecs = EcsDeploy.new(env: opts[:env], region: opts[:region], action: opts[:action],
                      config: opts[:config], revision: opts[:revision])
  ecs.main
end
