module EventsBuffer
  extend self

  mattr_accessor :events
  self.events = Concurrent::Array.new

  def clear
    events.clear
  end

  def size
    events.size
  end

  def add(value)
    events << value
  end

  def last_event
    events.last
  end

  def include?(action, payload)
    events.any? { |event| event.name == "#{action}.solid_queue" && match_payload?(event, payload) }
  end

  private
    def match_payload?(event, payload)
      payload[:exception]&.class == event.payload[:exception]&.class && event.payload.without(:exception) == payload.without(:exception)
    end
end
