pdu_tools
=========

Tools for encoding and decoding GSM SMS PDUs.

Usage
=====

Encoding SMS message
```
encoder = PDUTools::Encoder.new recipient: "+421910100100", message: "This is a message"
pdus = encoder.encode # => [#<PDUTools::PDU:0x007fd5a4a1d908 @pdu_hex="0001000C9124910101100000001154747A0E4ACF416150BB3C9F87CF65">]
```
in `pdus` variable is array of PDUs, if the message is too long it is separated to multiple PDUs.

Decoding SMS message
```
decoder = PDUTools::Decoder.new "0001000C9124910101100000001154747A0E4ACF416150BB3C9F87CF65", :ms_to_sc
message_part = decoder.decode # => #<PDUTools::MessagePart:0x007fd5a503a9f8 @address="+421910100100", @body="This is a message", @timestamp=nil, @validity_period=nil, @user_data_header=nil>
```
in `message_part` variable is now MessagePart object which contains information extracted from the PDU, you can check if the message is complete using `message_part.complete?` to see if message was separated in multiple PDUs using User Data Header.

There is difference when PDU is comming from MS(Mobile Station) to SC(Service Center) or reverse. You need to specify the direction of PDU in decoder's second parameter: `:ms_to_sc` or `:sc_to_ms`.

This tool was build with help of this [document](http://read.pudn.com/downloads150/sourcecode/embed/646395/Short%20Message%20in%20PDU%20Encoding.pdf)

Features
========
 * Encoding 7 bit and 16 bit characters
 * Decoding 7 bit, 8 bit and 16 bit characters
 * Encoding and decoding User Data Header - used for concatenating SMS messages
