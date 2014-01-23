require 'pathname'
require 'asciidoctor'
require 'aweplug/helpers/git_metadata'
require 'aweplug/helpers/searchisko'
require 'json'
require 'pry'

module Aweplug::Extensions
  # Public: An awestruct extension for guides / examples written in AsciiDoc.
  #         Files with the .asciidoc or .adoc extension are considered to be
  #         AsciiDoc files. This extension makes use of asciidoctor to 
  #         render the files.
  #
  # Example
  #
  #   extension Aweplug::Extensions::AsciidocExample({...})
  class AsciidocExample 
    include Aweplug::Helper::Git::Commit::Metadata
    include Aweplug::Helper::Git::Repository

    # Public: Initialization method, used in the awestruct pipeline.
    #
    # opts - A Hash of options, some being required, some not (default: {}). 
    #        :repository               - The String name of the directory 
    #                                    containing the repository (required).
    #        :directory                - The String directory name, within the
    #                                    :respository, containing the files 
    #                                    (required).
    #        :layout                   - The String name of the layout to use, 
    #                                    omitting the extension (required).
    #        :output_dir               - The String or Pathname of the output 
    #                                    directory for the files (required).
    #        :additional_excludes      - An Array of Strings containing 
    #                                    additional base file names to exclude 
    #                                    (default: []).
    #        :recurse_subdirectories   - Boolean flag indicating to continue 
    #                                    searching subdirectories (default: 
    #                                    true).
    #        :additional_metadata_keys - An Array of String keys from the 
    #                                    AsciiDoc metadata to include in the 
    #                                    searchisko payload (default: []).
    #        :site_variable            - String name of the key within the site
    #                                    containing additional metadata about 
    #                                    the guide (default: value of 
    #                                    :output_dir).
    # Returns the created extension.
    def initialize(opts = {})
      required_keys = [:repository, :directory, :layout, :output_dir, :site_variable]
      opts = {additional_excludes: [], recurse_subdirectories: true, 
              additional_metadata_keys: [], site_variable: opts[:output_dir]}.merge opts
      missing_required_keys = required_keys - opts.keys

      raise ArgumentError.new "Missing required arguments #{missing_required_keys.join ', '}" unless missing_required_keys.empty?

      @repo = opts[:repository]
      @output_dir = Pathname.new opts[:output_dir]
      @layout = opts[:layout]
      @recurse_subdirectories = opts[:recurse_subdirectories]
      @additional_metadata_keys = opts[:additional_metadata_keys]
      @additional_excludes = opts[:additional_excludes]
      @directory = File.join opts[:repository], opts[:directory]
      @site_variable = opts[:site_variable]
    end

    # Internal: Execute method required by awestruct. Called during the
    # pipeline execution. No return.
    #
    # site - The site instance from awestruct.
    #
    # Returns nothing.
    def execute site
      searchisko = Aweplug::Helpers::Searchisko.new({:base_url => site.dcp_base_url, 
                                                     :authenticate => true, 
                                                     :searchisko_username => ENV['dcp_user'], 
                                                     :searchisko_password => ENV['dcp_password'], 
                                                     :logger => site.profile == 'developement'})
      Find.find @directory do |path|
        Find.prune if File.directory?(path) && !@recurse_subdirectories

        next if File.directory?(path) # If it's a directory, start recursing

        Find.prune if File.extname(path) !~ /\.a(scii)?doc/ || @additional_excludes.include?(File.basename path)

        page = site.engine.load_site_page path
        page.layout = @layout
        page.output_path = File.join(@output_dir, File.basename(page.output_path))

        doc = Asciidoctor.load_file path
        metadata = {:author => doc.author, :commits => commit_info(@repo, path), 
                    :title => doc.doctitle, :tags => doc.attributes['tags'],
                    :toc => doc.sections.inject([]) {|result, elm| result << {:id => elm.id, :text => elm.title}; result},
                    :github_repo_url => repository_url(@repo),
                    # Will need to strip html tags for summary
                    :summary => doc.sections.first.render}

        page.send('metadata=', metadata)
        site.pages << page

        searchisko_hash = {
          :sys_title => metadata[:title], 
          :sys_content_id => Digest::SHA1.hexdigest(metadata[:title])[0..7], # maybe change?
          :sys_description => metadata[:summary],
          :sys_content => doc.render, 
          :sys_url_view => "#{site.base_url}#{site.ctx_root.nil? ? '/' : '/' + site.ctx_root + '/'}#{page.output_path}",
          :"sys_content_content-type" => 'text/html',
          :sys_type => 'jbossdeveloper_example',
          :sys_content_type => 'example',
          :sys_content_provider => 'jboss-developer',
          :contributors => metadata[:commits].collect { |c| c[:author] }.unshift(metadata[:author]).uniq,
          :sys_created => metadata[:commits].collect { |c| DateTime.parse c[:date] }.last,
          :sys_activity_dates => metadata[:commits].collect { |c| DateTime.parse c[:date] },
          :sys_updated => metadata[:commits].collect { |c| DateTime.parse c[:date] }.first
        } 

        @additional_metadata_keys.inject(searchisko_hash) do |hash, key|
          hash[key.to_sym] = doc.attributes[key]
          hash
        end

        unless site.profile =~ /development/
          searchisko.push_content(searchisko_hash[:sys_type], 
                                  searchisko_hash[:sys_content_id], 
                                  searchisko_hash.to_json)
        end
      end
    end
  end
end

