require 'pathname'
require 'set'
require 'json'

require 'kramdown'
require 'aweplug/helpers/git_metadata'
require 'aweplug/helpers/kramdown_metadata'
require 'aweplug/helpers/searchisko'
require 'json'
require 'parallel'

module Aweplug
  module Extensions
    module Kramdown
      # Public: An awestruct extension for guides / examples written in AsciiDoc.
      #         Files with the .asciidoc or .adoc extension are considered to be
      #         AsciiDoc files. This extension makes use of asciidoctor to 
      #         render the files. This makes use of the 
      #         Aweplug::Helper::Searchisko class, please see that class for 
      #         more info on options and settings for Searchisko.
      #
      # Example
      #
      #   extension Aweplug::Extensions::AsciidocExample({...})
      class Quickstart
        include Aweplug::Helper::Git::Commit::Metadata
        include Aweplug::Helper::Git::Repository

        # Public: Initialization method, used in the awestruct pipeline.
        #
        # opts - A Hash of options, some being required, some not (default: {}). 
        #        :repository         - The String name of the directory containing 
        #                              the repository (required).
        #        :layout             - The String name of the layout to use, 
        #                              omitting the extension (required).
        #        :output_dir         - The String or Pathname of the output 
        #                              directory for the files (required).
        #        :site_variable      - String name of the key within the site
        #                              containing additional metadata about 
        #                              the guide (default: value of 
        #                              :output_dir).
        #        :excludes           - Array of Strings containing additional 
        #                              directory names to exclude. Defaults to [].
        #        :push_to_searchisko - A boolean controlling whether a push to
        #                              seachisko should happen. A push will not
        #                              happen when the development profile is in
        #                              use, regardless of the value of this 
        #                              option.
        # Returns the created extension.
        def initialize opts = {}
          required_keys = [:repository, :layout, :output_dir]
          missing_required_keys = required_keys - opts.keys

          raise ArgumentError.new "Missing required arguments #{missing_required_keys.join ', '}" unless missing_required_keys.empty?
          @repo = opts[:repository]
          @output_dir = Pathname.new opts[:output_dir]
          @layout = opts[:layout]
          @site_variable = opts[:site_variable] || opts[:output_dir]
          @excludes = opts[:excludes] || []
          @push_to_searchisko = opts[:push_to_searchisko] || true
          @product = opts[:product]
        end

        # Internal: Execute method required by awestruct. Called during the
        # pipeline execution. No return.
        #
        # site - The Site instance from awestruct.
        #
        # Returns nothing.
        def execute site
          if site.cache.nil?
            site.send('cache=', Aweplug::Cache::YamlFileCache.new)
          end
          # Not sure if it's better to do this once per class, 
          # once per site, or once per invocation
          searchisko = Aweplug::Helpers::Searchisko.new({:base_url => site.dcp_base_url, 
                                                         :authenticate => true, 
                                                         :searchisko_username => ENV['dcp_user'], 
                                                         :searchisko_password => ENV['dcp_password'], 
                                                         :cache => site.cache,
                                                         :logger => site.log_faraday})
          Parallel.each(Dir["#{@repo}/*/README.md"], in_threads: 20) do |file|
            next if @excludes.include?(File.dirname(file))

            # Skip if the site already has this page
            output_path = File.join @output_dir, Pathname.new(file).relative_path_from(Pathname.new @repo).dirname, 'index.html' 
            next if site.pages.find {|p| p.output_path == output_path}

            page = add_to_site site, file

            metadata = extract_metadata(file)
            metadata[:commits] = commit_info @repo, Pathname.new(file)
            metadata[:current_tag] = current_tag @repo, Pathname.new(file)
            metadata[:current_branch] = current_branch @repo, Pathname.new(file)
            metadata[:github_repo_url] = repository_url @repo
            metadata[:contributors] = metadata[:commits].collect { |c| c[:author] }.uniq
            metadata[:contributors_email] = metadata[:commits].collect { |c| c[:author_email] }.uniq
            metadata[:contributors].delete(metadata[:author])
            metadata[:product] = @product if @product
            metadata[:searchisko_id] = Digest::SHA1.hexdigest(metadata[:title])[0..7]
            metadata[:searchisko_type] = 'jbossdeveloper_quickstart'
            converted_html = metadata.delete :converted

            unless metadata[:images].empty?
              metadata[:images].each do |img|
                image_path = Pathname.new(@repo).join(img) 
                add_image_to_site(site, image_path) if File.exist? image_path
              end
            end
            
            searchisko_hash = 
            {
              :sys_title => metadata[:title], 
              :level => metadata[:level],
              :tags => metadata[:technologies],
              :sys_description => metadata[:summary],
              :sys_content => converted_html, 
              :sys_url_view => "#{site.base_url}#{site.ctx_root.nil? ? '/' : '/' + site.ctx_root + '/'}#{page.output_path}",
              :contributors => metadata[:contributors_email],
              :author => metadata[:author],
              :sys_created => metadata[:commits].collect { |c| DateTime.parse c[:date] }.last,
              :sys_activity_dates => metadata[:commits].collect { |c| DateTime.parse c[:date] },
              :target_product => metadata[:target_product],
              :github_repo_url => metadata[:github_repo_url]
            } 


            unless !@push_to_searchisko || site.profile =~ /development/
              searchisko.push_content(metadata[:searchisko_type], 
                metadata[:searchisko_id], 
                searchisko_hash.to_json)
            end

            page.send 'metadata=', metadata
          end
          # Add the main readme
          if File.exist? "#{@repo}/README.md"
            index = add_to_site site, "#{@repo}/README.md"
            metadata = extract_metadata("#{@repo}/README.md")
            index.send 'metadata=', metadata
          end
          # Add the contributing
          if File.exist? "#{@repo}/CONTRIBUTING.md"
            contribute = add_to_site site, "#{@repo}/CONTRIBUTING.md"
            metadata = extract_metadata("#{@repo}/CONTRIBUTING.md")

            # Little bit of C&P to change the  output path, probably a better way
            page_path = Pathname.new "#{@repo}/CONTRIBUTING.md"
            contribute.output_path = File.join @output_dir, page_path.relative_path_from(Pathname.new @repo).dirname, 'contributing', 'index.html'
            contribute.send 'metadata=', metadata
          end
        end


        private

        # Private: Makes use of the sepcial Kramdown parser in aweplug to pull 
        # out metadata from the README files.
        # 
        # file - The String file path (relative or absolute) to parse.
        #
        # Returns a Hash of the metadata retrieved.
        def extract_metadata(file)
          document = parse_kramdown(file)
          toc = ::Kramdown::Converter::Toc.convert(document.root)
          toc_items = toc[0].children.select { |el| el.value.options[:level] == 2 }.map do |t| 
            {:id => t.attr[:id], :text => t.value.children.first.value}
          end


          metadata = document.root.options[:metadata]
          metadata[:toc] = toc_items
          metadata[:converted] = document.to_html
          metadata[:technologies] = metadata[:technologies].split(",")
          metadata[:images] = find_images(document.root)
          metadata
        end

        # Private: Depth first traversal of Kramdown tree to find images.
        #
        # el     - Kramdown::Element
        # images - Array of image sources
        def find_images el, images = Set.new
          el.children.each {|elem| find_images elem, images}
          if el.type == :img
            images << el.attr['src']
          end
          images
        end 

        # Private: Adds the Page to the site.
        #
        # site - The Site from awestruct.
        # file - The String file path (relative or absolute) to parse.
        # 
        # Returns the newly constructed Page
        def add_to_site(site, file)
          page_path = Pathname.new file
          page = site.engine.load_site_page file
          page.layout = @layout
          page.output_path = File.join @output_dir, page_path.relative_path_from(Pathname.new @repo).dirname, 'index.html'
          site.pages << page
          page
        end

        # Private: Adds the image to the site.
        #
        # site - The Site from awestruct.
        # file - The String of the image path
        #
        # Returns nothing
        def add_image_to_site(site, image)
          page_path = Pathname.new image
          page = site.engine.load_site_page image
          page.output_path = File.join @output_dir, page_path.relative_path_from(Pathname.new @repo).dirname, File.basename(image)
          site.pages << page
        end

        # Private: Parses the file through Kramdown.
        #
        # file - The String file path (relative or absolute) to parse.
        #
        # Returns the parsed Kramdown Document.
        def parse_kramdown(file)
          ::Kramdown::Document.new File.readlines(file).join, :input => 'QuickStartParser' 
        end
      end
    end
  end
end

