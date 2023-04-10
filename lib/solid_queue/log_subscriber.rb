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

    def claim_jobs(event)
      debug "claim_jobs", event, format_payload(event.payload, :limit, :claimed_size)
    end

    def release_jobs(event)
      debug "release_jobs", event, format_payload(event.payload, :size)
    end

    def perform_job(event)
      exception = event.payload[:exception]
      action = exception.present? ? "failed_job" : "performed_job"

      message = format_payload(event.payload, :job_id, :active_job_id)
      if exception
        message += " FAILED with #{exception.class.name}"
      end

      debug action, event, message
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

      def format_payload(payload, *attributes)
        payload.slice(*attributes).map { |attr, value| "#{attr}: #{value}"}.join(", ")
      end

      %w[ info debug warn ].each do |level|
        class_eval <<-METHOD, __FILE__, __LINE__ + 1
          def #{level}(action, event, message)
            super log_prefix_for_action(action, event) + message
          end
        METHOD
      end

      def log_prefix_for_action(action, event)
        prefix = if (process = event.payload[:process]) && process.try(:process_kind)
          process.process_kind
        elsif execution = event.payload[:execution]
          "execution #{execution.class.name}(#{execution.id})"
        end

        [ "solid", "queue", prefix ].compact.join("-") + " #{action} (#{event.duration.round(1)}ms) "
      end
  end
end
