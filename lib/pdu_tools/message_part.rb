module PDUTools
  class MessagePart
    attr_reader :address, :body, :timestamp, :validity_period, :user_data_header
    attr_writer :body
    attr_accessor :metadata

    def initialize address, body, timestamp, validity_period, user_data_header
      @address = address
      @body = body
      @timestamp = timestamp
      @validity_period = validity_period
      @user_data_header = user_data_header
    end

    def complete?
      return true unless @user_data_header
      if @user_data_header[:parts] > 1
        false
      else
        true
      end
    end
  end
end