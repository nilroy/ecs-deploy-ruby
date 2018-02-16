# frozen_string_literal: true

$LOAD_PATH.unshift File.dirname(__FILE__)

# stdlib
require 'logger'
require 'yaml'
require 'json'
require 'pathname'
require 'base64'
require 'erb'
require 'timeout'
require 'singleton'

# 3rd party
require 'rubygems'
require 'aws-sdk-ecs'
require 'trollop'
require 'awesome_print'
require 'pry-byebug'

# internal requires
require 'AWS/ecs'
require 'exceptions'
require 'log'
