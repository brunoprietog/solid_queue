module SolidQueue
  module Instrumentation
    private

    def instrument(action, payload = {}, &block)
      ActiveSupport::Notifications.instrument("#{action}.solid_queue", payload.merge(process: self), &block)
    end
  end
end
