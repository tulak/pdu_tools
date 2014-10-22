
module PDUTools
  class Decoder
    include Helpers
    # http://read.pudn.com/downloads150/sourcecode/embed/646395/Short%20Message%20in%20PDU%20Encoding.pdf
    def initialize pdu_hex, direction=:sc_to_ms
      @pdu_hex = pdu_hex.dup
      @direction = direction
    end

    def decode
      @sca_length = take(2, :integer) * 2                # Service center address length
      if @sca_length > 0
        @sca_type = parse_address_type take(2)            # Service center address type
        @sca = parse_address take(@sca_length - 2), @sca_type, @sca_length # Service center address
      end
      @pdu_type = parse_pdu_type take(2, :binary)   # PDU type octet
      @message_reference = take(2) if @pdu_type[:mti] == :sms_submit
      @address_length = take(2, :integer)
      @address_type = parse_address_type take(2)
      if [:national, :international].include? @address_type
        @address_length = @address_length.odd? ? @address_length + 1 : @address_length # Always take byte aligned - hexdecimal F is added when odd number
      end
      @address = parse_address take(@address_length), @address_type, @address_length
      @pid = take(2)
      @data_coding_scheme = parse_data_coding_scheme take(2, :binary)
      @sc_timestamp = parse_7byte_timestamp take(14) if [:sms_deliver, :sms_deliver_report].include? @pdu_type[:mti]
      case @pdu_type[:vpf]
      when :absolute
        @validity_period = parse_7byte_timestamp take(14)
      when :relative
        @validity_period = parse_validity_period take(2, :integer)
      end
      @user_data_length = take(2, :integer)
      parse_user_data @user_data_length

      MessagePart.new @address, @message, @sc_timestamp, @validity_period, @user_data_header
    end

    def inspect2
      r = "<PDUTools::Decoder"
      r << "PDU: #{@pdu_hex}\n"
      r << "SCA LENGTH: #{@sca_length}\n"
      r << "SCA TYPE: #{@sca_type}\n"
      r << "SCA: #{@sca}\n"
      r << "PDU TYPE: #{@pdu_type}\n"
      r << "MESSAGE REFERENCE: #{@message_reference}\n" if @message_reference
      r << ">"
      r
    end

    private

    def take n, format=:string, data=@pdu_hex
      part = data.slice!(0,n)
      case format
      when :string
        return part
      when :integer
        return part.to_i(16)
      when :binary
        bytes = n/2
        return "%0#{bytes*8}b" %  part.to_i(16)
      end
    end

    def parse_address_type type
      case type.to_i(16).to_s(2)[1,3]
      when "001"
        :international
      when "010", "100", "000"
        :national
      when "101"
        :a7bit
      else
        raise DecodeError, "unknown address type: #{type}"
      end
    end

    def parse_address address, type, length
      if type == :a7bit
        address = decode7bit address
      else
        address = swapped2normal address
        if type == :international
          address.prepend "+"
        end
      end
      address
    end

    def parse_pdu_type pdu_type
      rp = pdu_type.slice!(0,1) == "1"
      udhi = pdu_type.slice!(0,1) == "1"
      srr_or_sri = pdu_type.slice!(0,1) == "1"
      vpf = (case pdu_type.slice!(0,2)
           when "00", "01"
             :none
           when "10"
             :relative
           when "11"
             :absolute
           end)
      rd_or_mms = pdu_type.slice!(0,1)
      mti = pdu_type.slice!(0,2)

      type = { rp: rp, udhi: udhi, vpf: vpf }
      case @direction
      when :sc_to_ms
        type[:mti] = case mti
                     when "00"
                       :sms_deliver
                     when "01"
                       :sms_submit_report
                     when "10"
                       :sms_status_report
                     when "11"
                       :reserved
                     end
        type[:sri] = srr_or_sri
        type[:mms] = rd_or_mms == "0"
      when :ms_to_sc
        type[:mti] = case mti
                     when "00"
                       :sms_deliver_report
                     when "01"
                       :sms_submit
                     when "10"
                       :sms_command
                     when "11"
                       :reserved
                     end
        type[:srr] = srr_or_sri
        type[:rd] = rd_or_mms == "0"
      end
      type
    end

    def parse_data_coding_scheme scheme
      {
        coding_group: scheme.slice!(0,2),
        compresion: scheme.slice!(0,1) == "1",
        klass_meaning: scheme.slice!(0,1) == "1",
        alphabet: ALPHABETS.key(scheme.slice!(0,2)),
        klass: scheme.slice!(0,2)
      }
    end

    def parse_7byte_timestamp timestamp
      year, month, day, hour, minute, second, zone = swapped2normal(timestamp).split('').in_groups_of(2).collect(&:join)
      d = "#{year}-#{month}-#{day} #{hour}:#{minute}:#{second} +%02d:00" % (zone.to_i / 4)
      Time.parse(d)
    end

    def parse_validity_period period
      case period
      when 0..143
        ((period + 1) * 5).minutes
      when 144..167
        12.hours + ((period - 143) * 30).minutes
      when 168..196
        (period - 166).days
      when 197..255
        (period - 192).weeks
      end
    end

    def parse_user_data data_length
      @offset_7bit = 1
      if @pdu_type[:udhi]
        @udh_length = take(2, :integer) * 2
        udh = take(@udh_length)
        @user_data_header = parse_user_data_header udh
      end
      case @data_coding_scheme[:alphabet]
      when :a7bit
        @message = gsm0338_to_utf8 decode7bit(@pdu_hex, @offset_7bit)
      when :a8bit
        @message = gsm0338_to_utf8 decode8bit(@pdu_hex, data_length)
      when :a16bit
        @message = gsm0338_to_utf8 decode16bit(@pdu_hex, data_length)
      end
    end

    def parse_user_data_header header
      iei = take 2, :string, header
      header_length = take 2, :integer, header
      case iei
      when "00"
        reference = take 2, :integer, header
        @offset_7bit = 0
      when "08"
        reference = take 4, :integer, header
        @offset_7bit = 1
      else
        binding.pry
        raise DecodeError, "unsupported Information Element Identifier in User Data Header: #{iei}"
      end
      parts = take 2, :integer, header
      part_number = take 2, :integer, header
      {
          reference: reference,
          parts: parts,
          part_number: part_number
      }
    end

    DecodeError = Class.new(StandardError)
  end
end