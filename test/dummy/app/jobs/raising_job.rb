class DefaultsError < StandardError; end
class DiscardableError < StandardError; end

class RaisingJob < ApplicationJob
  queue_as :background

  retry_on DefaultsError
  discard_on DiscardableError

  def perform(raising, attempts, *)
    raising = raising.shift if raising.is_a?(Array)
    if raising && executions < attempts
      JobsBuffer.add("Raised #{raising} for the #{executions.ordinalize} time")
      raise raising, "This is a #{raising} exception"
    else
      JobsBuffer.add("Successfully completed job")
    end
  end
end
