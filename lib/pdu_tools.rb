require 'phone'
require 'active_support/all'

require_relative './pdu_tools/helpers'
require_relative './pdu_tools/pdu'
require_relative './pdu_tools/message_part'
require_relative './pdu_tools/decoder'
require_relative './pdu_tools/encoder'

module PDUTools
  ALPHABETS = {
      a7bit: '00',
      a8bit: '01',
      a16bit: '10'
  }

  MAX_MESSAGE_LENGTH = 39015
  MAX_GSM_MESSAGE_7BIT_PART_LENGTH = 152
  MAX_GSM_MESSAGE_16BIT_PART_LENGTH = 66
end
