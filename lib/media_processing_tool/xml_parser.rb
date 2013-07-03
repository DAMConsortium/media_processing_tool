require 'media_processing_tool/xml_parser/identifier'
require 'final_cut_pro/xml_parser'
require 'itunes/xml_parser'
module MediaProcessingTool

  class XMLParser

    # Gives access to the last document returned by the Identifier
    # This gives access to the identifiers instance parameters (such determined type) for use later
    def self.identifier_document
      @identifier_document
    end # self.identifier_document

    def self.parse(xml, params = { })
      @identifier_document = Identifier.load(xml, params)

      case @identifier_document.type
      when :final_cut_pro
        doc = FinalCutPro::XMLParser.parse(@identifier_document.xml_document, params)
      when :itunes
        doc = ITunes::XMLParser.parse(xml, params)
      else
        doc = @identifier_document
      end
      doc
    end # self.parse

  end # XMLParser

end # MediaProcessingTool