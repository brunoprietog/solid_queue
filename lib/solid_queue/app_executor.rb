# frozen_string_literal: true

module SolidQueue
  module AppExecutor
    def wrap_in_app_executor(&block)
      if SolidQueue.app_executor
        SolidQueue.app_executor.wrap(&block)
      else
        yield
      end
    end

    def handle_thread_error(error)
      if SolidQueue.on_thread_error
        SolidQueue.logger.error("[SolidQueue] #{error}")
        SolidQueue.on_thread_error.call(error)
      end
    end
  end
end
