require 'open3'
require 'json'

module Aweplug
  module Helper
    module Git
      module Commit
        module Metadata
          # Public: Retrieves commit information from the git repo containing the file.
          #
          # repo_root - The directory (relative to the site base) containing  the git repo
          # file_path - Path to the file being processed, relative to the site base
          #
          # Returns an array of commit info as json values
          def commit_info(repo_root, file_path)
            o, _ = Open3.capture2(%Q[git --git-dir=#{repo_root}/.git log --date=iso --format='{"author":"%an","date":"%ai","hash":"%h","subject":"%f"}' -- #{file_path.to_s.sub(/#{repo_root}\//, '')}])
            o.split("\n").map{ |l| JSON.parse l, :symbolize_names => true }
          end
        end
      end
    end
  end
end
