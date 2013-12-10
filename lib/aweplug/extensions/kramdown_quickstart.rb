require 'pathname'
require 'kramdown'
require 'aweplug/helpers/git_commit_metadata'
require 'aweplug/helpers/kramdown_metadata'

module Aweplug
  module Extensions
    module Kramdown
      class Quickstart
        include Aweplug::Helper::Git::Commit::Metadata

        def initialize repository, layout, output_dir
          @repo = repository
          @output_dir = Pathname.new output_dir
          @layout = layout
        end

        def execute site
          Dir["#{@repo}/**/README.md"].each do |file|
            page = add_to_site site, file

            metadata = extract_metadata(file)
            metadata[:commits] = commit_info @repo, Pathname.new(file)

            page.send 'metadata=', metadata
            # TODO: Upload to DCP
          end
        end

        def extract_metadata(file)
          document = (::Kramdown::Document.new File.readlines(file).join, :input => 'QuickStartParser')
          toc = ::Kramdown::Converter::Toc.convert(document.root)
          toc_items = toc[0].children.select { |el| el.value.options[:level] == 2 }.map do |t| 
            {:id => t.attr[:id], :text => t.value.children.first.value}
          end

          metadata = document.root.options[:metadata]
          metadata[:toc] = toc_items
          metadata
        end

        def add_to_site(site, file)
          page_path = Pathname.new file
          page = site.engine.load_site_page file
          page.layout = @layout
          page.output_path = File.join @output_dir, page_path.relative_path_from(Pathname.new @repo).dirname, 'index.html'
          site.pages << page
          page
        end
      end
    end
  end
end

