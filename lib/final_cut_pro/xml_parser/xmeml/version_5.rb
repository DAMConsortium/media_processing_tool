# http://developer.apple.com/library/mac/#documentation/AppleApplications/Reference/FinalCutPro_XML/DTD/DTD.html#//apple_ref/doc/uid/TP30001157-BCIHDFGD
require 'final_cut_pro/xml_parser/common'
module FinalCutPro
  class XMLParser
    class XMEML
      class Version5 < FinalCutPro::XMLParser::Common

        def self.parse_clips(xml, options = { })
          parser = new
          parser.parse_clips(xml_as_document(xml, options))
        end # self.parse_clips

        def self.parse_sequences(xml, options = { })
          parser = new
          parser.parse_sequences(xml_as_document(xml, options))
        end # self.parse_sequences

        def self.parse_files(xml, options = { })
          parser = new
          parser.parse_files(xml, options)
        end # self.parse_files

        def get_project_name(node)
          #@project_name = node.find('ancestor::project').first.find('./name').first.content.to_s
          project_node = node.find_first('ancestor::project')
          unless project_node.nil?
            project_name_node = project_node.find_first('./name')
            unless project_name_node.nil? or project_name_node.content.nil?
              project_name = project_name_node.content.to_s
              return project_name
            end
          end
        end

        def get_bin_path(node)
          bin_path = []
          node.find('ancestor::bin').each do |ancestor_node|
            bin_path << ancestor_node.find('./name').first.content.to_s unless ancestor_node.find('./name').first.content.to_s.empty?
          end
          return '' if bin_path.empty?
          return ("/" + bin_path.join("/") + "/").to_s
        end

        def get_clip_hash_by_id(doc, id)
          #puts "ID: #{id}"
          id = id.dup
          id.gsub!(/["\s]/, ' ' => "\\s", '"' => '&quot;')
          clip = doc.find("//clip[@id=\"#{id}\"]").first
          return { } unless clip
          return xml_node_to_hash(clip) || { }
        end

        def get_clipitem_hash(node)
          return xml_node_to_hash(node.parent)
        end

        def get_file_clipitems(node, file_id = nil)

        end

        def get_all_metadata(node)
          metadata = {}
          node.find('descendant::metadata|metadata').each do |metadata_node|
            metadata[metadata_node.find('./key').first.content.to_s] = metadata_node.find('./value').first.content.to_s unless metadata_node.find('./key').first.nil? or metadata_node.find('./key').first.empty? or  metadata_node.find('./value').first.nil? or  metadata_node.find('./value').first.empty?
          end
          return metadata
        end

        def get_all_labels(node)
          labels = []
          node.find('ancestor::bin/labels|ancestor::clip/labels|ancestor::sequence/labels|ancestor::clipitem/labels|ancestor::generatoritem/labels').each do |labels_node|
            label_set = {}
            label_set[:from] = {labels_node.parent.name.to_s => labels_node.parent.find('./name|@id').first.value.to_s}
            label_set[:labels] = []
            labels_node.find('./*').each do |label_node_item|
              label_set[:labels] << {label_node_item.name.to_s => label_node_item.content.to_s} unless label_node_item.content.nil? or label_node_item.content.empty?
            end
            labels << label_set
          end
          return labels
        end

        def get_all_comments(node)
          comments = []
          node.find('ancestor::bin/comments|ancestor::clip/comments|ancestor::sequence/comments|ancestor::clipitem/comments|ancestor::generatoritem/comments').each do |comments_node|
            parent = comments_node.parent
            comment_ids = parent.find('./name|@id')
            first_comment_id = comment_ids.first

            # Name field responds to .content where as id attribute value is found with .value
            comment_name_or_id = first_comment_id.respond_to?(:content) ? first_comment_id.content : first_comment_id.value

            comment_set = {}
            comment_set[:from] = comment_name_or_id # {parent.name.to_s => parent.find('./name|@id').first.value.to_s}
            comment_set[:comments] = []
            comments_node.find('./*').each do |comment_node_item|
              comment_set[:comments] << {comment_node_item.name.to_s => comment_node_item.content.to_s} unless comment_node_item.content.nil? or comment_node_item.content.empty?
            end
            comments << comment_set
          end
          return comments
        end

        def get_logging_info(node)
          logginginfos = []
          node.find('ancestor::clip/logginginfo|ancestor::sequence/logginginfo|ancestor::clipitem/logginginfo|ancestor::generatoritem/logginginfo').each do |logginginfo_node|
            logginginfo_set = {}
            logginginfo_set[:from] = {logginginfo_node.parent.name.to_s => logginginfo_node.parent.find('./name|@id').first.value.to_s}
            logginginfo_set[:logginginfo] = {}
            logginginfo_node.find('./*').each do |logginginfo_node_item|
              logginginfo_set[:logginginfo][logginginfo_node_item.name.to_s] = logginginfo_node_item.content.to_s unless logginginfo_node_item.content.nil? or logginginfo_node_item.content.empty?
            end
            logginginfos << logginginfo_set
          end
          return logginginfos
        end

        def get_files_as_nodes(doc)
          doc.find('//file[pathurl]')
        end # get_files_as_nodes

        def build_file_hash_hash(params = {})
          _files = { }
          key = params[:key_on] || :id
          files_array = build_file_hash_array(@xml_document)
          files_array.each {|file| _files[file[key]] = file }
          _files
        end # build_file_hash_hash

        def build_file_hash_array(doc, options = { })
          _files = []

          nodes = get_files_as_nodes(doc)
          total_files = nodes.count

          counter = 0

          nodes.each do |node|
            counter += 1
            logger.debug { "Processing file #{counter} of #{total_files}" }
            file_hash = build_file_hash(node)
            next unless file_hash
            logger.debug { "file_hash => #{file_hash}" }
            _files << file_hash
          end

          return _files
        end

        def build_file_hash(node)
          file_id = node.attributes.get_attribute('id').value.to_s
          logger.debug { "Processing File with an ID of: #{file_id}" }

          path_url_element = node.find('./pathurl').first
          unless !path_url_element.nil?
            logger.debug { 'Skipping File Node. No pathurl attribute found.' }
            return false
          end

          file_name = node.find('./name').first.content.to_s # Should equal the base name from the path url
          file_path_url = path_url_element.content.to_s
          file_hash = {
            :id => file_id,
            :name => file_name,
            :path_url => file_path_url
          }

          # a plus (+) would be converted to a space using CGI.unescape so we only escape %## encoded values from the pathurl
          #file_hash[:path_on_file_system] = CGI::unescape(URI(file_hash[:path_url]).path)
          file_hash[:path_on_file_system] = URI(file_path_url).path.gsub(/(%(?:[2-9]|[A-F])(?:\d|[A-F]))/) { |v| CGI.unescape(v) }
          file_hash[:file_node_full] = xml_node_to_hash node
          file_hash[:project_name] = get_project_name node
          file_hash[:bin_path] = get_bin_path node
          file_hash[:clipitem_node_full] = get_clipitem_hash node

          file_hash[:clipitems] = get_file_clipitems(node, file_id)

          master_clip_id = file_hash[:clipitem_node_full][:masterclipid]
          file_hash[:masterclip_node_full] = (master_clip_id.nil? or master_clip_id.empty?) ? { } : get_clip_hash_by_id(node.doc, master_clip_id)
          file_hash[:metadata] = get_all_metadata node
          file_hash[:labels] = get_all_labels node
          file_hash[:comments] = get_all_comments node
          file_hash[:logginginfo] = get_logging_info node
          file_hash
        end

        def parse(xml = @xml_document, options = { })
          xml_doc = self.class.xml_as_document(xml)
          @files = parse_files(xml_doc, options)
          @sequences = parse_sequences(xml_doc, options)
          @clips = parse_clips(xml_doc)
          return self
        end # parse

        def parse_files(xml = @xml_document, options = { })
          build_file_hash_array(self.class.xml_as_document(xml), options = { }) || [ ]
        end # parse_files

        def parse_clips(xml = @xml_document, options = { })
          self.class.xml_as_document(xml).find('//clip').map do |clip_node|
            # 'clipitem[(not(enabled) or enabled[text()="TRUE"]) and ancestor::video/track[enabled[text()="TRUE"]]]'
            # enabled tag may be missing on some clipitems such as those that link to other clipitems. This could cause a problem following links.
            clip_items = clip_node.find('clipitem[(not(enabled) or enabled[text()="TRUE"]) and ../../../../media/video/track[enabled[text()="TRUE"]]]').map do |clip_item_node|
              xml_node_to_hash(clip_item_node)
            end
            xml_node_to_hash(clip_node).merge({ :clip_items => clip_items })
          end
        end # parse_clips

        def parse_sequences(xml = @xml_document, options = { })
          self.class.xml_as_document(xml).find('//sequence').map do |sequence_node|
            clip_items = sequence_node.find('media/video/track/clipitem[not(enabled) or enabled[text()="TRUE"]]').map do |clip_item_node|
              xml_node_to_hash(clip_item_node)
            end
            xml_node_to_hash(sequence_node).merge({ :clip_items => clip_items })
          end
        end # parse_sequences

      end # Version5
    end # XMEML
  end # XMLParser
end # FinalCutPro