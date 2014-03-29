require 'tempfile'
require 'securerandom'
require 'fileutils'

module Aweplug
  module Helpers


    class PngError < StandardError; end

    # A class for compressing PNGs.
    # Both lossy compression, and file format compression are performed
    class PNG

      attr_accessor :input, :output, :modified
      alias :modified? :modified

      # Public: Initialization of the object.
      # input - The contents of a PNG
      def initialize(input)
        @input = input
      end

      # Public: Perform compression.
      # If the PNG can be compressed, the attribute modified will be set to true.
      def compress
        input_len = @input.bytesize
        tmp = optipng(quantize(@input))

        # Check to see whether we've improved the situation
        output_len = tmp.bytesize
        if input_len > output_len
          $LOG.debug " %d bytes -> %d bytes = %.1f%%" % [ input_len, output_len, 100 * output_len/input_len ] if $LOG.debug?
          @output = tmp
          @modified = true
        else
          $LOG.debug " no gain" if $LOG.debug?
          @output = @input
          @modified = false
        end
        self
      end

      private

      # Private: Optipng is currently the best program out there to
      # perform compression on the PNG file format. It is lossless.
      def optipng(content)
        input = Tempfile.new([SecureRandom.hex(16), ".png"])
        output = Tempfile.new([SecureRandom.hex(16), ".png"])
        begin
          raise PngError, "optipng not found in PATH=#{ENV['PATH']}" unless which("optipng")
          # Make sure the files are in the right state before we run the shell process
          output_path = output.to_path
          input_path = input.to_path
          input.write(content)
          input.close
          output.close
          cmd = "optipng -quiet -force -clobber -out #{output_path} #{input_path} "
          `#{cmd}`
          if $?.exitstatus != 0
            raise "Failed to execute optipng: #{cmd}"
          end
          File.read output_path
        ensure
          input.unlink
          output.unlink
        end
      end

      # Private: pngquant is currently the best program out there to
      # perform lossy compression on PNGs without damaging the quality
      def quantize(content, colors = 256)
        raise PngError, "pngquant not found in PATH=#{ENV['PATH']}" unless which("pngquant")
        out = ""
        exit_code, err_msg = Open3.popen3("pngquant #{colors}") do |stdin, stdout, stderr, wait_thr|
          stdin.write(content)
          out << stdout.read
          [wait_thr.value, stderr.gets(nil)]
        end

        raise(PngError, err_msg) if exit_code != 0
        out
      end

      # Private: locate the executable
      def which(cmd)
        exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
          exts.each { |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return exe if File.executable? exe
          }
        end

        nil
      end

    end

    # A class which extends PNG, adding support for compressing a file in situ
    class PNGFile < PNG

      # Public: Initialization of the object.
      # file_path - The file to compress
      def initialize(file_path)
        raise ArgumentError, "could not find #{file_path}" unless File.file?(file_path)
        @file_path = file_path
        super File.read(@file_path)
      end

      # Public: Compress a PNG in situ
      def compress!
        File.open(@file_path, 'w') { |file| file.write(output) } if compress.modified?
        self
      end

    end

  end
end
