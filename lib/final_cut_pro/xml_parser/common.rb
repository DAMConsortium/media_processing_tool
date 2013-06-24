require 'axml'
require 'cgi'
require 'uri'
require 'final_cut_pro'

module FinalCutPro
  class XMLParser
    class Common

      attr_accessor :logger
      attr_accessor :sequences, :files

      def self.xml_as_document(xml, options = { })
        AXML.xml_as_document(xml)
      end # xml_as_document

      def initialize(xml, options = { })
        @logger = FinalCutPro.process_options_for_logger(options)
        @xml_document = xml_as_document(xml)
      end # initialize

      def xml_as_document(xml)
        self.class.xml_as_document(xml)
      end # xml_as_document

      def to_hash(keys_to_symbols = true)
        rt = keys_to_symbols ? root_type.to_sym : root_type
        { rt => xml_node_to_hash(root, keys_to_symbols) }
      end # to_hash

      def xml_node_to_hash(node, keys_to_symbols = true)
        # If we are at the root of the document, start the hash
        return node.content.to_s unless node.element?
        result_hash = {}

        # Add the attributes for the node to the hash
        node.each_attr { |a| a_name = keys_to_symbols ? a.name.to_sym : a.name; result_hash[a_name] = a.value }
        return result_hash.empty? ? nil : result_hash unless node.children?

        node.each_child do |child|
          result = xml_node_to_hash(child, keys_to_symbols)

          if child.name == 'text' or child.cdata?
            return result if !child.next? and !child.prev?
            next
          end

          begin
            key = keys_to_symbols ? child.name.to_sym : child.name
          rescue
            # FCP CDATA Fields usually fail to convert to a sym.
            logger.error { "Error Converting #{child.name} to symbol.\nCHILD: #{child.inspect}\nNODE: #{node}" }
            key = child.name
          end
          if result_hash[key]
            # We don't want to overwrite a value for an existing key so the value needs to be an array
            if result_hash[key].is_a?(Array)
              result_hash[key] << result
            else
              # Create an array
              result_hash[key] = [ result_hash[key], result ]
            end
          else
            result_hash[key] = result
          end
        end
        return result_hash
      end # xml_node_to_hash

      def xml_document
        @xml_document
      end # xml_document
      alias :xmldoc :xml_document

      def root
        xml_document.root
      end # root

      # Gets the
      def root_type
        @root_type ||= root.name
      end # type

      def is_xmeml?
        root_type == 'xmeml'
      end # is_xmeml?

      def is_fcpxml?
        root_type == 'fcpxml'
      end # is_fcpxml?


      # The fcpxml or xmeml version
      def version
        @version ||= root.attributes['version']
      end

      # The tag inside of the xmeml or fcpxml tag
      def top_level_container
        @top_level_container ||= root.children.first.name
      end #

      def is_clip?
        top_level_container == 'clip'
      end # is_clip?

      def is_project?
        top_level_container == 'project'
      end # is_project?

      def is_sequence?
        top_level_container == 'sequence'
      end # is_sequence?

      def sequences
        @sequences ||= xml_document.find('//sequence')
      end # sequences

    end
  end
end
