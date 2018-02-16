#!/usr/bin/env ruby
# frozen_string_literal: true

# Will deploy to ecs services
# Authors
# Nilanjan Roy <nilanjan.roy@nosto.com/nilanjan1.roy@gmail.com>

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib') unless $LOAD_PATH.include?(File.dirname(__FILE__) + '/../lib')

require 'requirements'

# Class for deploying to ECS
class EcsDeploy
  def initialize(env:, config:, region: 'us-east-1', action: 'update')
    @env = env
    @config = YAML.load_file(config)[@env.to_sym]
    @region = region
    @action = action
    @log = ECS::ECSLog.instance.log
    @ecs = ECS::ECS.new(env: @env, region: region)
    main
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

  def fetch_service_definition
    @ecs.fetch_service_definition
  end

  def ecs_update
    service_definition = fetch_service_definition
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
    opt :config, 'Config file in YAML format', type: :string
    opt :action, "Action: #{valid_actions.join('/')}", type: :string, default: nil
  end

  Trollop.die :env, "Provide valid environment! Choose from : #{valid_environments.join('/')}" \
                unless valid_environments.include?(opts[:env])

  Trollop.die :action, "Wrong value for action! Choose from  : #{valid_actions.join('/')}" \
                unless valid_actions.include?(opts[:action])

  ecs = EcsDeploy.new(env: opts[:env], region: opts[:region], action: opts[:action], config: opts[:config])
  ecs.main
end
