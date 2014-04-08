require 'open3'
require 'json'

module Aweplug
  module Helper
    module Git
      module Repository
        # Public: Returns the URL for the git repository.
        #
        # repo_root - The directory (relative to the site base) containing the 
        #             git repository.
        # remote_name - Name of the remote to retrieve, defaults to 'origin'
        #
        # Returns a string containing the URL of the git remote repository
        def repository_url(repo_root, remote_name='origin') 
          Open3.capture2(%Q[git --git-dir=#{repo_root}/.git config --get remote.#{remote_name}.url]).first.chomp[0..-5]
        end
      end
      module Commit
        module Metadata
          # Public: Retrieves commit information from the git repo containing the file.
          #
          # repo_root - The directory (relative to the site base) containing the git repo
          # file_path - Path to the file being processed, relative to the site base
          #
          # Returns an array of commit info as json values
          def commit_info(repo_root, file_path)
            o, _ = Open3.capture2(%Q[git --git-dir=#{repo_root}/.git log --date=iso --format='{"author":"%an","author_email":"%ae","date":"%ai","hash":"%h","subject":"%f"}' -- #{file_path.to_s.sub(/#{repo_root}\//, '')}])
            o.split("\n").map{ |l| JSON.parse l, :symbolize_names => true }
          end
        end
      end
    end
  end
end

