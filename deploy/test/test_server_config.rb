require 'test/unit'
require 'server_config'
require 'util'

class TestProperties < Test::Unit::TestCase

  def teardown
    @s.wipe if @s
  end

  def test_load_properties
    properties = ServerConfig.load_properties(File.expand_path("../data/ml6-properties/default.properties", __FILE__), "test.")
    assert(properties.is_a?(Hash))
    assert_equal('admin', properties['test.user'])
    assert_equal('admin', properties['test.password'])
    assert_equal('roxy', properties['test.app-name'])
  end

  def test_substitute_properties
    sub_me = { 'username' => 'bob-${last-name}', 'password' => '123' }
    with_me = { 'last-name' => 'smith' }
    properties = ServerConfig.substitute_properties(sub_me, with_me)
    assert(properties.is_a?(Hash))
    assert_equal('bob-smith', properties['username'])
    assert_equal('123', properties['password'])

    sub_me = { 'username' => 'bob-${last-name}', 'password' => '123' }
    with_me = { 'ml.last-name' => 'smith' }
    properties = ServerConfig.substitute_properties(sub_me, with_me, "ml.")
    assert(properties.is_a?(Hash))
    assert_equal('bob-smith', properties['username'])
    assert_equal('123', properties['password'])
  end

  def test_properties
    properties = ServerConfig.properties(File.expand_path("../data/ml6-properties/", __FILE__))
    assert(properties.is_a?(Hash))
    assert_equal('admin', properties['ml.user'])
    assert_equal('admin', properties['ml.password'])
    assert_equal('roxy-deployer-tester', properties['ml.app-name'])
  end

  def test_build_config
  end

  def bootstrap_version(version)
    # cheat the local environment into the command line
    ARGV << "local"

    properties = ServerConfig.properties(File.expand_path("../data/ml#{version}-properties/", __FILE__))
    @s = ServerConfig.new({
        :config_file => File.expand_path("../data/ml#{version}-config.xml", __FILE__),
        :properties => properties,
        :logger => Logger.new(STDOUT)
      })

    assert(@s.bootstrap, "Boostrap should succeeded")
    assert(@s.validate_install, "Bootstrap passes validation")

    assert(@s.bootstrap, "Boostrap should succeeded")
    assert(@s.validate_install, "Bootstrap passes validation")
  end

  def test_bootstrap
    version = ENV['ROXY_TEST_SERVER_VERSION'] ||  4
    bootstrap_version version
  end
end