# https://developer.apple.com/library/mac/#documentation/FinalCutProX/Reference/FinalCutProXXMLFormat/FCPXMLDTDv1.1/FCPXMLDTDv1.1.html
require 'final_cut_pro/xml_parser/common'
module FinalCutPro
  class XMLParser
    class FCPXML
      class Version1 < FinalCutPro::XMLParser::Common

        def self.parse(xml, params = {})
          parser = new(xml)
          parser.parse(parser.xml_document, params)
        end # self.parse

        def parse(xml = @xml_document, options = { })
          @files = parse_files(xml, options)
          return self
        end # parse

        def parse_files(xml = @xml_document, options = { })
          xml.find('//asset').map do |asset_node|
            hash = xml_node_to_hash(asset_node)
            hash.merge!({ path_on_file_system: CGI::unescape(URI(hash[:src]).path) })
          end
        end # parse_files

      end # Version1
    end # FCPXML
  end # XMLParser
end # FinalCutPro