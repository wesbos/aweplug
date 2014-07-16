require 'open3'
require 'json'
require 'yaml'

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
          # opts      - Any options to pass to the git command
          #
          # Returns an array of commit info as json values
          def commit_info(repo_root, file_path, opts = {})
            # TODO: Sanitize this
            default_opts = {date: 'iso', format: %Q|{"author":"%an","author_email":"%ae","date":"%ai","hash":"%h","subject":"%f"}| }
            opts.merge! default_opts

            cmd = %Q[git --git-dir=#{repo_root}/.git log]
            opts.each {|key,value| cmd << " --#{key}='#{value}'"}
            cmd << " -- #{file_path.to_s.sub(/#{repo_root}\//, '')}"

            o, _ = Open3.capture2(cmd)
            o.split("\n").map{ |l| JSON.parse l, :symbolize_names => true }
          end

          # Public: Retrieves the most recent tag (annotated or non-annotated reachable from the commit
          # by executing git describe --tags --always. See git-describe(1) for a full explanation.
          #
          # repo_root - The directory (relative to the site base) containing the git repo
          # file_path - Path to the file being processed, relative to the site base
          #
          # Returns the most recent tag
          def current_tag (repo_root, file_path)
            o, _ = Open3.capture2(%Q[git --git-dir=#{repo_root}/.git describe --tags --always])
            o.strip
          end

          # Public: Retrieves the most recent branch reachable from the commit
          # by executing git rev-parse --abbrev-ref HEAD. See git-rev-parse(1) for a full explanation.
          #
          # repo_root - The directory (relative to the site base) containing the git repo
          # file_path - Path to the file being processed, relative to the site base
          #
          # Returns the current branch
          def current_branch (repo_root, file_path)
            o, _ = Open3.capture2(%Q[git --git-dir=#{repo_root}/.git rev-parse --abbrev-ref HEAD])
            o.strip
          end
        end
      end
    end
  end
end

