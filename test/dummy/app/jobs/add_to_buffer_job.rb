class AddToBufferJob < ApplicationJob
  queue_as :background

  def perform(arg)
    JobsBuffer.add(arg)
  end
end
