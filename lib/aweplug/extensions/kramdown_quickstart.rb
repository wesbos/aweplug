require 'pathname'
require 'kramdown'
require 'aweplug/helpers/git_commit_metadata'
require 'aweplug/helpers/kramdown_metadata'

module Aweplug
  module Extensions
    module Kramdown
      class Quickstart
        include Aweplug::Helper::Git::Commit::Metadata

        def initialize repository, layout
          @repo = repository
          @layout = layout
        end

        def execute site
          Dir["#{@repo}/**/README.md"].each do |file|
            page = add_to_site site, file

            metadata = extract_metadata(file)
            metadata[:commits] = commit_info @repo, Pathname.new(file)

            page.send 'metadata=', @metadata
            # TODO: Upload to DCP
          end
        end

        def extract_metadata(file)
          (Kramdown::Document.new File.readlines(file).join, :input => 'QuickStartParser').root.options[:metadata]
        end

        def add_to_site(site, file)
          page = site.engine.load_site_page file
          page.layout = @layout
          page
        end
      end
    end
  end
end
