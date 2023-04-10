class SolidQueue::ClaimedExecution < SolidQueue::Execution
  belongs_to :process

  class Result < Struct.new(:success, :exception)
    def success?
      success
    end
  end

  class << self
    def claim_batch(job_ids)
      claimed_at = Time.current
      rows = Array(job_ids).map { |id| { job_id: id, created_at: claimed_at } }
      insert_all(rows) if rows.any?
    end

    def release_all
      instrument "release_jobs", size: count do
        includes(:job).each(&:release)
      end
    end
  end

  def perform(process)
    instrument("perform_job", process: process, job_id: job.id, active_job_id: job.active_job_id) do |payload|
      claimed_by(process)

      result = execute
      if result.success?
        finished
      else
        failed_with(result.exception)
        payload[:exception] = result.exception
      end
    end
  end

  def release
    transaction do
      job.prepare_for_execution
      destroy!
    end
  end

  private
    def claimed_by(process)
      update!(process: process)
    end

    def execute
      ActiveJob::Base.execute(job.arguments)
      Result.new(true, nil)
    rescue Exception => e
      Result.new(false, e)
    end

    def finished
      transaction do
        job.finished
        destroy!
      end
    end

    def failed_with(exception)
      transaction do
        job.failed_with(exception)
        destroy!
      end
    end
end
