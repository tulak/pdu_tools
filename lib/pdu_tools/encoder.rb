module PDUTools
  class Encoder
    include Helpers

    DEFAULT_OPTIONS = {
        klass: nil,
        require_receipt: false,
        expiry_seconds: nil
    }

    MessagePart = Struct.new(:data, :length)

    # PDU structure - http://read.pudn.com/downloads150/sourcecode/embed/646395/Short%20Message%20in%20PDU%20Encoding.pdf
    # X Bytes - SMSC - Service Center Address
    # 1 Byte  - Flags / PDU Type
    #     - 1 bit  Reply Path parameter indicator
    #     - 1 bit  User Data Header Indicator
    #     - 1 bit  Status Request Report
    #     - 2 bits Validity Period Format
    #     - 1 bit  Reject Duplicates
    #     - 2 bits Message Type Indicator
    # 2 Bytes - Message Reference
    # X Bytes - Address length and address
    # 1 Byte  - Protocol identificator (PID)
    # 1 Byte  - Data Coding Scheme
    # X Bytes - Validity Period
    # 1 Byte  - User Data Length
    # X Bytes - User Data

    def initialize options
      raise ArgumentError, :recipient unless options[:recipient]
      raise ArgumentError, :message unless options[:message]
      @options = DEFAULT_OPTIONS.merge options

      @smsc = '00' # Phone Specified
      @message_parts, @alphabet = prepare_message options[:message]
      @pdu_type = pdu_type @concatenated_message_reference, options[:require_receipt], options[:expiry_seconds]
      @message_reference = '00' # Phone Specified
      @address = prepare_recipient options[:recipient]
      @protocol_identifier = '00' # SMS
      @data_coding_scheme = data_coding_scheme options[:klass], @alphabet
      @validity_period = validity_period options[:expiry_seconds]
    end

    def encode
      head = ""
      head << @smsc
      head << @pdu_type
      head << @message_reference
      head << @address
      head << @protocol_identifier
      head << @data_coding_scheme
      head << @validity_period
      pdus = []
      @message_parts.each do |part|
        pdus << PDU.new(head + part.length + part.data)
      end
      pdus
    end

    private
    def prepare_message message
      if message.ascii_only?
        # parts = message.scan(/.{1,#{MAX_GSM_MESSAGE_7BIT_PART_LENGTH}}/)
        parts = message.split('').in_groups_of(MAX_GSM_MESSAGE_7BIT_PART_LENGTH).collect(&:join)
        message_parts = []
        parts.each_with_index do |part, i|
          part_gsm0338 = utf8_to_gsm0338 part
          part_7bit = encode7bit(part_gsm0338)
          udh = user_data_header parts.size, i+1
          udh_length = (udh.present? ? (udh.length / 2) + 1 : 0)
          part_length = "%02X" % (part_gsm0338.length + udh_length)
          message_parts << MessagePart.new((udh + part_7bit), part_length)
        end
        [message_parts, :a7bit]
      else
        parts = message.split('').in_groups_of(MAX_GSM_MESSAGE_16BIT_PART_LENGTH).collect(&:join)
        message_parts = []
        parts.each_with_index do |part, i|
          part_8bit = encode8bit(part)
          udh = user_data_header parts.size, i+1
          part_length = "%02X" % ((udh + part_8bit).length / 2)
          message_parts << MessagePart.new((udh + part_8bit), part_length)
        end
        [message_parts, :a16bit]
      end
    end

    # http://en.wikipedia.org/wiki/Concatenated_SMS#Sending_a_concatenated_SMS_using_a_User_Data_Header
    def user_data_header parts_count, part_number
      return '' if parts_count == 1
      @concatenated_message_reference ||= rand((2**16)-1)
      udh =  '06' # Length of User Data Header
      udh << '08' # Concatenated short messages, 16-bit reference number
      udh << '04' # Length of the header, excluding the first two fields
      udh << "%04X" % @concatenated_message_reference
      udh << "%02X" % parts_count
      udh << "%02X" % part_number
      udh
    end

    def prepare_recipient recipient
      Phoner::Phone.default_country_code ||= "421"
      address_type = "91" # International
      address = Phoner::Phone.parse(recipient).format("%c%a%n")
      address_length = "%02X" % address.length
      address_encoded = normal2swapped address
      address_length + address_type + address_encoded
    end

    def data_coding_scheme klass, alphabet
      if klass
        klass_meaning = '1'
        klass = ("%02b" % klass)[-2,2]
      else
        klass_meaning = '0'
        klass = '00'
      end

      scheme_bin = ""
      scheme_bin << '00'                # 2 bits - coding_group
      scheme_bin << '0'                 # 1 bit  - compression
      scheme_bin << klass_meaning       # 1 bit  - klass meaning flag
      scheme_bin << ALPHABETS[alphabet] # 2 bits - alphabet
      scheme_bin << klass               # 2 bits - klass

      data_coding_scheme_dec = scheme_bin.to_i(2)
      dec2hexbyte data_coding_scheme_dec
    end

    def pdu_type uhdi, srr, vpf
      reply_path = '0'
      uhdi_flag = (uhdi ? '1' : '0') # User Data Header indicator
      srr_flag = (srr ? '1' : '0')   # Status Request Report
      vpf_flag = (vpf ? '10' : '00') # Validity Period Format
      rj = '0'                       # Reject Duplicates
      mti = '01'                     # Message Type Indicator (SMS-SUBMIT)
      first_octet_dec = (reply_path + uhdi_flag + srr_flag + vpf_flag + rj + mti).to_i(2)
      dec2hexbyte first_octet_dec
    end

    def validity_period expiry_seconds
      return '' unless expiry_seconds
      raise ArgumentError, "Expiry must be at least 300 seconds (5 minutes)" if expiry_seconds < 5.minutes
      validity_period_dec = case expiry_seconds
                            when 5.minutes..12.hours
                              (expiry_seconds / 5.minutes) - 1
                            when 12.hours..24.hours
                              ((expiry_seconds - 12.hours) / 5.minutes) + 143
                            when 24.hours..30.days
                              (expiry_seconds / 24.hours) + 166
                            when 30.days..63.weeks
                              (expiry_seconds / 1.week) + 192
                            else
                              raise ArgumentError, "Expiry must be 38102400 seconds (63 weeks) or less"
                            end
      dec2hexbyte validity_period_dec.ceil
    end
  end
end