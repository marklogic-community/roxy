#
# Put your custom functions in this class in order to keep the files under lib untainted
#
# This class has access to all of the stuff in deploy/lib/server_config.rb
#
class ServerConfig
  def my_custom_method()
    @logger.info(@properties["ml.content-db"])
  end
end