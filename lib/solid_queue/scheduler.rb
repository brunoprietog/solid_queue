# frozen_string_literal: true

class SolidQueue::Scheduler
  include SolidQueue::Runner

  attr_accessor :batch_size, :polling_interval

  def initialize(**options)
    options = options.dup.with_defaults(SolidQueue::Configuration::SCHEDULER_DEFAULTS)

    @batch_size = options[:batch_size]
    @polling_interval = options[:polling_interval]
  end

  def short_description
    "#{batch_size}, #{polling_interval}"
  end

  private
    def run
      batch = SolidQueue::ScheduledExecution.next_batch(batch_size)

      if batch.size > 0
        procline "preparing #{batch.size} jobs for execution"

        SolidQueue::ScheduledExecution.prepare_batch(batch)
      else
        procline "waiting"
        interruptible_sleep(polling_interval)
      end
    end

    def shutdown
      super

      @shutdown_completed = true
    end

    def shutdown_completed?
      @shutdown_completed
    end

    def metadata
      super.merge(batch_size: batch_size, polling_interval: polling_interval)
    end
end
