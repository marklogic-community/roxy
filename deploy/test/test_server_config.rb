require 'minitest/autorun'
require 'minitest/mock'
require 'server_config'
require 'util'

describe ServerConfig do

  describe "load_properties" do
    before do
      @properties = ServerConfig.load_properties(File.expand_path("../data/ml6-properties/default.properties", __FILE__), "test.")
    end

    it "should load the properties" do
      @properties.must_be_kind_of Hash
      @properties['test.user'].must_equal 'admin'
      @properties['test.password'].must_equal 'admin'
      @properties['test.app-name'].must_equal 'roxy'
    end
  end

  describe "substitute_properties" do

    it "should substitute properties" do
      sub_me = { 'username' => 'bob-${last-name}', 'password' => '123' }
      with_me = { 'last-name' => 'smith' }
      properties = ServerConfig.substitute_properties(sub_me, with_me)

      properties.must_be_kind_of Hash

      properties['username'].must_equal 'bob-smith'
      properties['password'].must_equal '123'
    end

    it "should substitute properties with a prefix" do
      sub_me = { 'username' => 'bob-${last-name}', 'password' => '123' }
      with_me = { 'ml.last-name' => 'smith' }
      properties = ServerConfig.substitute_properties(sub_me, with_me, "ml.")

      properties.must_be_kind_of Hash

      properties['username'].must_equal 'bob-smith'
      properties['password'].must_equal '123'
    end
  end

  describe "load properties" do

    it "should load properties from a file" do
      properties = ServerConfig.properties(File.expand_path("../data/ml6-properties/", __FILE__))

      properties.must_be_kind_of Hash
      properties['ml.user'].must_equal 'admin'
      properties['ml.password'].must_equal 'admin'
      properties['ml.app-name'].must_equal 'roxy-deployer-tester'
    end
  end

  describe "bootstrap" do

    before do
      @version = ENV['ROXY_TEST_SERVER_VERSION'] || 7
      @logger = Logger.new(STDOUT)
      @logger.info "Testing against MarkLogic version #{@version}.."

      # cheat the local environment into the command line
      ARGV << "local"

      @properties = ServerConfig.properties(File.expand_path("../data/ml#{@version}-properties/", __FILE__))
      @s = ServerConfig.new({
          :config_file => File.expand_path("../data/ml#{@version}-config.xml", __FILE__),
          :properties => @properties,
          :logger => @logger
        })
      r = @s.execute_query %Q{xdmp:host-name(xdmp:host())}
      r.body = parse_json(r.body)
      @properties['ml.bootstrap-host'] = r.body

      @s.bootstrap.must_equal true
      @s.validate_install.must_equal true
    end

    it "should bootstrap successfully twice consecutively" do
      @s.bootstrap.must_equal true
      @s.validate_install.must_equal true
    end

    it "should bootstrap a changed config file" do
      changed_config = File.expand_path("../data/ml#{@version}-config-changed.xml", __FILE__)

      if File.exists?(changed_config)
        @s = ServerConfig.new({
            :config_file => changed_config,
            :properties => @properties,
            :logger => @logger
          })

        @s.bootstrap.must_equal true
        @s.validate_install.must_equal true
      end
    end

    after do
      @logger.info "Wiping self-test deployment.."
      @s.wipe

      sleep(10)
    end
  end

  # issue #228
  describe "load properties from command" do

    before do
      ARGV << "--ml.yoda-age=900"
      ARGV << "--ml.missing-key=val1"

      @logger = MiniTest::Mock.new
      @logger.expect :warn, nil, ["Property ml.missing-key does not exist. It will be skipped."]

      ServerConfig.logger = @logger
      @properties = ServerConfig.properties(File.expand_path("../data/ml7-properties/", __FILE__))
    end

    it "should warn the user when missing keys are provided" do
      @logger.verify.must_equal true
    end

    it "should load valid properites from a command" do
      @properties['ml.yoda-age'].must_equal '900'
    end

    it "should not set missing keys" do
      @properties.has_key?('missing-key').wont_equal true
    end

    after do
      ARGV.shift
      ARGV.shift
    end
  end

  describe "test_credentials" do

    before do
      ARGV << "local"

      test_env = "blah"
      properties = ServerConfig.properties

      properties["environment"] = test_env
      properties["ml.environment"] = test_env

      @s = ServerConfig.new({
        :config_file => File.expand_path(properties["ml.config.file"], __FILE__),
        :properties => properties,
        :logger => Logger.new(STDOUT)
      })

      filename = "#{test_env}.properties"
      path = ServerConfig.path
      @properties_file = ServerConfig.expand_path("#{path}/#{filename}")
    end

    it "should prompt the user for credentials" do
      File.exists?(@properties_file).must_equal false

      with_stdin do |user|
        user.puts "bob"
        user.puts "smith"
        @s.credentials
      end

      File.exists?(@properties_file).must_equal true

      props_data = File.read(@properties_file)

      user = $1 if props_data =~ /user=(\w+)/
      password = $1 if props_data =~ /password=(\w+)/

      user.must_equal 'bob'
      password.must_equal 'smith'
    end

    after do
      File.delete(@properties_file)
      @s = nil
    end

  end


  def with_stdin
    stdin = $stdin             # remember $stdin
    $stdin, write = IO.pipe    # create pipe assigning its "read end" to $stdin
    yield write                # pass pipe's "write end" to block
  ensure
    write.close                # close pipe
    $stdin = stdin             # restore $stdin
  end
end
