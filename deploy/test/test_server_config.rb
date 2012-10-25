require 'test/unit'
require 'server_config'
require 'util'

class TestProperties < Test::Unit::TestCase
  def test_load_properties
    properties = ServerConfig.load_properties(File.expand_path("../data/ml6-properties/default.properties", __FILE__), "test.")
    assert(properties.is_a?(Hash))
    assert_equal('admin-user', properties['test.user'])
    assert_equal('admin-user', properties['test.password'])
    assert_equal('roxy-unit-tests', properties['test.app-name'])
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
    assert_equal('roxy-unit-tests', properties['ml.app-name'])
  end

  def test_build_config
  end

  def test_bootstrap
    # cheat the local environment into the command line
    ARGV << "local"

    properties = ServerConfig.properties(File.expand_path("../data/ml4-properties/", __FILE__))
    ServerConfig.logger.debug(properties)
    s = ServerConfig.new({
        :config_file => File.expand_path("../data/ml4-config.xml", __FILE__),
        :properties => properties,
        :logger => Logger.new(STDOUT)
      })

    s.bootstrap
    assert(s.validate_install, "Bootstrap passes validation")

    s.bootstrap
    assert(s.validate_install, "Bootstrap passes validation")

    s.wipe
  end
end