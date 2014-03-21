require 'digest'
require 'yaml'

module Aweplug
  module Helpers
    # CDN will take the details of a file passed to the version method
    # If necessary, if the file has changed since the last time version
    # was called for that method, it will generate a copy of the file in
    # _tmp/cdn with new file name, and return that file name
    class CDN

      CDN_TMP_DIR = Pathname.new("_tmp").join("cdn")
      CDN_CONTROL = Pathname.new("_cdn").join("cdn.yml")

      def initialize(ctx_path)
        @tmp_dir = CDN_TMP_DIR.join ctx_path
        FileUtils.mkdir_p(File.dirname(CDN_CONTROL))
        FileUtils.mkdir_p(@tmp_dir)
      end

      def version(name, ext, content)
        id = name + ext
        yml = YAML::Store.new CDN_CONTROL
        yml.transaction do
          yml[id] ||= { "build_no" => 0 }
          md5sum = Digest::MD5.hexdigest(content)
          if yml[id]["md5sum"] != md5sum
            yml[id]["md5sum"] = md5sum
            yml[id]["build_no"] += 1
            File.open(@tmp_dir.join(name + "-" + yml[id]["build_no"].to_s + ext), 'w') { |file| file.write(content) }
          end
          name + "-" + yml[id]["build_no"].to_s + ext
        end
      end
   
    end
  end
end
