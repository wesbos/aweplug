require 'aweplug/google_apis'
require 'aweplug/helpers/searchisko_social'
require 'json'
require 'aweplug/helpers/resources'
require 'aweplug/helpers/searchisko'

module Aweplug
  module Books

    module StringUtils
      refine String do
        def numeric?
          return true if self =~ /^\d+$/
          true if Float(self) rescue false
        end

        def truncate(max: 150)
          out = ""
          i = 0
          self.gsub(/<\/?[^>]*>/, "").scan(/[^\.!?]+[\.!?]/).map(&:strip).each do |s|
            i += s.length
            if i > max
              break
            else
              out << s
            end
          end
          out
        end

      end

    end

    class GoogleBooks
      include Aweplug::GoogleAPIs
      include Aweplug::Helpers::SearchiskoSocial
      include Aweplug::Helpers::Resources
      using StringUtils

      BOOKS_API_SERVICE_NAME = 'books'
      BOOKS_API_VERSION = 'v1'

      def initialize site, push_to_searchisko
        @site = site
        @push_to_searchisko = push_to_searchisko
        @client = google_client(site, authenticate: false)
        @books = @client.discovered_api(BOOKS_API_SERVICE_NAME, BOOKS_API_VERSION)
        @searchisko = Aweplug::Helpers::Searchisko.default site
      end

      def get data
        res = @client.execute!(
          :api_method => @books.volumes.list,
          :parameters => {
            :q => "isbn:#{data['isbn']}"
          }
        )
        if res.success?
          books = JSON.load(res.body)
          if books['totalItems'] == 1
            book = books['items'][0]
          elsif books['totalItems'] > 1
            # See if only one of the books has the correct ISBN_13
            possibles = books['items'].find_all { |b| isbn_13(b) == data['isbn'] }
            if possibles.length == 1
              book = possibles.first
            else
              puts ">1 books found for #{data['isbn']}"
            end
          else
            puts "No results found for isbn: #{data['isbn']}"
          end
          unless book.nil?
            isbn = isbn_13(book) || data['isbn']
            if !data['thumbnail_url'].nil? && !data['thumbnail_url'].empty?
              thumbnail = data['thumbnail_url']
            elsif book['volumeInfo'].has_key? 'imageLinks'
              thumbnail = book['volumeInfo']['imageLinks']['thumbnail']
            else
              thumbnail = cdn("#{@site.base_url}/images/books/book_noimageavailable.jpg")
            end
            normalized_authors = book['volumeInfo'].has_key?('authors') ? book['volumeInfo']['authors'].collect { |a| normalize 'contributor_profile_by_jbossdeveloper_quickstart_author', a, @searchisko } : []
            unless book['volumeInfo']['publishedDate'].nil?
              if m = book['volumeInfo']['publishedDate'].match(/^(\d{4})([-|\/](\d{1,2})([-|\/](\d{1,2}))?)?$/)
                if !m[5].nil?
                  published = DateTime.new(m[1].to_i, m[3].to_i, m[5].to_i)
                elsif !m[3].nil?
                  published = DateTime.new(m[1].to_i, m[3].to_i)
                else
                  published = DateTime.new(m[1].to_i)
                end
              end
            end
            description = book['volumeInfo']['description'].truncate(max: 500) if book['volumeInfo']['description']
            {
              :sys_title => book['volumeInfo']['title'],
              :sys_description => description,
              :sys_url_view => book['volumeInfo']['canonicalVolumeLink'],
              :authors => book['volumeInfo']['authors'],
              :thumbnail => thumbnail.to_s,
              :isbn => isbn,
              :tags => book['volumeInfo']['categories'],
              :web_reader_link => book['volumeInfo']['webReadLink'],
              :preview_link => book['volumeInfo']['previewLink'],
              :info_link => book['volumeInfo']['infoLink'],
              :publisher => book['volumeInfo']['publisher'],
              #:sys_content => book['volumeInfo']['description'],
              :sys_created => published,
              :normalized_authors => normalized_authors,
              :average_rating => book['volumeInfo']['averageRating']
            }
          end
        else
          puts "#{res.status} loading isbn: #{data['isbn']}"
        end
      end

      def send_to_searchisko book
        unless !@push_to_searchisko || @site.profile =~ /development/
          @searchisko.push_content('jbossdeveloper_book', 
                                 book[:isbn], 
                                 book.reject {|k, v| k == :normalized_authors }.to_json)
        end
      end

      private

      def isbn_13 book
        if book['volumeInfo'].has_key?('industryIdentifiers')
          ids = Hash[book['volumeInfo']['industryIdentifiers'].map(&:values).map(&:flatten)]
          if ids.has_key?('ISBN_13') && !ids['ISBN_13'].nil? && !ids['ISBN_13'].empty?
            return ids['ISBN_13']
          elsif ids.has_key?('OTHER') && !ids['OTHER'].nil? && ids['OTHER'].numeric? && !ids['OTHER'].empty?
            return ids['OTHER']
          end
        end
        nil 
      end

    end
  end
end

