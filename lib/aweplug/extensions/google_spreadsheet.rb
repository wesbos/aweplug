require 'aweplug/helpers/google_spreadsheets'

module Aweplug
  module Extensions
    class GoogleSpreadsheet

      def initialize assign_to: , authenticate: false, key: , worksheet_title: , by: nil, row_labels: false, col_labels: false
        @assign_to = assign_to
        @authenticate = authenticate
        @key = key
        @worksheet_title = worksheet_title
        @row_labels = row_labels
        @col_labels = col_labels
        @by = by
      end

      def execute site
        gs = Aweplug::Helpers::GoogleSpreadsheets.new site: site, authenticate: @authenticate
        ws = gs.worksheet_by_title @key, @worksheet_title
        if @by == 'row'
          site.send( "#{@assign_to}=", ws.by_row(row_labels: @row_labels, col_labels: @col_labels) )
        elsif @by == 'col'
          site.send( "#{@assign_to}=", ws.by_col(row_labels: @row_labels, col_labels: @col_labels) )
        else
          site.send( "#{@assign_to}=", ws )
        end
      end

    end
  end
end

