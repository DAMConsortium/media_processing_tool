require 'axml'

module MediaProcessingTool

  class XMLParser

    class Document

      def self.xml_as_document(xml, params = {})
        AXML.xml_as_document(xml)
      end # self.xml_as_document

      def self.load(xml, params = { })
        new(xml, params)
      end # self.load

      def initialize(xml, params = { })
        @xml_document = self.class.xml_as_document(xml, params)
      end # initialize

      def xml_document
        @xml_document
      end # xml_document

      def root
        xml_document.root
      end # root

      # Gets the
      def root_type
        @root_type ||= root.name
      end # type

    end # Document

  end # XMLParser

end # MediaProcessingTool