begin
  require 'libxml'
  XML_PARSER ||= :libxml
rescue LoadError
  require 'rexml/document'
  XML_PARSER ||= :rexml
end

# Abstracted XML Module
module AXML

  module REXMLAbstraction
    class << self
      def self.xml_as_document(xml)
        if xml.is_a?(String)
          xml_clean = xml.chomp.strip.chomp
          unless xml_clean.start_with?('<')
            file_name = File.expand_path(xml)
            xml_document = REXML::Document.new(File.new(file_name)) if !file_name.start_with?('<') and File.exists?(file_name)
          end
          xml_document ||= REXML::Document.new(xml)
        else
          xml_document = xml
        end
        xml_document
      end # xml_as_document
    end # self
  end # Module_REXML

  module LibXMLAbstraction

    def self.xml_as_document(xml)
      if xml.is_a?(String)
        xml_clean = xml.chomp.strip.chomp
        unless xml_clean.start_with?('<')
          file_name = File.expand_path(xml)
          xml_document = LibXML::XML::Document.file(file_name) if File.exists?(file_name)
        end
        xml_document ||= LibXML::XML::Document.string(xml)
      else
        xml_document = xml
      end
      xml_document
    end # xml_as_document

  end # ModuleLibXML

  if XML_PARSER == :libxml
    #puts 'Including LibXML'
    include LibXMLAbstraction
  else
    #puts 'Including REXML'
    include REXMLAbstraction
  end

  # Force LibXML Usage
  def self.xml_as_document(xml); LibXMLAbstraction.xml_as_document(xml); end # self.xml_as_document

end # AXML