require 'final_cut_pro/xml_parser/common'
require 'final_cut_pro/xml_parser/xmeml/version_5'
require 'final_cut_pro/xml_parser/fcpxml/version_1'

module FinalCutPro
  class XMLParser
    class Document < Common

      def self.load(xml, options = { })
        doc = new(xml, options = { })
        return XMEML::Version5.new(doc.xml_document, options = { }) if doc.is_xmeml?
        return FCPXML::Version1.new(doc.xml_document, options = { }) if doc.is_fcpxml?
        return false
      end # self.load

    end # Document
  end # XMLParser
end # FinalCutPro