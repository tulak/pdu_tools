module PDUTools
  module Helpers
    GSM_03_38_ESCAPES = {
        "@" => "\x00",
        "$" => "\x02",
        "_" => "\x11",
        "^" => "\x1B\x14",
        "{" => "\x1B\x28",
        "}" => "\x1B\x29",
        "\\" => "\x1B\x2F",
        "[" => "\x1B\x3C",
        "~" => "\x1B\x3D",
        "]" => "\x1B\x3E",
        "|" => "\x1B\x40"
        # "\x80" => "\x1B\x65"
    }

    def utf8_to_gsm0338 string
      GSM_03_38_ESCAPES.each do |find, replace|
        string.gsub! find, replace
      end
      string
    end

    def gsm0338_to_utf8 string
      GSM_03_38_ESCAPES.each do |replace, find|
        string.gsub! find, replace
      end
      string
    end


    def dec2hexbyte dec
      "%02X" % dec
    end

    def encode7bit string, padding=0
      current_byte = 0
      offset = padding
      packed = []
      string.chars.to_a.each_with_index do |char, i|
        # cap off any excess bytes
        septet = char.ord & 0x7F
        # append the septet and then cap off excess bytes
        current_byte |= (septet << offset) & 0xFF
        offset += 7
        if offset > 7
          # the current byte is full, add it to the encoded data.
          packed << current_byte
          # shift left and append the left shifted septet to the current byte
          septet = septet >> (7 - (offset - 8 ))
          current_byte = septet
          # update offset
          offset -= 8
        end
      end
      packed << current_byte if offset > 0 # append the last byte
      packed.collect{|c| "%02X" % c }.join
    end

    def encode8bit string
      string.chars.to_a.collect do |char|
        "%04X" % char.ord
      end.join
    end

    def normal2swapped string
      string << "F" if string.length.odd?
      string.scan(/../).collect(&:reverse).join
    end

    def swapped2normal string
      string.scan(/../).collect(&:reverse).join.gsub(/F$/,'')
    end

    def decode7bit textdata, offset=1
      ret = ""
      bytes = []
      textdata.split('').each_slice(2) do |s|
        bytes << "%08b" % s.join.to_i(16)
      end

      cur_septet = ""
      next_septet = ""
      last_char = ""

      bytes.each_with_index do |byte, index|
        to_take = ([0,1].include? offset) ? 7 : 8-offset
        cur_septet.prepend byte[offset, to_take]
        next_septet = byte[0,offset] if offset > 0
        ret << cur_septet.to_i(2).chr

        if offset == 7
          offset = 1
          ret << next_septet.to_i(2).chr
          cur_septet = ""
        else
          offset += 1
          cur_septet = next_septet
        end
        next_septet = nil
      end
      ret
    end

    def decode8bit data, length
      octets = data.split('').in_groups_of(2).collect(&:join)[0, length]
      octets.collect do |o|
        o.to_i(16).chr
      end.join
    end

    def decode16bit data, length
      dobule_octets = data.split('').in_groups_of(4).collect(&:join)[0, length/2]
      dobule_octets.collect do |o|
        [o.to_i(16)].pack("U")
      end.join
    end
  end
end
