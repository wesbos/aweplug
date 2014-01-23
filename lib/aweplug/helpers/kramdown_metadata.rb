require 'kramdown'
require 'kramdown/parser/kramdown'

module Kramdown
  module Parser
    # Public: A Kramdown parser specific for the JBoss Quickstart format. See
    # http://kramdown.gettalong.org/parser/kramdown.html for more information.
    class QuickStartParser < Kramdown::Parser::Kramdown

      # Private: Initializer for the Parser.
      #
      # source  - String source of the document.
      # options - Hash of options, see 
      #           http://kramdown.gettalong.org/parser/kramdown.html for list
      #           of supported options.
      def initialize source, options
        super
        @block_parsers.unshift :author_metadata
        @block_parsers.unshift :level_metadata
        @block_parsers.unshift :technologies_metadata
        @block_parsers.unshift :target_product_metadata
        @block_parsers.unshift :source_metadata
        @block_parsers.unshift :summary_metadata
        @block_parsers.unshift :product_metadata
        @block_parsers.unshift :title_hack_metadata

        @root.options[:metadata] = {:author => '', :level => '',
                                    :technologies => '', :target_product => '',
                                    :source => '', :summary => ''}
      end

      HEADER_ID=/(?:[ \t]+\{#([A-Za-z][\w:-]*)\})?/
      SETEXT_HEADER_START = /^(#{OPT_SPACE}[^ \t].*?)#{HEADER_ID}[ \t]*?\n(=)+\s*?\n/

      # Internal: Parses the title to add to the metadata Hash.
      def parse_title_hack_metadata 
        return false if !after_block_boundary?

        #start_line_number = @src.current_line_number
        @src.pos += @src.matched_size
        text, id, _ = @src[1], @src[2], @src[3]
        text.strip!
        el = new_block_el(:header, nil, nil, :level => 1, :raw_text => text, :location => 1)
        add_text(text, el)
        el.attr['id'] = id if id
        
        @root.options[:metadata][:title] = text
        #@tree.children << el
        true
      end
      define_parser(:title_hack_metadata, SETEXT_HEADER_START)

      # Internal: Parses the author to add to the metadata Hash.
      def parse_author_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:author] = @src[2].rstrip
      end
      define_parser(:author_metadata, /^(Author:)#{OPT_SPACE}(.*?)\s*?\n/)

      # Internal: Parses the level to add to the metadata Hash.
      def parse_level_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:level] = @src[2].rstrip
      end
      define_parser(:level_metadata, /^(Level:)#{OPT_SPACE}(.*?)\s*?\n/)

      # Internal: Parses the technologies to add to the metadata Hash.
      def parse_technologies_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:technologies] = @src[2].rstrip
      end
      define_parser(:technologies_metadata, /^(Technologies:)#{OPT_SPACE}(.*?)\s*?\n/)

      # Internal: Parses the target_product to add to the metadata Hash.
      def parse_target_product_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:target_product] = @src[2].rstrip
      end
      define_parser(:target_product_metadata, /^(Target Product:)#{OPT_SPACE}(.*?)\s*?\n/)

      # Internal: Parses the source URL to add to the metadata Hash.
      def parse_source_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:source] = @src[2][1..-2].rstrip
      end
      define_parser(:source_metadata, /^(Source:)#{OPT_SPACE}(.*?)\s*?\n/)

      # Internal: Parses the summary to add to the metadata Hash.
      def parse_summary_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:summary] = @src[2].rstrip
      end
      define_parser(:summary_metadata, /^(Summary:)#{OPT_SPACE}(.*?)\s*?\n/)

      # Internal: Parses the product to add to the metadata Hash.
      def parse_product_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:product] = @src[2].rstrip
      end
      define_parser(:product_metadata, /^(Product Versions:)#{OPT_SPACE}(.*?)\s*?\n/)
    end
  end
end
