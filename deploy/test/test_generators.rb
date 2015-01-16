require 'minitest/autorun'
require 'server_config'
require 'framework'
require 'Help'
require 'util'

describe Roxy::Framework do

  before do
    # initialize roxy or these tests will fail
    ARGV.push "roxy"
    ARGV.push "--server-version=7"
    ARGV.push "--app-type=hybrid"
    begin
      ServerConfig.init
    rescue HelpException
    end

    ARGV.clear
  end

  describe "when creating a model" do

    before do
      @properties = ServerConfig.properties
      @logger = Logger.new(STDOUT)
      @src_dir = @properties["ml.xquery.dir"]
      @final_file = File.expand_path("#{@src_dir}/app/models/unit_test_delme.xqy")
      @framework = Roxy::Framework.new :logger => @logger, :properties => @properties

      def Help.reset_do_help()
        @do_help_called = false
      end

      def Help.do_help_called?()
        @do_help_called ||= false
        return @do_help_called
      end

      # stub the dohelp method
      def Help.doHelp(logger, command, error_message = nil)
        @do_help_called = true
        return true
      end

      Help.reset_do_help()
    end

    it "should not already exist" do
      File.exists?(@final_file).must_equal false
    end

    it "should show help with < 2 params" do
      ARGV.length.must_equal 0
      ARGV.push "model"
      Help.do_help_called?.must_equal false
      @framework.create
      Help.do_help_called?.must_equal true
    end

    it "should created a model with 2 params" do
      ARGV.length.must_equal 0
      ARGV.push "model"
      ARGV.push "unit_test_delme"
      Help.do_help_called?.must_equal false
      @framework.create
      Help.do_help_called?.must_equal false

      File.exists?(@final_file).must_equal true
      File.read(@final_file).must_match /module namespace m = "http:\/\/marklogic.com\/roxy\/models\/unit_test_delme";/

      FileUtils.rm @final_file
    end

    it "should created a model with 3 params" do
      ARGV.length.must_equal 0
      ARGV.push "model"
      ARGV.push "test_delme"
      ARGV.push "unit_test_delme"
      @framework.create

      File.exists?(@final_file).must_equal true
      File.read(@final_file).wont_match /m:blah/
      File.read(@final_file).must_match /module namespace m = "http:\/\/marklogic.com\/roxy\/models\/test_delme";/

      FileUtils.rm @final_file
    end

    it "should created a model with 2 params and a function name" do
      ARGV.length.must_equal 0
      ARGV.push "model"
      ARGV.push "unit_test_delme/blah"
      @framework.create

      File.exists?(@final_file).must_equal true

      File.read(@final_file).must_match /m:blah/

      FileUtils.rm @final_file
    end
  end
end
