# frozen_string_literal: true

module SolidQueue
  module ProcessRegistration
    extend ActiveSupport::Concern

    included do
      include Procline

      set_callback :start, :before, :register
      set_callback :start, :before, :start_heartbeat

      set_callback :run, :after, -> { stop unless registered? }

      set_callback :shutdown, :before, :stop_heartbeat
      set_callback :shutdown, :after, :deregister
    end

    def inspect
      "#{self.class.name} #{metadata.inspect}"
    end
    alias to_s inspect

    def description
      metadata.without(:kind, :hostname).compact.map { |key, value| "#{key}=#{value}"}.join(", ")
    end

    def process_kind
      self.class.name.demodulize.downcase
    end

    private
      attr_accessor :process

      def register
        @process = SolidQueue::Process.register(metadata)
      end

      def deregister
        process.deregister
      end

      def registered?
        process.persisted?
      end

      def start_heartbeat
        @heartbeat_task = Concurrent::TimerTask.new(execution_interval: SolidQueue.process_heartbeat_interval) { heartbeat }
        @heartbeat_task.execute
      end

      def stop_heartbeat
        @heartbeat_task.shutdown
      end

      def heartbeat
        process.heartbeat
      end

      def metadata
        { kind: process_kind, hostname: hostname, pid: process_pid, supervisor_pid: supervisor_pid }
      end
  end
end
