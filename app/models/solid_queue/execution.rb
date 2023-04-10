class SolidQueue::Execution < ActiveRecord::Base
  self.abstract_class = true

  belongs_to :job

  def self.instrument(action, payload = {}, &block)
    ActiveSupport::Notifications.instrument("#{action}.solid_queue", payload, &block)
  end

  private
    def assume_attributes_from_job
      self.queue_name ||= job&.queue_name
      self.priority = job&.priority if job&.priority.to_i > priority
    end

    def instrument(action, payload = {}, &block)
      self.class.instrument(action, payload.merge(execution: self), &block)
    end
end
