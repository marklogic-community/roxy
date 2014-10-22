require 'test/unit'
require 'util'

class TestProperties < Test::Unit::TestCase

  def teardown
  end

  # test for issue #177
  def test_xquery_safe_unsafe
    assert_equal('secret', 'secret'.xquery_safe.xquery_unsafe)
    assert_equal('crazypassword{123@#$%}},.<>', 'crazypassword{123@#$%}},.<>'.xquery_safe.xquery_unsafe)
  end

end
