require 'rubygems'
require 'active_support'
require 'active_support/test_case'

require 'mocha'

require 'rack'
require 'asset_server'

require "test/unit"

class AssetServerTest < Test::Unit::TestCase
  FIXTURE_PATH = "#{File.dirname(__FILE__)}/fixtures"

  App = Rack::Builder.new {
    map "/javascripts/all.js" do
      run Assets::BundleServer.new("#{FIXTURE_PATH}/javascripts/*.js")
    end

    map "/javascripts/all_foo.js" do
      run Assets::BundleServer.new("#{FIXTURE_PATH}/javascripts/*.js", "#{File.dirname(__FILE__)}/fixtures/plugins/foo/javascripts/*.js")
    end

    map "/javascripts/all_plugins.js" do
      run Assets::BundleServer.new("#{FIXTURE_PATH}/javascripts/*.js", "#{File.dirname(__FILE__)}/fixtures/plugins/**/javascripts/*.js")
    end

    map "/javascripts/none.js" do
      run Assets::BundleServer.new("#{FIXTURE_PATH}/stylesheets/*.js")
    end
  }

  def test_serves_javascript_assets_from_directory
    response = Rack::MockRequest.new(App).get("/javascripts/all.js")
    assert_equal "var bar;\n\n\nvar foo;", response.body
  end

  def test_serves_javascript_assets_from_all_and_plugin
    response = Rack::MockRequest.new(App).get("/javascripts/all_foo.js")
    assert_equal "var bar;\n\n\nvar foo;\n\nvar foo_plugin;", response.body
  end

  def test_serves_javascript_assets_from_all_and_all_plugins
    response = Rack::MockRequest.new(App).get("/javascripts/all_plugins.js")
    assert_equal "var bar;\n\n\nvar foo;\n\nvar bar_plugin;\n\nvar foo_plugin;", response.body
  end

  def test_serves_source_with_etag_headers
    response = Rack::MockRequest.new(App).get("/javascripts/all.js")
    assert_equal "\"b6d428092bf6479893474f9dd032faeb\"", response.headers["ETag"]
  end

  def test_updated_file_updates_the_last_modified
    response = Rack::MockRequest.new(App).get("/javascripts/all.js")
    time_before_touching = response.headers["Last-Modified"]

    response = Rack::MockRequest.new(App).get("/javascripts/all.js")
    time_after_touching = response.headers["Last-Modified"]

    assert_equal time_before_touching, time_after_touching

    touch_fixture("javascripts/bar.js")

    response = Rack::MockRequest.new(App).get("/javascripts/all.js")
    time_after_touching = response.headers["Last-Modified"]

    assert_not_equal time_before_touching, time_after_touching
  end

  def test_not_modified_response_when_headers_match
    touch_fixture("plugins/bar/javascripts/bar.js")

    response = Rack::MockRequest.new(App).get(
      "/javascripts/all_plugins.js",
      "HTTP_IF_MODIFIED_SINCE" => File.mtime("#{FIXTURE_PATH}/plugins/bar/javascripts/bar.js").httpdate
    )

    assert_equal 304, response.status
  end

  def test_if_sources_didnt_change_the_server_shouldnt_rebundle
    Rack::MockRequest.new(App).get("/javascripts/all.js")
    Assets::BundleServer::Asset.any_instance.expects(:new).never
    Rack::MockRequest.new(App).get("/javascripts/all.js")
  end

  def test_query_string_md5_sets_expiration_to_the_future
    response = Rack::MockRequest.new(App).get("/javascripts/all.js")
    etag = response.headers["ETag"]

    response = Rack::MockRequest.new(App).get("/javascripts/all.js?#{etag[1..-2]}")
    assert_match %r{max-age}, response.headers["Cache-Control"]
  end

  def test_server_with_no_sources
    response = Rack::MockRequest.new(App).get("/javascripts/none.js")
    assert_equal 404, response.status
  end

  private
    def touch_fixture(relative_path)
      `touch #{FIXTURE_PATH}/#{relative_path}`
    end
end
