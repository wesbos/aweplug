require 'uri'
require 'json'
require 'date'
require 'aweplug/helpers/searchisko'
require 'aweplug/helpers/faraday'
require 'aweplug/cache'
require 'parallel'

module Aweplug
  module Helpers
    # Helper function for searching and retrieving documents from Strata.
    class Strata

      SearchiskoOptions = Struct.new(:dcp_base_url, :cache, :log_faraday, :searchisko_warnings)

      def search_then_index strata_url, cache, search_opts = {}, searchisko_opts = {}, logger = ::Logger.new('_tmp/faraday.log', 'daily')
        faraday = Aweplug::Helpers::FaradayHelper.default(strata_url, {logger: logger, cache: cache}) 
        faraday.basic_auth ENV['strata_username'], ENV['strata_password']

        response = faraday.get URI.escape('/rs/search'), search_opts, {Accept: 'application/json'}
        binding.pry
        if response.success?
          results = JSON.load response.body

          # loop through each, GET uri, build searchisko hash off that, send to searchisko 
          results["search_result"].each do |result|
            searchisko = Aweplug::Helpers::Searchisko.default(SearchiskoOptions.new(searchisko_opts[:dcp_base_url], cache, logger, searchisko_opts[:searchisko_warnings]))

            node = JSON.load faraday.get(result['uri'].split(strata_url).last, {}, {Accept: 'application/json'}).body

            searchisko_hash = {
              sys_updated: DateTime.now,
              sys_content_provider: 'rht',
              sys_title: node['title'],
              sys_project: node['products'].nil? ? nil : node['products']['product'],
              sys_project_name: node['products'].nil? ? nil : node['products']['product'],
              sys_url_view: node['view_uri'],
              product: node['product'],
              tags: node['tags'].nil? ? [] : node['tags']['tag'],
              sys_tags: node['tags'].nil? ? [] : node['tags']['tag']
            }
            if (result.key? "solution")
              searchisko_hash.merge!({
                sys_content_type: 'rht_knowledgebase_solution',
                sys_activity_dates: node['lastModifiedDate'] || [DateTime.now],
                sys_last_activity_date: node['lastModifiedDate'] || [DateTime.now],
                sys_created: node['createdDate'],
                sys_description: node['issue'].nil? ? '' : node['issue']['text'][0..400],
                sys_content: node['resolution'].nil? ? '' : node['resolution']['html'],
                "sys_content_content-type" => 'text/html',
                sys_content_plaintext: node['resolution'].nil? ? '' : 'text'
              })
              searchisko.push_content 'solution', node['id'], searchisko_hash
            end
            if (result.key? "article")
              searchisko_hash.merge!({
                sys_type: 'article',
                sys_content_type: 'rht_knowledgebase_article',
                sys_description: node['issue'].nil? ? '' : node['issue']['text'][0..400],
                issue: node['issue'].nil? ? '' : node['issue']['text'],
                environment: node['environment'].nil? ? '' : node['environment']['text'],
                resolution: node['resolution'].nil? ? '' : node['resolution']['text'],
                root_cause: node['root_cause'].nil? ? '' : node['root_cause']['text']
              })
              searchisko.push_content 'article', node['id'], searchisko_hash
            end
          end
        end
      end

      private 
      
    end
  end
end

