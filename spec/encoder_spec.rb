# encoding: utf-8
require 'spec_helper'

describe PDUTools::Encoder do
  let(:recipient) { "+421 900 100 100" }
  let(:encoder) { PDUTools::Encoder.new recipient: recipient, message: message }
  context "short" do
    context "7bit text" do
      let(:message) { "This is a test message" }
      it "should encode pdu" do
        pdus = encoder.encode
        expect(pdus.size).to eq(1)
      end
    end

    context "16bit text" do
      let(:message) { "This is diacritics ľščťžýáíäúôň" }
      it "should encode pdu" do
        pdus = encoder.encode
        expect(pdus.size).to eq(1)
      end
    end
  end

  context "lonh" do
    context "7bit text" do
      let(:message) { "This is a test message" * 10 }
      it "should encode pdu" do
        pdus = encoder.encode
        expect(pdus.size).to eq(2)
      end
    end

    context "16bit text" do
      let(:message) { "This is diacritics ľščťžýáíäúôň" * 3 }
      it "should encode pdu" do
        pdus = encoder.encode
        expect(pdus.size).to eq(2)
      end
    end
  end
end