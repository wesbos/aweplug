require 'pathname'
require 'asciidoctor'
require 'aweplug/helpers/git_commit_metadata'
require 'aweplug/helpers/searchisko'
require 'json'
require 'pry'

module Aweplug::Extensions
  class AsciidocExample 
    include Aweplug::Helper::Git::Commit::Metadata

    def initialize(repository, directory, layout, output_dir, additional_excludes = [], 
                   recurse_subdirectories = true, additional_metadata_keys = [])
      @repo = repository
      @output_dir = Pathname.new output_dir
      @layout = layout
      @recurse_subdirectories = recurse_subdirectories
      @additional_metadata_keys = additional_metadata_keys
      @additional_excludes = additional_excludes
      @directory = File.join repository, directory
    end

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
          :contributors => metadata[:commits].collect { |c| c[:author] }.uniq,
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

