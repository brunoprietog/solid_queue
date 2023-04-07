# frozen_string_literal: true

module SolidQueue
  module Procline
    private

    # Sets the procline ($0)
    # solid-queue-supervisor(0.1.0): <string>
    def procline(string)
      $0 = "solid-queue-#{process_kind}(#{SolidQueue::VERSION}): #{string}"
    end
  end
end
