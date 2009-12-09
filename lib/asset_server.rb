require 'digest/md5'
require 'time'

module Assets
  class BundleServer
    class Asset
      attr_reader :source, :md5, :etag, :created_at

      def initialize(sources)
        @sources    = sources
        @source     = concate_source
        @md5        = compute_md5
        @etag       = quoted_md5
        @created_at = last_modified

        freeze
      end

      def stale?
        @created_at < last_modified
      end

      private
        def concate_source
          @sources.collect { |file| File.read(file) }.join("\n\n")
        end

        def compute_md5
          Digest::MD5.hexdigest(@source)
        end

        def quoted_md5
          %("#{@md5}")
        end

        def last_modified
          @sources.collect { |file| File.mtime(file) }.sort.last
        end
    end

    def initialize(*paths)
      @sources = paths.map { |path| Dir[path] }.flatten
      @lock = Mutex.new
    end

    def call(env)
      return not_found_response if @sources.empty?

      asset = rebundle(env)

      if not_modified?(asset, env) || etag_match?(asset, env)
        not_modified_response(asset, env)
      else
        ok_response(asset, env)
      end
    end

    private
      def source_changed?(asset)
        asset.nil? || asset.stale?
      end

      def rebundle(env)
        if env["rack.multithread"]
          synchronized_rebundle
        else
          rebundle!
        end
      end

      def synchronized_rebundle
        asset = @asset
        if source_changed?(asset)
          @lock.synchronize { rebundle! }
        else
          asset
        end
      end

      def rebundle!
        if source_changed?(@asset)
          @asset = Asset.new(@sources)
        end
        @asset
      end


      def not_found_response
        [ 404, { "Content-Type" => "text/plain", "Content-Length" => "9" }, [ "Not found" ] ]
      end

      def not_modified?(asset, env)
        env["HTTP_IF_MODIFIED_SINCE"] == asset.created_at.httpdate
      end

      def etag_match?(asset, env)
        env["HTTP_IF_NONE_MATCH"] == asset.etag
      end

      def not_modified_response(asset, env)
        [ 304, headers(asset, env), [] ]
      end

      def ok_response(asset, env)
        [ 200, headers(asset, env), [asset.source] ]
      end

      def headers(asset, env)
        Hash.new.tap do |headers|
          headers["Content-Type"]   = "text/javascript"
          headers["Content-Length"] = asset.source.size.to_s

          headers["Cache-Control"]  = "public, must-revalidate"
          headers["Last-Modified"]  = asset.created_at.httpdate
          headers["ETag"]           = asset.etag

          if env["QUERY_STRING"] == asset.md5
            headers["Cache-Control"] << ", max-age=#{1.year.to_i}"
          end
        end
      end
  end
end
