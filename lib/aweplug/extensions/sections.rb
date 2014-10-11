require 'parallel'
require 'asciidoctor'
require 'awestruct/handlers/interpolation_handler'

module Aweplug
  module Extensions
    # Public: Parses (AsciiDoc files currently) and pulls out h2 sections
    # (and their contents), setting them as first class page variables.
    #
    # Examples
    #
    # extension Awestruct::Extensions::Sections.new
    class Sections
      # Internal: Looks for all AsciiDoc files and pulls out the sections,
      # adding them to the page variable.
      #
      # site - The awestruct site variable
      def execute site 
        Parallel.each(site.pages, :in_threads => 10) do |page|
          if page.content_syntax =~ /^a(sc)?(ii)?(d(oc)?)?$/
            sections = Asciidoctor.load(interpolated_content(page), {sectanchors: ''}).sections
            sections.each do |s|
              r = String.new
              s.blocks.each {|b| r << b.render}
              page.send "#{s.id}=", r
            end
          end
        end
      end

      private

      # Private: Retreives the interpolated content if the InterpolationHandler
      # is in the handler chain.
      #
      # page - Awestruct Page object.
      #
      # Returns either the raw content for the page, or the interpolated
      # content.
      def interpolated_content page 
        handler = page.handler

        until (handler.nil?)
          handler = handler.delegate
          if handler.class == ::Awestruct::Handlers::InterpolationHandler
            return handler.rendered_content page.create_context(page.raw_content)
          end
        end
        page.raw_content
      end
    end
  end
end
