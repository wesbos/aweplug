require 'parallel'
require 'aweplug/books/google_books'

module Aweplug
  module Extensions
    class Books

      # Public: Creates a new instance of this Awestruct plugin.
      #
      # variable_name       - Name of the variable in the Awestruct Site containing
      #                       the list of book ISBNs.
      # push_to_searchisko  - A boolean controlling whether a push to
      #                       seachisko should happen. A push will not
      #                       happen when the development profile is in
      #                       use, regardless of the value of this 
      #                       option.
      #
      # Returns a new instance of this extension.                
      def initialize variable_name, push_to_searchisko = true
        @variable = variable_name
        @push_to_searchisko = push_to_searchisko
      end

      def execute site 
        gbooks = Aweplug::Books::GoogleBooks.new site, @push_to_searchisko
        books = []
        
        Parallel.each(eval(@variable), in_threads: 40) do |isbn|
          book = gbooks.get(isbn)
          unless book.nil?
            books << book
            gbooks.send_to_searchisko book
          end
        end
        site.send("books=", books.sort { |b, a| (a[:sys_created] || DateTime.new(1970)) <=> (b[:sys_created] || DateTime.new(1970)) })
      end

    end
  end
end

