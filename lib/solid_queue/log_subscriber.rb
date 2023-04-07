# frozen_string_literal: true

require "active_support/log_subscriber"

module SolidQueue
  class LogSubscriber < ActiveSupport::LogSubscriber
    def start_supervisor(event)
      processes = event.payload[:supervised]
      info "start", event, "#{process_description_from_event(event)} [#{supervised_processes_description(processes)}]"
    end

    def start_supervised_process(event)
      mode = event.payload[:mode]
      info "start in #{mode} mode", event, process_description_from_event(event)
    end

    def logger
      SolidQueue.logger
    end

    private
      def supervised_processes_description(runners)
        runners.map { |runner| "#{runner.process_kind}(#{runner.short_description})" }.join(", ")
      end

      def process_description_from_event(event)
        event.payload[:process]&.description || ""
      end

      %w[ info debug warn ].each do |level|
        class_eval <<-METHOD, __FILE__, __LINE__ + 1
          def #{level}(action, event, message)
            super log_prefix_for_process_action(action, event) + message
          end
        METHOD
      end

      def log_prefix_for_process_action(action, event)
        process = event.payload[:process]
        process_kind = process&.process_kind || "unknown"
        "solid-queue-#{process_kind} #{action} (#{event.duration.round(1)}ms) "
      end
  end
end
