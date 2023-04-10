# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
require "rails/test_help"
require "debug"
require "mocha/minitest"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures :all
end

class ActiveSupport::TestCase
  teardown do
    JobsBuffer.clear
    EventsBuffer.clear
    File.delete(SolidQueue.supervisor_pidfile) if File.exist?(SolidQueue.supervisor_pidfile)
  end

  private
    def wait_for_jobs_to_finish_for(timeout = 10.seconds)
      Timeout.timeout(timeout) do
        while SolidQueue::Job.where(finished_at: nil).any? do
          sleep 0.25
        end
      end
    rescue Timeout::Error
    end

    def run_supervisor_as_fork(**options)
      fork do
        SolidQueue::Supervisor.start(**options)
      end
    end

    def wait_for_registered_processes(count, timeout: 10.seconds)
      Timeout.timeout(timeout) do
        while SolidQueue::Process.count < count do
          sleep 0.25
        end
      end
    rescue Timeout::Error
    end

    def assert_no_registered_processes
      skip_active_record_query_cache do
        assert SolidQueue::Process.none?
      end
    end

    def terminate_process(pid, timeout: 10, signal: :TERM, from_parent: true)
      signal_process(pid, signal)
      wait_for_process_termination_with_timeout(pid, timeout: timeout, from_parent: from_parent)
    end

    def wait_for_process_termination_with_timeout(pid, timeout: 10, from_parent: true, exitstatus: 0)
      Timeout.timeout(timeout) do
        if from_parent
          Process.waitpid(pid)
          assert exitstatus, $?.exitstatus
        else
          loop do
            break unless process_exists?(pid)
            sleep(0.1)
          end
        end
      end
    rescue Timeout::Error
      signal_process(pid, :KILL)
      raise
    end

    def signal_process(pid, signal, wait: nil)
      Thread.new do
        sleep(wait) if wait
        Process.kill(signal, pid)
      end
    end

    def process_exists?(pid)
      Process.getpgid(pid)
      true
    rescue Errno::ESRCH
      false
    end

    # Allow skipping AR query cache, necessary when running test code in multiple
    # forks. The queries done in the test might be cached and if we don't perform
    # any non-SELECT queries after previous SELECT queries were cached on the connection
    # used in the test, the cache will still apply, even though the data returned
    # by the cached queries might have been updated, created or deleted in the forked
    # processes.
    def skip_active_record_query_cache(&block)
      ActiveRecord::Base.uncached(&block)
    end
end
