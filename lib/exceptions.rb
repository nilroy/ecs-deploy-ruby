# frozen_string_literal: true

module ECS
  class EcsException < RuntimeError
  end

  class NotFoundException < RuntimeError
  end
end
