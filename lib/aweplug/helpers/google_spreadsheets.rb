require 'xmlsimple'
require 'uri'
require 'pathname'
require 'faraday'
require 'faraday_middleware' 
require 'logger'
require 'aweplug/cache'
require 'aweplug/middleware/statuslogger'

module Aweplug
  module Helpers
    class GoogleSpreadsheets

      class Worksheet
        
        def initialize data
          @data = data
        end

        def raw
          @data
        end

        def by_row row_labels: false, col_labels: false
          res = by do |res, col, row, content|
            res[row] ||= {}
            res[row][col] = content
          end
          if row_labels
            res = add_labels_1d res
          end
          if col_labels
            res = add_labels_2d res
          end
          res
        end

        def by_col row_labels: false, col_labels: false
          res = by do |res, col, row, content|
            res[col] ||= {}
            res[col][row] = content
          end
          if row_labels
            res = add_labels_2d res
          end
          if col_labels
            res = add_labels_1d res
          end
          res
        end

        private

        def by
          res = {} 
          @data['entry'].each do |e|
            c = e['cell'].first
            loc = e['title'].first['content']
            d = loc.index(/\d/)
            col = loc.slice(0..(d-1))
            row = loc.slice(d..loc.length)
            yield res, col, row, c['content']
          end
          res
        end

        def labelify s
          s ? s.downcase.gsub(' ', '_') : nil
        end

        def add_labels_1d data
          res = {}
          labels = {}
          data.each do |a, bs|
            labels[a] = label = labelify(bs.values[0])
          end
          data.each do |a, bs|
            res[labels[a] || a] ||= {}
            bs.each do |b, c|
              res[labels[a] || a][b] = c
            end
          end
          res
        end

        def add_labels_2d data
          res = {}
          labels = {}
          data.each_with_index do |(a, bs), i|
            if i == 0
              labels = bs
            else
              res[a] = {}
              bs.each do |(b, c)|
                res[a][labelify(labels[b]) || b] = c
              end
            end
          end
          res
        end

      end


      BASE_URL = 'https://spreadsheets.google.com/feeds/'

      def initialize site: , authenticate: false, logger: true, raise_error: false, adapter: nil
        @site = site
        @authenticate = authenticate

        Aweplug::Cache.default site

        @faraday = Faraday.new(:url => BASE_URL) do |builder|
          if authenticate
            oauth2_client = client_signet
            builder.use FaradayMiddleware::OAuth2, oauth2_client.access_token
          end
          if (logger) 
            if (logger.is_a?(::Logger))
              builder.response :logger, @logger = logger
            else 
              builder.response :logger, @logger = ::Logger.new('_tmp/faraday.log', 'daily')
            end
          end
          builder.request :url_encoded
          builder.request :retry
          builder.use Aweplug::Middleware::StatusLogger 
          builder.response :raise_error if raise_error
          builder.use FaradayMiddleware::FollowRedirects
          builder.use FaradayMiddleware::Caching, Aweplug::Cache.default(site), {}
          #builder.response :json, :content_type => /\bjson$/
          builder.adapter adapter || :net_http
        end
      end

      def worksheets key
        XmlSimple.xml_in(get("worksheets/#{key}").body)
      end

      def worksheet key, id
        Worksheet.new(XmlSimple.xml_in(get("cells/#{key}/#{id}").body))
      end

      def worksheet_by_title key, title
        worksheets(key)['entry'].each do |s|
          s['title'].each do |t|
            if title == t['content']
              return worksheet(key, Pathname.new(URI(s['id'].first).path).basename)
            end
          end
        end
      end

      private

      # Internal: Obtains an OAuth::AcccessToken for the Google Spreadsheets API, using the 
      # google_client_id and google_access_token defined in site/config.yml and
      # google_client_secret and google_access_token_secret defined in environment
      # variables
      #
      # site - Awestruct Site instance
      # 
      # Returns an OAuth::AccessToken for the Google API 
      def client_signet
        require 'signet/oauth_2/client'
        require 'google/api_client/auth/key_utils'
        key = Google::APIClient::KeyUtils.load_from_pkcs12(ENV['google_private_key'] || @site.google_private_key || Pathname.new(ENV['HOME']).join('.google-private-key.p12').to_s, 'notasecret')
        client = Signet::OAuth2::Client.new(
          :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
          :audience => 'https://accounts.google.com/o/oauth2/token',
          :scope => 'https://spreadsheets.google.com/feeds',
          :issuer => @site.google_client_email,
          :signing_key => key
        )
        client.fetch_access_token!
        client
      end

      def get path, params = {}
        response = @faraday.get URI.escape("#{path}/#{@authenticate ? 'private' : 'public'}/full"), params
        unless response.success?
          raise "#{response.status} loading spreadsheet at #{path}."
        end
        if response.body.include? "<!DOCTYPE html>"
          raise "#{path} is not public, either enable authentication or publish the spreadsheet to the web"
        end
        response
      end


    end
  end
end

