require 'media_processing_tool/xml_parser/document'
module MediaProcessingTool

  class XMLParser

    class Identifier < Document

      def initialize(xml, params = { })
        super(xml, params)
      end # initialize

      def is_fcpxml?
        root_type == 'fcpxml'
      end # is_fcpxml?

      def is_xmeml?
        root_type == 'xmeml'
      end # is_xmeml?

      def is_plist?
        root_type == 'plist'
      end # is_plist?

      def is_final_cut_pro?
        is_xmeml? || is_fcpxml?
      end # is_final_cut_pro?

      def is_itunes?
        is_plist? and !xml_document.find('/plist/dict/key[text()="Tracks"]').empty?
      end # is_itunes?

      def type
        return :final_cut_pro if is_final_cut_pro?
        return :itunes if is_itunes?
        return :plist if is_plist?
        return :unknown
      end # source_application

    end # Identifier

  end # XMLParser

end # MediaProcessingTool
