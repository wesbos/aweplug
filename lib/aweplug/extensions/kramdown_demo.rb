require 'pathname'
require 'set'
require 'json'
require 'kramdown'
require 'aweplug/helpers/kramdown_metadata'
require 'aweplug/helpers/searchisko'
require 'parallel'
require 'yaml'
require 'aweplug/handlers/synthetic_handler'
require 'awestruct/page'
require 'awestruct/handlers/layout_handler'
require 'awestruct/handlers/tilt_handler'
require 'faraday'
require 'faraday_middleware' 
require 'base64'
require 'nokogiri'
require 'aweplug/helpers/searchisko_social'
require 'aweplug/cache'



module Aweplug
  module Extensions
    module Kramdown
      # Public: An awestruct extension for demos which have their main page 
      #         written in markdown. It reads the list of demos from a remote
      #         url and generates metadata and page for each. This extension 
      #         makes use of the Aweplug::Helper::Searchisko class, please see
      #         that class for more info on options and settings for Searchisko.
      #
      # Example
      #
      #   extension Aweplug::Extensions::Kramdown::Demo({...})
      class Demo
        include Aweplug::Helpers::SearchiskoSocial

        GITHUB_REPO = /^https?:\/\/(www\.)?github\.com\/([^\/]*)\/([^\/]*)\/?$/
        GITHUB_RELEASE = /^https?:\/\/(www\.)?github\.com\/([^\/]*)\/([^\/]*)\/(releases\/tag|archive)\/(.*?)(\.zip|\.tar\.gz)?$/
        # Public: Initialization method, used in the awestruct pipeline.
        #
        # opts - A Hash of options, some being required, some not (default: {}). 
        #        :url                - The url of demo list (see 
        #                              https://github.com/jboss-developer/jboss-developer-demos 
        #                              for metadata specification)
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
          required_keys = [:url, :layout, :output_dir]
          missing_required_keys = required_keys - opts.keys

          raise ArgumentError.new "Missing required arguments #{missing_required_keys.join ', '}" unless missing_required_keys.empty?
          @url = opts[:url]
          @output_dir = Pathname.new opts[:output_dir]
          @layout = opts[:layout]
          @site_variable = opts[:site_variable] || opts[:output_dir]
          @excludes = opts[:excludes] || []
          @push_to_searchisko = opts[:push_to_searchisko].nil? ? true : opts[:push_to_searchisko]
          @normalize_contributors = opts.has_key?(:normalize_contributors) ? opts[:normalize_contributors]  : true
        end

        # Internal: Execute method required by awestruct. Called during the
        # pipeline execution. No return.
        #
        # site - The Site instance from awestruct.
        #
        # Returns nothing.
        def execute site
          @cache = Aweplug::Cache.default site # default cache here shouldn't matter.
          farday = init_faraday(site)

          ids = []
          if @url.start_with? 'http'
            demos = YAML.load(@faraday.get(@url).body)
          else
            demos = YAML.load(File.open(@url))
          end
          if demos
            Parallel.each(demos, in_threads: 40) do |url|
              next if @excludes.include?(url)
              build(url, site, ids)
            end
          end
        end

        private

        def build url, site, ids = []
          init_faraday(site)
          # Load the demo definition
          if url =~ GITHUB_REPO
            metadata = from_github({:github_org => $2, :github_repo => $3})
          else
            # We load the definition from the YAML file specified
            metadata = from_yaml(url)
          end
          unless metadata.nil?
            metadata[:original_url] = url

            source = @faraday.get(metadata[:content]).body

            # Raise an error if the site already has this page
            dir = File.join @output_dir, metadata[:id]
            path = File.join dir, 'index.html'
            raise "Demo '#{metadata[:id]}' already exists (built from #{url})" if ids.include? metadata[:id]

            if metadata[:author]
              metadata[:author].split(',').each_with_index do |author, i|
                metadata[:author] = author if i == 0
                metadata[:contributors] << author unless i == 0
              end
            end

            if (metadata[:summary].nil? || metadata[:summary].strip.empty?) && !metadata[:converted].strip.empty?
              metadata[:summary] = Nokogiri::HTML.parse(metadata[:converted]).css('p').first.text.gsub("\n", ' ')
            end

            validate metadata

            # Not sure if it's better to do this once per class, 
            # once per site, or once per invocation
            searchisko = Aweplug::Helpers::Searchisko.new({:base_url => site.dcp_base_url, 
                                                          :authenticate => true, 
                                                          :searchisko_username => ENV['dcp_user'], 
                                                          :searchisko_password => ENV['dcp_password'], 
                                                          :cache => @cache,
                                                          :logger => site.log_faraday,
                                                          :searchisko_warnings => site.searchisko_warnings})

            page = add_to_site site, path, metadata[:converted]

            unless !@push_to_searchisko || site.profile =~ /development/
              send_to_searchisko(searchisko, metadata, page, site, metadata[:converted])
            end
            
            if @normalize_contributors
              unless metadata[:author].nil? 
                metadata[:author] = normalize 'contributor_profile_by_jbossdeveloper_quickstart_author', metadata[:author], searchisko
              end

              metadata[:contributors].collect! do |contributor|
                contributor = normalize 'contributor_profile_by_jbossdeveloper_quickstart_author', contributor, searchisko
              end
            end

            metadata[:contributors].delete(metadata[:author])

            page.send 'metadata=', metadata

            if site.dev_mat_techs.nil?
              site.send('dev_mat_techs=', []);
            end
            site.dev_mat_techs << metadata[:technologies].flatten
          end
        end

        def init_faraday site
          @faraday ||= Faraday.new do |builder|
            if (site.log_faraday.is_a?(::Logger))
              builder.response :logger, @logger = site.log_faraday
            else 
              builder.response :logger, @logger = ::Logger.new('_tmp/faraday.log', 'daily')
            end
            builder.request :url_encoded
            builder.request :retry
            builder.use FaradayMiddleware::Caching, @cache, {}
            builder.use FaradayMiddleware::FollowRedirects, limit: 3
            builder.adapter Faraday.default_adapter 
          end
        end

        def from_yaml url
          response = @faraday.get(url)
          if response.success?
            metadata = symbolize_hash(YAML.load(response.body))
            if metadata[:id].nil?
              p = Pathname.new(URI.parse(url).path)
              metadata[:id] = p.basename.to_s.chomp(p.extname.to_s)
            end
            if metadata.has_key?(:github_repo_url) && metadata[:github_repo_url] =~ GITHUB_REPO
              metadata[:github_org] = $2
              metadata[:github_repo] = $3
              from_github metadata
            else
              metadata[:scm] = 'unknown'
              metadata
            end
          else
            puts "#{response.status} loading #{url}"
          end
        end

        def from_github metadata
          metadata[:id] ||= metadata[:github_repo]
          metadata[:github_repo_url] ||= "http://github.com/#{metadata[:github_org]}/#{metadata[:github_repo]}"
          if metadata[:content].nil?
            metadata[:content] ||= "https://api.github.com/repos/#{metadata[:github_org]}/#{metadata[:github_repo]}/readme"
            raw = Base64.decode64(JSON.load(@faraday.get(metadata[:content]).body)['content'])
          else
            raw = @faraday.get(metadata[:content]).body
          end
          metadata = extract_metadata(raw).merge(metadata)
          unless metadata.has_key?(:download) || metadata.has_key?(:published) || metadata.has_key?(:browse)
            if metadata.has_key?(:release) && metadata[:release] =~ GITHUB_RELEASE
              download_org = $2
              download_repo = $3
              tag = $5
            end
            base_download_url = "https://api.github.com/repos/#{download_org || metadata[:github_org]}/#{download_repo || metadata[:github_repo]}"
            releases = JSON.load(@faraday.get("#{base_download_url}/releases").body)

            # Find the tagged release
            release = releases.find {|r| r['tag_name'] == tag} unless tag.nil?
            # If no tag, or not gound, find the first non prerelease
            release ||= releases.find {|r| r['prerelease'] != 'true'}
            
            unless release.nil?
              metadata[:download] ||= release['zipball_url']
              metadata[:published] ||= DateTime.parse(release['published_at'])
              browse = "https://github.com/#{download_org || metadata[:github_org]}/#{download_repo || metadata[:github_repo]}/tree/#{release['tag_name']}"
              if @faraday.get(browse).success?
                metadata[:browse] = browse
              else
                metadata[:browse] = release['html_url']
              end
            else
              metadata[:download] ||= "#{base_download_url}/zipball/master"
              metadata[:published] = DateTime.parse(JSON.load(@faraday.get("#{base_download_url}/commits").body).first['commit']['author']['date'])
              metadata[:browse] = metadata[:github_repo_url]
            end
          end
          unless metadata.has_key?(:author) && metadata.has_key?(:contributors)
            commits = JSON.load(@faraday.get("https://api.github.com/repos/#{metadata[:github_org]}/#{metadata[:github_repo]}/commits").body)
            a = commits.collect { |c| c['author'].nil? ? nil : c['author']['login'] }
            b = a.inject(Hash.new(0)) { |r, l| r[l] += 1; r }
            contributors = commits.collect { |c| c['author'].nil? ? nil : c['author']['login'] }.inject(Hash.new(0)) { |r, l| r[l] += 1; r }.sort_by{ |l,c| -c}.collect{ |(k,v)| k }.reject{ |l| l.nil? }
            metadata[:author] = contributors.last unless metadata.has_key?(:author)
            metadata[:contributors] = contributors unless metadata.has_key?(:contributors)
          end
          metadata[:scm] = 'github'
          metadata
        end


        def validate metadata
          raise "Must specify title for #{metadata[:original_url]}" unless metadata.has_key? :title
          raise "Must specify summary for #{metadata[:original_url]}" unless metadata.has_key? :summary
          raise "Must specify download for #{metadata[:original_url]}" unless metadata.has_key? :download
          raise "Must specify browse for #{metadata[:original_url]}" unless metadata.has_key? :browse
          raise "Must specify content for #{metadata[:original_url]}" unless metadata.has_key? :content
          raise "Must specify published for #{metadata[:original_url]}" unless metadata.has_key? :published
          raise "Must specify level" unless metadata.has_key? :level
          raise "Must specify author" unless metadata.has_key? :author
        end

        # Private: Sends the metadata to Searchisko.
        #
        # Returns nothing.
        def send_to_searchisko(searchisko, metadata, page, site, converted_html)
          metadata[:searchisko_id] = metadata[:id]
          metadata[:searchisko_type] = 'jbossdeveloper_demo'

          searchisko_hash = {
            :sys_title => metadata[:title], 
            :level => metadata[:level],
            :tags => metadata[:technologies],
            :sys_description => metadata[:summary],
            :sys_content => converted_html, 
            :sys_url_view => "#{site.base_url}#{site.ctx_root.nil? ? '/' : '/' + site.ctx_root + '/'}#{page.output_path}",
            :author => metadata[:author],
            :contributors => metadata[:contributors],
            :sys_created => metadata[:published],
            :target_product => metadata[:target_product],
            :github_repo_url => metadata[:github_repo_url],
            :experimental => metadata[:experimental],
            :thumbnail => metadata[:thumbnail],
            :download => metadata[:download]
          } 

          searchisko.push_content(metadata[:searchisko_type], 
                                    metadata[:searchisko_id], 
                                    searchisko_hash.to_json)
        end

        # Private: Makes use of the sepcial Kramdown parser in aweplug to pull 
        # out metadata from the README files.
        # 
        # content - the content to parse
        #
        # Returns a Hash of the metadata retrieved.
        def extract_metadata(content)
          document = parse_kramdown(content)
          toc = ::Kramdown::Converter::Toc.convert(document.root)
          toc_items = toc[0].children.select { |el| el.value.options[:level] == 2 }.map do |t| 
            {:id => t.attr[:id], :text => t.value.children.first.value}
          end
          metadata = document.root.options[:metadata]
          metadata[:toc] = toc_items
          metadata[:converted] = document.to_html
          metadata[:technologies] = metadata[:technologies].split(",").collect {|tech| tech.strip}
          metadata[:author] = metadata[:author].split(',').first if metadata[:author]
          metadata[:product] ||= @product
          metadata[:experimental] ||= @experimental
          metadata[:experimental] ||= false
          metadata[:level] = 'Beginner'
          metadata
        end

        # Private: Adds the Page to the site.
        #
        # site - The Site from awestruct.
        # path - The output path
        # content - The content to parse
        # 
        # Returns the newly constructed Page
        def add_to_site(site, path, content)
          page = ::Awestruct::Page.new(site,
                     ::Awestruct::Handlers::LayoutHandler.new(site,
                       ::Awestruct::Handlers::TiltHandler.new(site,
                         ::Aweplug::Handlers::SyntheticHandler.new(site, content, path))))
          page.layout = @layout
          page.output_path = path
          site.pages << page
          page
        end

        # Private: Parses the file through Kramdown.
        #
        # file - The String file path (relative or absolute) to parse.
        #
        # Returns the parsed Kramdown Document.
        def parse_kramdown(content)
          ::Kramdown::Document.new content, :input => 'QuickStartParser' 
        end

        # Private: Converts hash key to symbols
        def symbolize_hash hash
          hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
        end
      end
    end
  end
end

