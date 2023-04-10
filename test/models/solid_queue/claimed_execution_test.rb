require "test_helper"

class SolidQueue::ClaimedExecutionTest < ActiveSupport::TestCase
  setup do
    @jobs = SolidQueue::Job.where(queue_name: "fixtures")
    @jobs.each(&:prepare_for_execution)

    @process = SolidQueue::Process.register({ queue: "fixtures" })
  end

  test "claim all jobs for existing queue" do
    assert_difference -> { SolidQueue::ReadyExecution.count } => -@jobs.count, -> { SolidQueue::ClaimedExecution.count } => @jobs.count do
      subscribe_to_notification_events do
        SolidQueue::ReadyExecution.claim("fixtures", @jobs.count + 1)
      end
    end

    assert_notified_events [ "claim_jobs", { limit: @jobs.count + 1, claimed_size: @jobs.count } ]
  end

  test "claim jobs for queue without jobs at the moment" do
    assert_no_difference [ -> { SolidQueue::ReadyExecution.count }, -> { SolidQueue::ClaimedExecution.count } ] do
      subscribe_to_notification_events do
        SolidQueue::ReadyExecution.claim("some_non_existing_queue", 10)
      end
    end

    assert_notified_events [ "claim_jobs", { limit: 10, claimed_size: 0 } ]
  end

  test "claim some jobs for existing queue" do
    assert_difference -> { SolidQueue::ReadyExecution.count } => -2, -> { SolidQueue::ClaimedExecution.count } => 2 do
      subscribe_to_notification_events do
        SolidQueue::ReadyExecution.claim("fixtures", 2)
      end
    end

    assert_notified_events [ "claim_jobs", { limit: 2, claimed_size: 2 } ]
  end

  test "perform job successfully" do
    job = solid_queue_jobs(:add_to_buffer_job)
    claimed_execution = prepare_and_claim_job(job)

    assert_difference -> { SolidQueue::ClaimedExecution.count }, -1 do
      subscribe_to_notification_events do
        claimed_execution.perform(@process)
      end
    end

    assert job.reload.finished?
    assert_notified_events [ "perform_job", { process: @process, execution: claimed_execution, job_id: job.id, active_job_id: job.active_job_id } ]
  end

  test "perform job that fails" do
    job = solid_queue_jobs(:raising_job)
    claimed_execution = prepare_and_claim_job(job)

    assert_difference -> { SolidQueue::ClaimedExecution.count } => -1, -> { SolidQueue::FailedExecution.count } => 1 do
      subscribe_to_notification_events do
        claimed_execution.perform(@process)
      end
    end

    assert_not job.reload.finished?
    assert job.failed?

    assert_equal @process, claimed_execution.process
    assert_notified_events [ "perform_job", { process: @process, execution: claimed_execution, job_id: job.id, active_job_id: job.active_job_id, exception: RuntimeError.new } ]
  end

  test "job failures are reported via Rails error subscriber" do
    subscriber = ErrorsBuffer.new

    with_error_subscriber(subscriber) do
      job = solid_queue_jobs(:raising_job)
      claimed_execution = prepare_and_claim_job(job)

      claimed_execution.perform(@process)
    end

    assert_equal 1, subscriber.errors.count
    assert_equal "This is a RuntimeError exception", subscriber.messages.first
  end

  test "release" do
    job = solid_queue_jobs(:add_to_buffer_job)
    claimed_execution = prepare_and_claim_job(job)

    assert_difference -> { SolidQueue::ClaimedExecution.count } => -1, -> { SolidQueue::ReadyExecution.count } => 1 do
      subscribe_to_notification_events do
        SolidQueue::ClaimedExecution.release_all
      end
    end

    assert job.reload.ready?

    assert_notified_events [ "release_jobs", { size: 1 } ]
  end

  private
    def prepare_and_claim_job(job)
      job.prepare_for_execution
      job.reload.ready_execution.claim
      job.reload.claimed_execution
    end

    def with_error_subscriber(subscriber)
      Rails.error.subscribe(subscriber)
      yield
    ensure
      Rails.error.unsubscribe(subscriber) if Rails.error.respond_to?(:unsubscribe)
    end

    def subscribe_to_notification_events
      callback = lambda { |*args| EventsBuffer.add ActiveSupport::Notifications::Event.new(*args) }

      ActiveSupport::Notifications.subscribed(callback, /solid_queue/) do
        yield
      end
    end

    def assert_notified_events(*events)
      assert_equal events.size, EventsBuffer.size
      events.each do |action, payload|
        assert EventsBuffer.include?(action, payload), "not found #{action} event with #{payload}"
      end
    end
end
