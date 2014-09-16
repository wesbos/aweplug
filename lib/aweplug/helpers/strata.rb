require 'uri'
require 'json'
require 'date'
require 'aweplug/helpers/searchisko'
require 'aweplug/cache/file_cache'
require 'faraday'
require 'faraday_middleware'
require 'parallel'

module Aweplug
  module Helpers
    # Helper function for searching and retrieving documents from Strata.
    class Strata

      def search_then_index strata_url, search_opts = {}, searchisko_opts = {}, logger = nil, cache = nil
        faraday = init_faraday(strata_url, logger, cache)

        response = faraday.get URI.escape('/rs/search'), search_opts, {Accept: 'application/json'}
        results = JSON.load response.body

        # loop through each, GET uri, build searchisko hash off that, send to searchisko 
        results["search_result"].each do |result|
          searchisko = Aweplug::Helpers::Searchisko.new({:base_url => searchisko_opts[:dcp_base_url], 
                                                         :authenticate => true, 
                                                         :searchisko_username => ENV['dcp_user'], 
                                                         :searchisko_password => ENV['dcp_password'], 
                                                         :cache => searchisko_opts[:cache],
                                                         :logger => searchisko_opts[:logger],
                                                         :searchisko_warnings => searchisko_opts[:searchisko_warnings]})
          begin
            node = JSON.load faraday.get(result['uri'].split(strata_url).last, {}, {Accept: 'application/json'}).body

            searchisko_hash = {
                sys_updated: DateTime.now,
                sys_content_provider: 'rht',
                sys_title: node['title'],
                sys_project: value_or_default(node['products'], 'product', nil),
                sys_project_name: value_or_default(node['products'], 'product', nil), 
                sys_url_view: node['view_uri'],
                product: node['product'],
                tags: value_or_default(node['tags'], 'tag', []),
                sys_tags: value_or_default(node['tags'], 'tag', [])
            }
            if (result.key? "solution")
              searchisko_hash.merge!({
                sys_content_type: 'rht_knowledgebase_solution',
                sys_activity_dates: value_or_default(node, 'lastModifiedDate', [DateTime.now]),
                sys_last_activity_date: value_or_default(node, 'lastModifiedDate', DateTime.now),
                sys_created: node['createdDate'],
                sys_description: value_or_default(node['issue'], 'text', '')[0..400],
                sys_content: value_or_default(node['resolution'], 'html', ''),
                "sys_content_content-type" => 'text/html',
                sys_content_plaintext: value_or_default(node['resolution'], 'text', ''),
              })
              searchisko.push_content 'solution', node['id'], searchisko_hash
            end
            if (result.key? "article")
              searchisko_hash.merge!({
                sys_type: 'article',
                sys_content_type: 'rht_knowledgebase_article',
                sys_description: value_or_default(node['issue'], 'text', '')[0..400],
                issue: value_or_default(node['issue'],'text', ''),
                environment: value_or_default(node['environment'],'text', ''),
                resolution: value_or_default(node['resolution'],'text', ''),
                root_cause: value_or_default(node['root_cause'],'text', '')
              })
              searchisko.push_content 'article', node['id'], searchisko_hash
            end
          rescue Exception => e
            puts "#{e}"
            puts e.backtrace
          end
        end
      end

      protected

      private

      def value_or_default(container, key, default)
        begin
          container[key]
        rescue
          default
        end
      end

      def init_faraday strata_url, logger = nil, cache = nil
        cache = Aweplug::Cache::FileCache.new if cache.nil?
        conn = Faraday.new(url: strata_url) do |builder|
          if (logger) 
            if (logger.is_a?(::Logger))
              builder.response :logger, @logger = logger
            else 
              builder.response :logger, @logger = ::Logger.new('_tmp/faraday.log', 'daily')
            end
          end
          builder.use FaradayMiddleware::Caching, cache, {}
          builder.adapter :net_http
          builder.options.params_encoder = Faraday::FlatParamsEncoder
          builder.ssl.verify = false
        end

        conn.basic_auth ENV['strata_username'], ENV['strata_password']
        conn
      end
      
    end
  end
end

