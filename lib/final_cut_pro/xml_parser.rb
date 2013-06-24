require 'final_cut_pro/xml_parser/document'
module FinalCutPro
  class XMLParser

    def self.load(xml, options = { })
      return Document.load(xml, options = { })
    end # self.load

    def self.parse(xml, options = { })
      doc = load(xml, options)
      doc.parse
    end # self.parse

  end
end
