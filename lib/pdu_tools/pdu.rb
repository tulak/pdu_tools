module PDUTools
  class PDU
    attr_reader :pdu_hex
    def initialize pdu_hex
      @pdu_hex = pdu_hex
    end

    def checksum
      @checksum ||= begin
        sum = @pdu_hex.scan(/../).collect{|c| c.to_i(16)}.sum
        "%02X" % (sum & 0xFF)
      end
    end

    def length
      @length ||= (@pdu_hex.length / 2) - 1
    end
  end
end