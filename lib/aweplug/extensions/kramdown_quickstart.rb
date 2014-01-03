require 'pathname'
require 'kramdown'
require 'aweplug/helpers/git_commit_metadata'
require 'aweplug/helpers/kramdown_metadata'
require 'aweplug/helpers/searchisko'
require 'json'

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
          # Not sure if it's better to do this once per class, 
          # once per site, or once per invocation
          searchisko = Aweplug::Helpers::Searchisko.new({:base_url => site.dcp_base_url, 
                                                         :authenticate => true, 
                                                         :searchisko_username => ENV['dcp_user'], 
                                                         :searchisko_password => ENV['dcp_password'], 
                                                         :logger => site.profile == 'developement'})
          Dir["#{@repo}/**/README.md"].each do |file|
            page = add_to_site site, file

            metadata = extract_metadata(file)
            metadata[:commits] = commit_info @repo, Pathname.new(file)
            converted_html = metadata.delete :converted

            page.send 'metadata=', metadata
            
            searchisko_hash = 
            {
              :sys_title => metadata[:title], 
              :sys_content_id => Digest::SHA1.hexdigest(metadata[:title])[0..7], # maybe change?
              :level => metadata[:level],
              :tags => metadata[:technologies].split(/,\s/),
              :sys_description => metadata[:summary],
              :sys_content => converted_html, 
              :sys_url_view => "#{site.base_url}#{site.ctx_root.nil? ? '/' : '/' + site.ctx_root + '/'}#{page.output_path}",
              :"sys_content_content-type" => 'text/html',
              :sys_type => 'jbossdeveloper_quickstart',
              :sys_content_type => 'quickstart',
              :sys_content_provider => 'jboss-developer',
              :contributors => metadata[:commits].collect { |c| c[:author] }.unshift(metadata[:author]).uniq,
              :sys_created => metadata[:commits].collect { |c| DateTime.parse c[:date] }.last,
              :sys_activity_dates => metadata[:commits].collect { |c| DateTime.parse c[:date] },
              :sys_updated => metadata[:commits].collect { |c| DateTime.parse c[:date] }.first,
              :target_product => metadata[:target_product]
            } 

            unless site.profile =~ /development/
              searchisko.push_content(searchisko_hash[:sys_type], 
                searchisko_hash[:sys_content_id], 
                searchisko_hash.to_json)
            end
          end
        end

        def extract_metadata(file)
          document = parse_kramdown(file)
          toc = ::Kramdown::Converter::Toc.convert(document.root)
          toc_items = toc[0].children.select { |el| el.value.options[:level] == 2 }.map do |t| 
            {:id => t.attr[:id], :text => t.value.children.first.value}
          end

          metadata = document.root.options[:metadata]
          metadata[:toc] = toc_items
          metadata[:converted] = document.to_html
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

        private

        def parse_kramdown(file)
          ::Kramdown::Document.new File.readlines(file).join, :input => 'QuickStartParser' 
        end
      end
    end
  end
end

