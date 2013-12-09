require 'kramdown'
require 'kramdown/parser/kramdown'

module Kramdown
  module Parser
    class QuickStartParser < Kramdown::Parser::Kramdown
      def initialize source, options
        super
        @block_parsers.unshift :author_metadata
        @block_parsers.unshift :level_metadata
        @block_parsers.unshift :technologies_metadata
        @block_parsers.unshift :target_product_metadata
        @block_parsers.unshift :source_metadata
        @block_parsers.unshift :summary_metadata

        @root.options[:metadata] = {:author => '', :level => '',
                                    :technologies => '', :target_product => '',
                                    :source => '', :summary => ''}
      end

      def parse_author_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:author] = @src[3]
      end
      define_parser(:author_metadata, /^(Author:)(\s+)(.*?)$/)

      def parse_level_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:level] = @src[3]
      end
      define_parser(:level_metadata, /^(Level:)(\s+)(.*?)$/)

      def parse_technologies_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:technologies] = @src[3]
      end
      define_parser(:technologies_metadata, /^(Technologies:)(\s+)(.*?)$/)

      def parse_target_product_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:target_product] = @src[3]
      end
      define_parser(:target_product_metadata, /^(Target Product:)(\s+)(.*?)$/)

      def parse_source_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:source] = @src[3][1..-2]
      end
      define_parser(:source_metadata, /^(Source:)(\s+)(.*?)$/)

      def parse_summary_metadata
        @src.pos += @src.matched_size
        @root.options[:metadata][:summary] = @src[3]
      end
      define_parser(:summary_metadata, /^(Summary:)(\s+)(.*?)$/)
    end
  end
end
