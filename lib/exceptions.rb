# frozen_string_literal: true

module AwsECS
  class EcsException < RuntimeError
  end

  class NotFoundException < RuntimeError
  end
end
