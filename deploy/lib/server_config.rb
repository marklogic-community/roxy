###############################################################################
# Copyright 2012-2015 MarkLogic Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################
require 'util'
require 'uri'
require 'net/http'
require 'fileutils'
require 'json'
require 'RoxyHttp'
require 'xcc'
require 'MLClient'
require 'date'
require 'ml_rest'
require 'time'
require 'tmpdir'

class ExitException < Exception; end

class HelpException < Exception
  attr_reader :command, :message
  def initialize(command, message = nil)
    @command = command
    @message = message
  end
end

class DanglingVarsException < Exception
  def initialize(vars)
    @vars = vars
  end

  def vars
    return @vars
  end
end

class ServerConfig < MLClient

  # needed to determine if Roxy is running inside a jar
  @@is_jar = is_jar?
  @@path = @@is_jar ? "./deploy" : "../.."
  @@context = @@is_jar ? Dir.pwd : __FILE__

  def self.path
    @@path
  end

  def initialize(options)
    @options = options

    @properties = options[:properties]
    @environment = @properties["environment"]
    @config_file = @properties["ml.config.file"]

    @properties["ml.server"] = @properties["ml.#{@environment}-server"] unless @properties["ml.server"]
    if (@properties["ml.server"] == nil)
      raise "Error! ml.server not set. You may be missing deploy/" + @properties["environment"] + ".properties"
    end

    @hostname = @properties["ml.server"]
    @bootstrap_port_four = @properties["ml.bootstrap-port-four"]
    @bootstrap_port_five = @properties["ml.bootstrap-port-five"]
    @use_https = @properties["ml.use-https"] == "true"
    @protocol = "http#{@use_https ? 's' : ''}"

    super(
      :user_name => @properties["ml.user"],
      :password => @properties["ml.password"],
      :logger => options[:logger],
      :no_prompt => options[:no_prompt],
      :http_connection_retry_count => @properties["ml.http.retry-count"].to_i,
      :http_connection_open_timeout => @properties["ml.http.open-timeout"].to_i,
      :http_connection_read_timeout => @properties["ml.http.read-timeout"].to_i,
      :http_connection_retry_delay => @properties["ml.http.retry-delay"].to_i
    )

    @server_version = @properties["ml.server-version"].to_i

    if (@server_version < 7)
      logger.warn "WARN: This version of Roxy is not tested against MarkLogic #{@server_version}."
      if (@server_version > 4)
        logger.info "      Consider downgrading to v1.7.0 using `./ml upgrade --branch=v1.7.0`."
      end
      logger.warn "Note: MarkLogic #{@server_version} is EOL."
    end

    if @properties["ml.bootstrap-port"]
      @bootstrap_port = @properties["ml.bootstrap-port"]
    else
      if @server_version == 4
        @bootstrap_port = @bootstrap_port_four
      else
        @bootstrap_port = @bootstrap_port_five
        @properties["ml.bootstrap-port"] = @bootstrap_port
      end
    end

    if @properties['ml.qconsole-port']
      @qconsole_port = @properties['ml.qconsole-port']
    else
      @qconsole_port = @bootstrap_port
    end

    begin
      r = execute_query %Q{xdmp:host-name()}
      @properties["ml.server-name"] = parse_body(r.body)
    rescue
      logger.warn "WARN: unable to determine MarkLogic Host name of #{@hostname}"
    end

    @properties["ml.password"] = @ml_password

    begin
      r = execute_query %Q{ substring-before(xdmp:version(), ".") }
      r.body = parse_body r.body
      if r.body.to_i != @server_version
        logger.warn "WARN: #{@hostname} is running MarkLogic #{r.body}, but server-version is set to #{@server_version}!"
      end
    rescue
      logger.warn "WARN: unable to determine MarkLogic Version of #{@hostname}"
    end
  end

  def get_properties
    return @properties
  end

  def info
    format = find_arg(['--format'])
    info = {}
    info["isJar"] = @@is_jar
    info["properties"] = @properties
    if format == "json"
      logger.info "#{JSON.pretty_generate(info)}"
    elsif format == "xml"
      logger.info "<info>"
      logger.info "\s\s<isJar>#{@@is_jar}</isJar>"
      logger.info "\s\s<properties>"
      # applying ascending order for better readability
      @properties.sort {|x,y| x <=> y}.each do |k, v|
        logger.info "\s\s\s\s<property name=\"#{k}\">#{v}</property>"
      end
      logger.info "\s\s</properties>"
      logger.info "</info>"
    else
      logger.info "IS_JAR: #{@@is_jar}"
      logger.info "Properties:"
      @properties.sort {|x,y| x <=> y}.each do |k, v|
        logger.info k + ": " + v.to_s
      end
    end
    return true
  end

  # This method exists to return a path relative to roxy
  # when running as regular old Roxy or as a jar
  def ServerConfig.expand_path(path)
#    logger.info("path: #{path}")
#    logger.info("context: #{@@context}")
    result = File.expand_path(path, @@context)
#    logger.info("result: #{result}")
    return result
  end

  def ServerConfig.strip_path(path)
    basepath = File.expand_path(@@path + "/..", @@context)
    return path.sub(basepath + '/', '')
  end

  def self.jar
    raise HelpException.new("jar", "You must be using JRuby to create a jar") unless RUBY_PLATFORM == "java"
    begin
      # ensure warbler gem is installed
      gem 'warbler'
      require 'warbler'

      jar_file = ServerConfig.expand_path("#{@@path}/../roxy.jar")
      logger.debug(jar_file)
      Dir.mktmpdir do |tmp_dir|
        logger.debug(tmp_dir)

        temp_roxy_dir = tmp_dir + "/roxy"
        Dir.mkdir temp_roxy_dir

        FileUtils.mkdir_p temp_roxy_dir + "/bin"
        FileUtils.cp(ServerConfig.expand_path("#{@@path}/lib/ml.rb"), temp_roxy_dir + "/bin/roxy.rb")

        FileUtils.cp_r(ServerConfig.expand_path("#{@@path}/lib"), temp_roxy_dir)
        FileUtils.cp_r(ServerConfig.expand_path("#{@@path}/sample"), temp_roxy_dir)

        Dir.chdir(temp_roxy_dir) do
          Warbler::Application.new.run
          FileUtils.cp(Dir.glob("*.jar")[0], jar_file)
        end
      end
      return true
    rescue Gem::LoadError
      raise HelpException.new("jar", "Please install the warbler gem")
    end
  end

  def self.init
    # input files
    if @@is_jar
      sample_config = "roxy/sample/ml-config.sample.xml"
      sample_properties = "roxy/sample/build.sample.properties"
      sample_options = "roxy/sample/all.sample.xml"
      sample_rest_properties = "roxy/sample/properties.sample.xml"
      sample_app_config = "roxy/deploy/sample/custom-config.xqy"
    else
      sample_config = ServerConfig.expand_path("#{@@path}/sample/ml-config.sample.xml")
      sample_properties = ServerConfig.expand_path("#{@@path}/sample/build.sample.properties")
      sample_options = ServerConfig.expand_path("#{@@path}/sample/all.sample.xml")
      sample_rest_properties = ServerConfig.expand_path("#{@@path}/sample/properties.sample.xml")
      sample_app_config = ServerConfig.expand_path("#{@@path}/sample/custom-config.xqy")
    end

    # output files
    build_properties = ServerConfig.expand_path("#{@@path}/build.properties")
    options_file = ServerConfig.expand_path("#{@@path}/../rest-api/config/options/all.xml")
    rest_properties = ServerConfig.expand_path("#{@@path}/../rest-api/config/properties.xml")
    app_config = ServerConfig.expand_path("#{@@path}/../src/config/config.xqy")

    # dirs to create
    rest_ext_dir = ServerConfig.expand_path("#{@@path}/../rest-api/ext")
    rest_transforms_dir = ServerConfig.expand_path("#{@@path}/../rest-api/transforms")
    options_dir = ServerConfig.expand_path("#{@@path}/../rest-api/config/options")
    config_dir = ServerConfig.expand_path("#{@@path}/../src/config")

    # get supplied options
    force = find_arg(['--force']).present?
    force_props = find_arg(['--force-properties']).present?
    force_config = find_arg(['--force-config']).present?
    app_type = find_arg(['--app-type'])
    server_version = find_arg(['--server-version'])

    # Check for required --server-version argument value
    if (!server_version.present? || server_version == '--server-version' || !(%w(4 5 6 7 8 9).include? server_version))
      server_version = prompt_server_version
    end

    error_msg = []
    if !force && !force_props && File.exists?(build_properties)
      error_msg << "build.properties has already been created."
    else
      #create clean properties file
      copy_file sample_properties, build_properties

      properties_file = File.read(build_properties)

      # replace the appname if one is provided
      name = ARGV.shift
      properties_file.gsub!(/app-name=roxy/, "app-name=#{name}") if name

      # do app-type customizations
      properties_file.gsub!(/app-type=mvc/, "app-type=#{app_type}")

      # If this app will use the ML REST API, we need rewrite-resolved-globally to get those URLs to work
      if ["rest", "hybrid"].include? app_type
        properties_file.gsub!(/rewrite-resolves-globally=/, "rewrite-resolves-globally=true")
      end

      if app_type == "bare"
        # bare applications don't use rewriter and error handler
        properties_file.gsub!(/url-rewriter=\/roxy\/rewrite.xqy/, "url-rewriter=")
        properties_file.gsub!(/error-handler=\/roxy\/error.xqy/, "error-handler=")
      elsif app_type == "rest"
        # rest applications don't use Roxy's MVC structure, so they can use MarkLogic's rewriter and error handler
        # Note: ML8 rest uses the new native rewriter
        rewriter_name = (server_version.to_i >= 8) ? "rewriter.xml" : "rewriter.xqy"
        properties_file.gsub!(/url-rewriter=\/roxy\/rewrite.xqy/, "url-rewriter=/MarkLogic/rest-api/" + rewriter_name)
        properties_file.gsub!(/error-handler=\/roxy\/error.xqy/, "error-handler=/MarkLogic/rest-api/error-handler.xqy")
      end

      # replace the text =random with a random string
      o = (33..126).to_a
      properties_file.gsub!(/=random/) do |match|
        random = (0...20).map{ o[rand(o.length)].chr }.join
        "=#{random}"
      end

      # Update properties file to set server-version to value specified on command-line
      properties_file.gsub!(/server-version=6/, "server-version=#{server_version}")

      if ["rest", "bare"].include? app_type
        properties_file.gsub!(/application-conf-file=src\/app\/config\/config.xqy/, 'application-conf-file=src/config/config.xqy')
      end

      # save the replacements
      open(build_properties, 'w') {|f| f.write(properties_file) }
    end

    # If this is a rest or hybrid app, set up some initial options
    if ["rest", "hybrid"].include? app_type
      FileUtils.mkdir_p rest_ext_dir
      FileUtils.mkdir_p rest_transforms_dir
      FileUtils.mkdir_p options_dir
      copy_file sample_options, options_file
      copy_file sample_rest_properties, rest_properties
    end

    if ["rest", "bare"].include? app_type
      FileUtils.mkdir_p config_dir
      copy_file sample_app_config, app_config
    end

    target_config = ServerConfig.expand_path(ServerConfig.properties["ml.config.file"])

    if !force && !force_config && File.exists?(target_config)
      error_msg << "ml-config.xml has already been created."
    else
      #create clean marklogic configuration file
      copy_file sample_config, target_config
    end

    raise HelpException.new("init", error_msg.join("\n")) if error_msg.length > 0

    return true
  end

  def self.initcpf
    if @@is_jar
      sample_config = "roxy/sample/pipeline-config.sample.xml"
    else
      sample_config = ServerConfig.expand_path("#{@@path}/sample/pipeline-config.sample.xml")
    end
    target_config = ServerConfig.expand_path(ServerConfig.properties["ml.pipeline-config-file"])

    force = find_arg(['--force']).present?
    if !force && File.exists?(target_config)
      raise HelpException.new("initcpf", "cpf configuration has already been created.")
    else
      copy_file sample_config, target_config
    end
    return true
  end

  def self.prompt_server_version
    if @@no_prompt
      puts 'Required option --server-version=[version] not specified with valid value,
but --no-prompt parameter prevents prompting for password.'
      server_version = 0
    else
      puts 'Required option --server-version=[version] not specified with valid value.

  What is the version number of the target MarkLogic server? [7, 8, or 9]'
      server_version = STDIN.gets.chomp.to_i
    end
    if server_version == 0
      puts "Defaulting to 9.."
      server_version = 9
    end
    server_version
  end

  def self.index
    if @@no_prompt
      raise ExitException.new("--no-prompt parameter prevents prompting for input")
    else
      puts "What type of index do you want to build?
    1 element range index
    2 attribute range index"
      # TODO:
      # 3 field range index
      # 4 geospatial index
      type = STDIN.gets.chomp.to_i
      if type == 1
        build_element_index
      elsif type == 2
        build_attribute_element_index
      else
        puts "Sorry, I don't know how to do that yet"
      end
    end
  end

  def self.request_type
    if @@no_prompt
      raise ExitException.new("--no-prompt parameter prevents prompting for input")
    else
      scalar_types = %w[int unsignedInt long unsignedLong float double decimal dateTime
        time date gYearMonth gYear gMonth gDay yearMonthDuration dayTimeDuration string anyURI]
      puts "What will the scalar type of the index be [1-" + scalar_types.length.to_s + "]? "
      i = 1
      for t in scalar_types
        puts "#{i} #{t}"
        i += 1
      end
      scalar = STDIN.gets.chomp.to_i
      scalar_types[scalar - 1]
    end
  end

  def self.request_collation
    if @@no_prompt
      raise ExitException.new("--no-prompt parameter prevents prompting for input")
    else
      puts "What is the collation URI (leave blank for the root collation)?"
      collation = STDIN.gets.chomp
      collation = "http://marklogic.com/collation/" if collation.blank?
      collation
    end
  end

  def self.request_range_value_positions
    if @@no_prompt
      raise ExitException.new("--no-prompt parameter prevents prompting for input")
    else
      puts "Turn on range value positions? [y/N]"
      positions = STDIN.gets.chomp.downcase
      if positions == "y"
        positions = "true"
      else
        positions = "false"
      end
      positions
    end
  end

  def self.inject_index(key, index)
    properties = ServerConfig.properties
    config_path = ServerConfig.expand_path(properties["ml.config.file"])
    existing = File.read(config_path)
    existing = existing.gsub(key) { |match| "#{match}\n#{index}" }
    File.open(config_path, "w") { |file| file.write(existing) }
  end

  def self.build_attribute_element_index
    if @@no_prompt
      raise ExitException.new("--no-prompt parameter prevents prompting for input")
    else
      scalar_type = request_type
      puts "What is the parent element's namespace URI?"
      p_uri = STDIN.gets.chomp
      puts "What is the parent element's localname?"
      p_localname = STDIN.gets.chomp
      puts "What is the attribute's namespace URI?"
      uri = STDIN.gets.chomp
      puts "What is the attribute's localname?"
      localname = STDIN.gets.chomp
      collation = request_collation if scalar_type == "string"
      positions = request_range_value_positions
      index = "        <range-element-attribute-index>
            <scalar-type>#{scalar_type}</scalar-type>
            <parent-namespace-uri>#{p_uri}</parent-namespace-uri>
            <parent-localname>#{p_localname}</parent-localname>
            <namespace-uri>#{uri}</namespace-uri>
            <localname>#{localname}</localname>
            <collation>#{collation}</collation>
            <range-value-positions>#{positions}</range-value-positions>
          </range-element-attribute-index>"

      properties = ServerConfig.properties
      puts "Add this index to #{properties["ml.config.file"]}? [y/N]\n" + index
      approve = STDIN.gets.chomp.downcase
      if approve == "y"
        inject_index("<range-element-attribute-indexes>", index)
        puts "Index added"
      end
    end
  end

  def self.build_element_index
    if @@no_prompt
      raise ExitException.new("--no-prompt parameter prevents prompting for input")
    else
      scalar_type = request_type
      puts "What is the element's namespace URI?"
      uri = STDIN.gets.chomp
      puts "What is the element's localname?"
      localname = STDIN.gets.chomp
      collation = request_collation if scalar_type == "string" # string
      positions = request_range_value_positions
      index = "        <range-element-index>
            <scalar-type>#{scalar_type}</scalar-type>
            <namespace-uri>#{uri}</namespace-uri>
            <localname>#{localname}</localname>
            <collation>#{collation}</collation>
            <range-value-positions>#{positions}</range-value-positions>
          </range-element-index>"
      properties = ServerConfig.properties
      puts "Add this index to #{properties["ml.config.file"]}? [y/N]\n" + index
      approve = STDIN.gets.chomp.downcase
      if approve == "y"
        inject_index("<range-element-indexes>", index)
        puts "Index added"
      end
    end
  end

  def self.howto
    begin
      optional_require 'open-uri'
      optional_require 'nokogiri'

      search = ARGV.first

      doc = Nokogiri::HTML(open("https://github.com/marklogic/roxy/wiki/_pages"))

      pages = doc.css('.content').select do |page|
        search == nil or page.text.downcase().include? search
      end

      selected = 1

      if pages.length > 1
        count = 0
        pages.each do |page|
          count = count + 1
          puts "#{count} - #{page.text}\n\thttps://github.com/#{page.xpath('a/@href').text}"
        end

        print "Select a page: "
        selected = STDIN.gets.chomp().to_i
        if selected == 0
          return
        end

        if selected > pages.length
          selected = pages.length
        end
      end

      count = 0
      pages.each do |page|
        count = count + 1
        if count == selected

          puts "\n#{page.text}\n\thttps://github.com/#{page.xpath('a/@href').text}"

          uri = "https://github.com/#{page.xpath('a/@href').text}"
          doc = Nokogiri::HTML(open(uri))

          puts doc.css('.markdown-body').text.gsub(/\n\n\n+/, "\n\n")

        end
      end
    rescue NameError => e
      puts "Missing library: #{e}"
    end
  end

  def execute_query(query, properties = {})
    r = nil
    if @server_version == 4
      r = execute_query_4 query, properties
    elsif @server_version == 5 || @server_version == 6
      r = execute_query_5 query, properties
    elsif @server_version == 7
      r = execute_query_7 query, properties
    else # 8 or 9
      r = execute_query_8 query, properties
    end

    raise ExitException.new(r.body) unless r.code.to_i == 200

    return r
  end

  def restart_group(group = nil, legacy = false)
    logger.debug "group: #{group}"
    logger.debug "legacy: #{legacy}"

    if ! group
      # Note:
      # Restarting partial cluster is unsafe when working with multiple groups.
      # Therefor restart entire cluster by default..
      group = "cluster"
    end

    if group == "cluster"
      logger.info "Restarting MarkLogic Server cluster of #{@hostname}"
    else
      logger.info "Restarting MarkLogic Server group #{group}"
    end

    if @server_version > 7 && !legacy
      # MarkLogic 8+, make use of Management REST api and return details of all involved hosts

      if group == "cluster"
        r = go(%Q{http://#{@properties["ml.server"]}:#{@properties["ml.bootstrap-port"]}/manage/v2?format=json}, "post", {
          'Content-Type' => 'application/json'
        }, nil, %Q{
          { "operation": "restart-local-cluster" }
        })
      else
        r = go(%Q{http://#{@properties["ml.server"]}:#{@properties["ml.bootstrap-port"]}/manage/v2/groups/#{group}?format=json}, "post", {
          'Content-Type' => 'application/json'
        }, nil, %Q{
          { "operation": "restart-group" }
        })
      end

      raise ExitException.new(r.body) unless r.code.to_i == 202

      return JSON.parse(r.body)['restart']['last-startup']
    else
      # MarkLogic 7- fallback, restart as before, and only verify restart of bootstrap host

      old_timestamp = go(%Q{http://#{@properties["ml.server"]}:8001/admin/v1/timestamp}, "get").body

      setup = File.read ServerConfig.expand_path("#{@@path}/lib/xquery/setup.xqy")
      r = execute_query %Q{#{setup} setup:do-restart("#{group}")}
      logger.debug "code: #{r.code.to_i}"

      r.body = parse_body(r.body)
      logger.info r.body

      return [{
        'host-id' => @properties["ml.server"],
        'value' => old_timestamp
      }]
    end
  end

  def get_host_names
    r = go(%Q{http://#{@properties["ml.server"]}:8002/manage/v2/hosts?format=json}, "get")

    raise ExitException.new(r.body) unless r.code.to_i == 200

    names = { @properties["ml.server"] => @properties["ml.server"] } # ml7 fallback

    JSON.parse(r.body)['host-default-list']['list-items']['list-item'].each do |host|
      names[host['idref']] = host['nameref']
    end

    return names
  end

  def restart
    # Default to verified restart
    verify = find_arg(['--no-verify']) == nil  && find_arg(['--verify']) != 'false'
    # Default to using Management Rest api (if available)
    legacy = find_arg(['--legacy']) != nil

    logger.debug "verify: #{verify}"
    logger.debug "legacy: #{legacy}"

    group = next_arg("^[^-]")

    @ml_username = @properties['ml.bootstrap-user'] || @properties['ml.user']
    if @ml_username == @properties['ml.bootstrap-user']
      @ml_password = @properties['ml.bootstrap-password']
    else
      @ml_password = @properties['ml.password']
    end

    if ! verify
      restart_group(group, legacy)
    else
      host_names = get_host_names()

      old_timestamps = restart_group(group, legacy)

      # Iterate until all hosts have restarted (or max is reached)
      old_timestamps.each do |host|
        host_name = host_names[host['host-id']]
        old_timestamp = host['value']

        print "Verifying restart for #{host_name}"

        # Initialize vars for repeated check
        retry_count = 0
        retry_max = @properties["ml.verify_retry_max"].to_i
        retry_interval = [@properties["ml.verify_retry_interval"].to_i, 10].max # 10 sec sleep at least
        new_timestamp = old_timestamp

        while retry_count < retry_max do
          begin
            new_timestamp = go(%Q{http://#{host_name}:8001/admin/v1/timestamp}, "get").body
          rescue
            logger.debug 'Retry attempt ' + retry_count.to_s + ' failed'
          end

          if new_timestamp != old_timestamp
            # Indicates that restart is confirmed successful
            break
          end

          # Retry..
          print ".."
          sleep retry_interval
          retry_count += 1
        end

        if retry_max < 1
          puts ": SKIPPED"
        elsif new_timestamp == old_timestamp
          puts ": FAILED"
        else
          puts ": OK"
        end
      end

    end
  end

  def merge
    what = ARGV.shift
    raise HelpException.new("merge", "Missing WHAT") unless what

    case what
      when 'content'
        merge_db(@properties['ml.content-db'])
      else
        raise HelpException.new("merge", "Invalid WHAT")
    end
    return true
  end

  def merge_db(target_db)
    logger.info "Merging #{target_db} on #{@hostname}"

    r = execute_query %Q{
      xdmp:merge(
      <options xmlns="xdmp:merge">
        <merge-timestamp>{xdmp:request-timestamp()}</merge-timestamp>
      </options>)
    },
    { :db_name => target_db }
    logger.debug "code: #{r.code.to_i}"

    r.body = parse_body(r.body)
    logger.info r.body
  end

  def reindex
    what = ARGV.shift
    raise HelpException.new("reindex", "Missing WHAT") unless what

    case what
      when 'content'
        reindex_db(@properties['ml.content-db'])
      else
        raise HelpException.new("reindex", "Invalid WHAT")
    end
    return true
  end

  def reindex_db(target_db)
    logger.info "Reindexing #{target_db} on #{@hostname}"

    r = execute_query %Q{
      xquery version "1.0-ml";

      import module namespace admin = "http://marklogic.com/xdmp/admin"
        at "/MarkLogic/admin.xqy";

      admin:save-configuration-without-restart(
        admin:database-set-reindexer-timestamp(
          admin:get-configuration(),
          xdmp:database("#{target_db}"),
          xdmp:request-timestamp()
        )
      )
    },
    { :db_name => target_db }
    logger.debug "code: #{r.code.to_i}"

    r.body = parse_body(r.body)
    logger.info r.body
  end

  def properties_map
    entries = []
    @properties.each do |k, v|
      entries.push %Q{map:entry("#{k}", "#{v.xquery_safe}")}
    end
    "map:new((\n" + entries.join(",\n  ")+ "))"
  end

  def config
    setup = File.read ServerConfig.expand_path("#{@@path}/lib/xquery/setup.xqy")
    r = execute_query %Q{
      #{setup}
      try {
        setup:rewrite-config(#{get_config}, #{properties_map})
      } catch($ex) {
        xdmp:log($ex),
        fn:concat($ex/err:format-string/text(), '&#10;See MarkLogic Server error log for more details.')
      }
    }
    logger.debug "code: #{r.code.to_i}"

    r.body = parse_body(r.body)
    logger.info r.body
    return true
  end

  def bootstrap
    raise ExitException.new("Bootstrap requires the target environment's hostname to be defined") unless @hostname.present?

    @ml_username = @properties['ml.bootstrap-user'] || @properties['ml.user']
    if @ml_username == @properties['ml.bootstrap-user']
      @ml_password = @properties['ml.bootstrap-password']
    else
      @ml_password = @properties['ml.password']
    end

    internals = find_arg(['--replicate-internals'])
    if internals
      dointernals = 'internals'

      # Number of hosts
      r = execute_query %Q{ fn:count(xdmp:hosts()) }
      r.body = parse_body(r.body)

      # check cluster size
      nr = find_arg(['--nr-replicas'])
      if nr
        if nr.downcase == "max"
          nr = r.body.to_i - 1
        else
          nr = nr.to_i
        end
      else
        nr = 1
      end

      raise ExitException.new("Increase nr-replicas, minimum is 1") if nr < 1
      raise ExitException.new("Adding #{nr} replicas to internals requires at least a #{nr + 1} node cluster") if r.body.to_i <= nr

      logger.info "Bootstrapping replicas for #{@properties['ml.system-dbs']} on #{@hostname}..."

      # build custom ml-config
      assigns = ''
      internals = @properties['ml.system-dbs'].split ','
      internals.each do |db|
        repnames = %Q{
            <replica-name>#{db}-rep1</replica-name>}
        repassigns = %Q{
            <assignment>
              <forest-name nr-replicas="#{nr}">#{db}-rep1</forest-name>
            </assignment>}

        assigns = assigns + %Q{

            <!-- #{db} -->
            <assignment>
              <forest-name>#{db}</forest-name>
              <replica-names>#{repnames}
              </replica-names>
            </assignment>#{repassigns}}
      end
      databases = ''
      internals.each do |db|
        databases = databases + %Q{

            <!-- #{db} -->
            <database>
              <database-name>#{db}</database-name>
              <forests>
                <forest-id name="#{db}"/>
              </forests>
            </database>}
      end
      config = %Q{
        <configuration default-group="#{@properties['ml.group']}">
          <assignments xmlns="http://marklogic.com/xdmp/assignments">#{assigns}
          </assignments>
          <databases xmlns="http://marklogic.com/xdmp/database">#{databases}
          </databases>
        </configuration>
      }
      logger.debug config
    else
      dointernals = ''
      logger.info "Bootstrapping your project into MarkLogic #{@properties['ml.server-version']} on #{@hostname}..."
      config = get_config
    end

    apply_changes = find_arg(['--apply-changes'])

    if apply_changes == nil or apply_changes == ""
      apply_changes = "all"
    end

    setup = File.read(ServerConfig.expand_path("#{@@path}/lib/xquery/setup.xqy"))
    r = execute_query %Q{#{setup} setup:do-setup(#{config}, "#{apply_changes},#{dointernals}", #{properties_map})}
    logger.debug "code: #{r.code.to_i}"

    r.body = parse_body(r.body)
    logger.debug r.body

    if r.body.match("error log")
      logger.error r.body
      raise ExitException.new("... Bootstrap FAILED")
      return false
    else
      if r.body.match("(note: restart required)")
        logger.warn "************************************"
        logger.warn "*** RESTART OF MARKLOGIC IS REQUIRED"
        logger.warn "************************************"
      end
      logger.info "... Bootstrap Complete"
      return true
    end
  end

  def clean_replicas_state
    internals = find_arg(['--internal-replicas'])

    if internals == nil
      internals = ''
      logger.info "Cleaning application forest decommissioned replica state"
    else
      logger.info "Cleaning interal forest decommissioned replica state"
      internals = 'internals'
    end

    setup = File.read(ServerConfig.expand_path("#{@@path}/lib/xquery/setup.xqy"))
    r = execute_query %Q{#{setup} setup:do-clean-replicas-state("#{internals}")}

    if r.body.match("error log")
      logger.error r.body
      logger.error "... Cleaning replicas FAILED"
      return false
    end

    logger.info r.body
    logger.info "... Cleaning replicas Complete"
    return true
  end

  def clean_replicas
    internals = find_arg(['--internal-replicas'])

    if internals == nil
      internals = ''
      logger.info "Cleaning application forest decommissioned replicas, if ready."
      config = get_config
    else
      logger.info "Cleaning interal forest decommissioned replicas, if ready."
      internals = 'internals'
      config = get_config
    end

    setup = File.read(ServerConfig.expand_path("#{@@path}/lib/xquery/setup.xqy"))
    r = execute_query %Q{#{setup} setup:do-clean-replicas(#{config}, "#{internals}", #{properties_map})}
    logger.debug "code: #{r.code.to_i}"

    r.body = parse_body(r.body)
    logger.debug r.body

    if r.body.match("error log")
      logger.error r.body
      logger.error "... Cleaning replicas FAILED"
      return false
    end
    if r.body.match("Replicas not ready")
      logger.error r.body
      return false
    end
    if r.body.match("nothing to do")
      logger.error r.body
      logger.info "No replicas were found to be retired.  Nothing to do."
      return false
    end

    logger.info r.body
    logger.info "... Cleaning replicas Complete"
    return true
  end

  def wipe

    @ml_username = @properties['ml.bootstrap-user'] || @properties['ml.user']
    if @ml_username == @properties['ml.bootstrap-user']
      @ml_password = @properties['ml.bootstrap-password']
    else
      @ml_password = @properties['ml.password']
    end

    wipe_environments = (@properties['ml.wipe-environments'] || 'local').split(',')
    if ! wipe_environments.index(@environment)
      expected_response = %Q{I WANT TO WIPE #{@environment.upcase}}
      print %Q{
*******************************************************************************
WARNING!!! You are attempting to wipe your #{@environment.upcase} environment!

This will remove everything that Roxy has bootstrapped. It's quite dangerous.
*******************************************************************************

Are you sure you want to do this?

In order to proceed please type: #{expected_response}
:> }
      if @@no_prompt
        raise ExitException.new("--no-prompt parameter prevents prompting for input")
      else
        response = STDIN.gets.chomp unless @@no_prompt
        if response != expected_response
          logger.info "\nAborting wipe on #{@environment}"
          return
        end
      end
    end

    appbuilder = find_arg(['--app-builder'])
    internals = find_arg(['--internal-replicas'])
    setup = File.read(ServerConfig.expand_path("#{@@path}/lib/xquery/setup.xqy"))

    if (appbuilder != nil)
      logger.info "Wiping MarkLogic App-Builder deployment #{appbuilder} from #{@hostname}..."
      config = %Q{
        <configuration>
          <http-servers xmlns="http://marklogic.com/xdmp/group">
            <http-server>
              <http-server-name>#{appbuilder}</http-server-name>
            </http-server>
          </http-servers>
          <assignments xmlns="http://marklogic.com/xdmp/assignments">
            <assignment>
              <forest-name>#{appbuilder}-modules-1</forest-name>
            </assignment>
          </assignments>
          <databases xmlns="http://marklogic.com/xdmp/database">
            <database>
              <database-name>#{appbuilder}-modules</database-name>
              <forests>
                <forest-id name="#{appbuilder}-modules-1"/>
              </forests>
            </database>
          </databases>
        </configuration>
      }
    elsif (internals == nil)
      databases = find_arg(['--databases']) || '##none##'
      forests = find_arg(['--forests']) || '##none##'
      servers = find_arg(['--servers']) || '##none##'

      logger.debug %Q{(#{databases}), (#{forests}), (#{servers})}

      if databases != '##none##' || forests != '##none##' || servers != '##none##'

        if (databases.split(',') & ['App-Services', 'Documents', 'Extensions', 'Fab', 'Last-Login', 'Meters', 'Modules', 'Schemas', 'Security', 'Triggers']).length > 0
          logger.warn "\nWARN: Cannot wipe built-in databases..\n"
          return
        end
        if (forests.split(',') & ['App-Services', 'Documents', 'Extensions', 'Fab', 'Last-Login', 'Meters', 'Modules', 'Schemas', 'Security', 'Triggers']).length > 0
          logger.warn "\nWARN: Cannot wipe built-in forests..\n"
          return
        end
        if (servers.split(',') & ['Admin', 'App-Services', 'HealthCheck', 'Manage']).length > 0
          logger.warn "\nWARN: Cannot wipe built-in servers..\n"
          return
        end

        databases = quote_arglist(databases)
        forests = quote_arglist(forests)
        servers = quote_arglist(servers)

        logger.info "Getting wipe configuration from #{@hostname}..."
        logger.debug %Q{calling setup:get-configuration((#{databases}), (#{forests}), (#{servers}), (9999999), (9999999), ("##none##"))..}
        r = execute_query %Q{#{setup} setup:get-configuration((#{databases}), (#{forests}), (#{servers}), (9999999), (9999999), ("##none##"))}

        config = parse_body(r.body)
        logger.info "Wiping MarkLogic #{databases}, #{forests}, #{servers} from #{@hostname}..."
      else
        logger.info "Wiping MarkLogic setup for your project from #{@hostname}..."
        config = get_config
      end
    end

    if (internals != nil)
      logger.info "Wiping replicas for #{@properties['ml.system-dbs']} from #{@hostname}.."
      r = execute_query %Q{
        xquery version "1.0-ml";

        import module namespace admin = "http://marklogic.com/xdmp/admin"
          at "/MarkLogic/admin.xqy";

        let $admin-config := admin:get-configuration()
        let $replicas :=
          for $forest-name in (#{quote_arglist(@properties['ml.system-dbs'])})
          let $forest-id := admin:forest-get-id($admin-config, $forest-name)
          for $replica in admin:forest-get-replicas($admin-config, $forest-id)
          return (
            xdmp:set(
              $admin-config,
              admin:forest-remove-replica($admin-config, $forest-id, $replica)
            ),
            $replica
          )
        let $_ :=
          for $replica in $replicas
          return xdmp:set(
            $admin-config,
            admin:forest-delete($admin-config, $replica, fn:true())
          )
        return
          if (admin:save-configuration-without-restart($admin-config)) then
            "(note: restart required)"
          else ()

      }
    else
      #logger.debug %Q{#{setup} setup:do-wipe(#{config}, #{properties_map})}

      wipe_changes = find_arg(['--apply-changes'])

      if wipe_changes == nil or wipe_changes == ""
        wipe_changes = "all"
      end

      r = execute_query %Q{#{setup} setup:do-wipe(#{config}, "#{wipe_changes}", #{properties_map})}
    end
    logger.debug "code: #{r.code.to_i}"

    r.body = parse_body(r.body)
    logger.debug r.body

    if r.body.match("RESTART_NOW")
      logger.warn "***************************************"
      logger.warn "*** WIPE NOT COMPLETE, RESTART REQUIRED"
      logger.warn "***************************************"
      logger.info "... NOTE: RERUN WIPE AFTER RESTART TO COMPLETE!"
      return false
    elsif r.body.match("<error:error") || r.body.match("error log")
      logger.error r.body
      logger.error "... Wipe FAILED"
      return false
    else
      if r.body.match("(note: restart required)")
        logger.warn "************************************"
        logger.warn "*** RESTART OF MARKLOGIC IS REQUIRED"
        logger.warn "************************************"
      end
      logger.info "... Wipe Complete"
      return true
    end
  end

  def validate_install
    logger.info "Validating your project installation into MarkLogic on #{@hostname}..."
    setup = File.read(ServerConfig.expand_path("#{@@path}/lib/xquery/setup.xqy"))
    begin
      r = execute_query %Q{#{setup} setup:validate-install(#{get_config}, #{properties_map})}
      logger.debug "code: #{r.code.to_i}"

      r.body = parse_body(r.body)
      logger.debug r.body

      if r.body.match("<error:error") || r.body.match("error log")
        logger.error r.body
        logger.info "... Validation ERROR"
        result = false
      else
        logger.info "... Validation SUCCESS"
        result = true
      end
    rescue Net::HTTPFatalError => e
      e.response.body = parse_body(e.response.body)
      logger.error e.response.body
      logger.error "... Validation FAILED"
      result = false
    end
    result
  end

  alias_method :validate, :validate_install

  def deploy
    @ml_username = @properties['ml.deploy-user'] || @properties['ml.user']
    if @ml_username == @properties['ml.deploy-user']
      @ml_password = @properties['ml.deploy-password']
    else
      @ml_password = @properties['ml.password']
    end

    what = ARGV.shift
    raise HelpException.new("deploy", "Missing WHAT") unless what

    case what
      when 'content'
        deploy_content
      when 'modules'
        deploy_modules
      when 'src'
        deploy_src
      when 'rest'
        deploy_rest
      when 'ext'
        deploy_ext
      when 'transform'
        deploy_transform
      when 'schemas'
        deploy_schemas
      when 'cpf'
        deploy_cpf
      when 'triggers'
        deploy_triggers
      when 'rest-config'
        deploy_rest_config
      else
        raise HelpException.new("deploy", "Invalid WHAT")
    end
    return true
  end

  def load
    dir = ARGV.shift
    db = find_arg(['--db']) || @properties['ml.content-db']
    remove_prefix = find_arg(['--remove-prefix'])
    remove_prefix = File.expand_path(remove_prefix) if remove_prefix
    quiet = find_arg(['--quiet'])

    add_prefix = find_arg(['--add-prefix'])

    raise HelpException.new("load", "File or Directory is required!") unless dir
    count = load_data dir, :remove_prefix => remove_prefix, :add_prefix => add_prefix, :db => db, :quiet => quiet
    logger.info "\nLoaded #{count} #{pluralize(count, "document", "documents")} from #{dir} to #{xcc.hostname}:#{xcc.port}/#{db} at #{DateTime.now.strftime('%m/%d/%Y %I:%M:%S %P')}\n"
    return true
  end

  def load_data(dir, options = {})
    batch_override = find_arg(['--batch'])
    batch = @environment != "local" && batch_override.blank? || batch_override.to_b

    incremental = find_arg(['--incremental']).to_b

    options[:batch_commit] = batch
    options[:permissions] = permissions(@properties['ml.app-role'], Roxy::ContentCapability::ERU) unless options[:permissions]

    path = File.expand_path(dir)

    if (!File.exists?(path))
      logger.error "#{path} does not exist"
      return 0
    end

    files = get_files(path, options)

    if incremental
      files = filter_to_newer_files(files, options)
    end

    xcc.load_files(files, options)
  end

  #
  # Cleans something
  #  .. content = cleans the content db
  #  .. modules = cleans the modules db
  #  .. triggers = cleans the triggers db
  #  .. schemas = cleans the schemas db
  #  .. cpf = cleans the cpf configuration
  #
  def clean
    what = ARGV.shift
    raise HelpException.new("clean", "Missing WHAT") unless what

    case what
      when 'content'
        clean_content
      when 'modules'
        clean_modules
      when 'schemas'
        clean_schemas
      when 'cpf'
        clean_cpf
      when 'triggers'
        clean_triggers
      when 'replicas'
        clean_replicas
      when 'replicas-state'
        clean_replicas_state
      else
        raise HelpException.new("clean", "Invalid WHAT")
    end
    return true
  end

  #
  # An alernative command for clean
  #
  def clear
    clean
  end

  #
  # Install - Runs all steps needed to 'install' a Roxy application
  #
  def install
    bootstrap
    deploy_modules
    if File.exist?(@properties["ml.schemas.dir"])
      deploy_schemas
    end
    if @properties["ml.triggers-db"]
      deploy_triggers
    end
    if @properties["ml.triggers-db"] and @properties["ml.data.dir"] and File.exist?(ServerConfig.expand_path(@properties["ml.pipeline-config-file"]))
      deploy_cpf
    end
    deploy_content
  end

  #
  # Uninstall - an alternative command for wipe to complement install
  #
  def uninstall
    wipe
  end

  #
  # Invokes unit tests for the project
  #
  def test
    if @environment == "prod"
      logger.error "There is no Test database on the Production server"
    elsif ! @properties["ml.test-port"] || ! @properties["ml.test-content-db"]
      logger.error "Testing is not properly configured"
    else
      if find_arg(['--skip-suite-teardown']).present?
        suiteTearDown = "&runsuiteteardown=false"
      else
        suiteTearDown = "&runsuiteteardown=true"
      end
      if find_arg(['--skip-test-teardown']).present?
        testTearDown = "&runteardown=false"
      else
        testTearDown = "&runteardown=true"
      end
      r = go(%Q{http://#{@hostname}:#{@properties["ml.test-port"]}/test/default.xqy?func=list}, "get")
      suites = []
      r.body.split(">").each do |line|
        suites << line.gsub(/.*suite path="([^"]+)".*/, '\1').strip if line.match("suite path")
      end

      success = true
      suites.each do |suite|
        begin
          r = go(%Q{http://#{@hostname}:#{@properties["ml.test-port"]}/test/default.xqy?func=run&suite=#{url_encode(suite)}&format=junit#{suiteTearDown}#{testTearDown}}, "get")
          logger.info r.body
        rescue Net::HTTPServerException => e
          if e.response.code.to_i == 409
            # ignore 409's, but mark failure
            success = false
          else
            raise # reraise last exception
          end
        end
      end
    end
    if !success
      logger.error "Some tests failed!"
    end
    return success
  end

  def test_cleanup
    src_dir = ServerConfig.expand_path(@properties["ml.xquery.dir"])
    File.delete("#{src_dir}/app/controllers/missing-map.xqy")
    File.delete("#{src_dir}/app/controllers/tester.xqy")
    FileUtils.rm_r("#{src_dir}/app/views/tester", :force => true)
    File.delete("#{src_dir}/app/views/layouts/different-layout.html.xqy")
  end

  def backup_database(id, dir)
    r = execute_query %Q{xdmp:database-backup(xdmp:database-forests(#{id}), "#{dir}")}
    r.body
  end

  def is_backup_complete(job)
    r = execute_query %Q{xdmp:database-backup-status(#{job})}
    statuses = []
    r.body.split("\n").each do |line|
      statuses << line.gsub(/.*<job:status>([^<]+)<\/job:status>/, '\1').strip if line.match("job:status")
    end

    completed_count = 0
    failed_count = 0
    statuses.each do |status|
      if status == "completed"
        completed_count = completed_count + 1
      elsif status == "failed"
        failed_count = failed_count + 1
      end
    end

    completed = (completed_count + failed_count) == statuses.size

    return completed, failed_count
  end

  def recordloader
    filename = ARGV.shift
    raise HelpException.new("recordloader", "configfile is required!") unless filename
    properties_file = ServerConfig.expand_path("#{@@path}/#{filename}")
    properties = ServerConfig.load_properties(properties_file, "")
    properties = ServerConfig.substitute_properties(properties, @properties, "")

    properties.each do |k, v|
      logger.debug "#{k}=#{v}"
    end

    prop_string = ""
    properties.each do |k,v|
      prop_string << %Q{-D#{k}="#{v}" }
    end

    # Find the jars
    recordloader_file = find_jar("recordloader")
    xcc_file = find_jar("xcc")
    xpp_file = find_jar("xpp")

    runme = %Q{java -cp #{recordloader_file}#{path_separator}#{xcc_file}#{path_separator}#{xpp_file} #{prop_string} com.marklogic.ps.RecordLoader}
    logger.info runme
    r = system(runme)
    logger.debug $?

    if r == nil
      logger.error "Call to RecordLoader failed"
      r = false
    elsif !r
      logger.error "RecordLoader non-zero exit"
    else
      logger.info ""
    end

    return r
  end

  def xqsync
    filename = ARGV.shift
    raise HelpException.new("xqsync", "configfile is required!") unless filename
    properties_file = ServerConfig.expand_path("#{@@path}/#{filename}")
    properties = ServerConfig.load_properties(properties_file, "")
    properties = ServerConfig.substitute_properties(properties, @properties, "")

    properties.each do |k, v|
      logger.debug "#{k}=#{v}"
    end
    prop_string = ""
    properties.each do |k,v|
      prop_string << %Q{-D#{k}="#{v}" }
    end

    # Find the jars
    xqsync_file = find_jar("xqsync")
    xcc_file = find_jar("xcc")
    xstream_file = find_jar("xstream")
    xpp_file = find_jar("xpp")

    runme = %Q{java -Xmx2048m -cp #{xqsync_file}#{path_separator}#{xcc_file}#{path_separator}#{xstream_file}#{path_separator}#{xpp_file} -Dfile.encoding=UTF-8 #{prop_string} com.marklogic.ps.xqsync.XQSync}
    logger.info runme

    # Note: XQSync doesn't seem to exit with non-zero code at failure (yet), putting this in place nonetheless
    r = system(runme)
    logger.debug $?

    if r == nil
      logger.error "Call to XQSync failed"
      r = false
    elsif !r
      logger.error "XQSync non-zero exit"
    else
      logger.info ""
    end

    return r
  end

  def corb
    @ml_username = @properties['ml.corb-user'] || @properties['ml.user']
    if @ml_username == @properties['ml.corb-user']
      @ml_password = @properties['ml.corb-password']
    else
      @ml_password = @properties['ml.password']
    end

    password_prompt
    encoded_password = url_encode(@ml_password)
    connection_string = %Q{xcc://#{@ml_username}:#{encoded_password}@#{@properties['ml.server']}:#{@properties['ml.xcc-port']}/#{@properties['ml.content-db']}}

    options = Hash.new("")
    # handle Roxy convention for CoRB properties first
    process_module = find_arg(['--modules']) || ''
    process_module = process_module.reverse.chomp("/").reverse
    if !process_module.blank?
        options["PROCESS-MODULE"] = process_module
    end

    collection_name = find_arg(['--collection']) || ''
    if !collection_name.blank?
        options["COLLECTION-NAME"] = collection_name
        # when COLLECTION-NAME is specified, assume CoRB 1.0 convention,
        # and set URIS-MODULE with an inline module to return the URIs of all docs in the specified collection(s)
        options["URIS-MODULE"] = "INLINE-XQUERY|xquery version '1.0-ml'; declare variable \\$URIS as xs:string external; let \\$uris := cts:uris('', ('document'), cts:collection-query(\\$URIS)) return (count(\\$uris), \\$uris)"
    end

    uris_module = find_arg(['--uris']) || ''
    uris_module = uris_module.reverse.chomp('/').reverse
    if !uris_module.blank?
        options["URIS-MODULE"] = uris_module
    end

    thread_count = find_arg(['--threads'])
    thread_count = thread_count.to_i
    if thread_count > 0
        options["THREAD-COUNT"] = thread_count
    end

    module_root = find_arg(['--root']) || ''
    if !module_root.blank?
        options["MODULE-ROOT"] = module_root
    end

    modules_database = @properties['ml.modules-db'] || ''
    if !modules_database.blank?
        options["MODULES-DATABASE"] = modules_database
    end

    # collect options with either "--" or "-D" prefix, and normalize options to be UPPER-CASE
    optionArgPattern = /^(--|-D)([^.]*?)(\..*?)?="?(.*)"?/
    ARGV.each do |arg|
      if arg.match(optionArgPattern)
        matches = arg.match(optionArgPattern).to_a
        options[matches[2].to_s.upcase + matches[3].to_s] = matches[4]
      end
    end

    # collect options and set as Java system properties switches
    systemProperties = options.delete_if{ |key, value| value.blank? }
                        .map{ |key, value| "-D#{key}=\"#{value}\""}
                        .join(' ')

    # Find the jars
    corb_file = find_jar('corb')
    xcc_file = find_jar('xcc')

    runme = %Q{java -cp #{corb_file}#{path_separator}#{xcc_file} #{systemProperties} com.marklogic.developer.corb.Manager #{connection_string}}
    logger.debug runme

    if options.fetch("INSTALL", false)
      # If we're installing, we need to change directories to the source
      # directory, so that the xquery_modules will be visible with the
      # same path that will be used to see it in the modules database.
      Dir.chdir(@properties['ml.xquery.dir']) do
        r = system(runme)
      end
    else
      r = system(runme)
    end
    logger.debug $?

    if r == nil
      logger.error "Call to Corb failed"
      r = false
    elsif !r
      logger.error "Corb non-zero exit"
    else
      logger.info ""
    end

    ARGV.clear
    return r
  end

  def mlcp
    mlcp_home = @properties['ml.mlcp-home']
    if @properties['ml.mlcp-home'] == nil || ! File.directory?(File.expand_path(mlcp_home)) || ! File.exists?(File.expand_path("#{mlcp_home}/bin/mlcp.sh"))
      raise "MLCP not found or mis-configured, please check the mlcp-home setting."
    end

    # Find all jars required for running MLCP. At least:
    jars = Dir.glob(ServerConfig.expand_path("#{mlcp_home}/lib/*.jar"))
    confdir = ServerConfig.expand_path("#{mlcp_home}/conf")
    classpath = "#{confdir}#{path_separator}#{jars.join(path_separator)}"

    vmargs = %Q{"-DCONTENTPUMP_HOME=#{mlcp_home}" -Dfile.encoding=UTF-8 -Dxcc.txn.compatible=true "-Djava.library.path=#{mlcp_home}/lib/native" #{@properties['ml.mlcp-vmargs']} }

    ARGV.each do |arg|
      if arg == "-options_file"
        # remove flag from ARGV
        index = ARGV.index(arg)
        ARGV.slice!(index)

        # capture and remove value from ARGV
        options_file = ARGV[index]
        ARGV.slice!(index)

        # find and read file if exists
        options_file = File.expand_path("#{options_file}")
        if File.exist? options_file
          logger.debug "Reading options file #{options_file}.."
          options = File.read options_file

          # substitute properties
          replace_properties(options, File.basename(options_file))

          logger.debug "Options after resolving properties:"
          lines = options.split(/[\n\r]+/).reject { |line| line.empty? || line.match("^#") }

          lines.each do |line|
            logger.debug line
          end

          # and write updated options to a tmpfile, to pass them through to MLCP
          tmpdir = Dir.mktmpdir
          tmpfile = "#{tmpdir}#{File.basename(options_file)}"
          logger.debug tmpfile
          File.write(tmpfile, options)
          ARGV[index,0] = ['-options_file', tmpfile]
        else
          raise "Options file #{options_file} not found."
        end
      end
    end

    @ml_username = @properties['ml.mlcp-user'] || @properties['ml.user']
    if @ml_username == @properties['ml.mlcp-user']
      @ml_password = @properties['ml.mlcp-password']
    else
      @ml_password = @properties['ml.password']
    end

    if ARGV.length > 0
      password_prompt
      connection_string = %Q{ -username #{@ml_username} -password #{@ml_password} -host #{@properties['ml.server']} -port #{@properties['ml.xcc-port']}}

      args = ARGV.join(" ")

      runme = %Q{java -cp "#{classpath}" #{vmargs} com.marklogic.contentpump.ContentPump #{args} #{connection_string}}
    else
      runme = %Q{java -cp "#{classpath}" #{vmargs} com.marklogic.contentpump.ContentPump}
    end

    logger.debug runme
    logger.info ""

    # PATH change only important for Windows, so always using ; and \
    env_variables = {
      "PATH" => "#{ENV['PATH']};#{mlcp_home}\\bin",
      "HADOOP_HOME" => mlcp_home
    }
    r = system(env_variables, runme)
    logger.debug $?

    if r == nil
      logger.error "Call to MLCP failed"
      r = false
    elsif !r
      logger.error "MLCP non-zero exit"
    else
      logger.info ""
    end

    ARGV.clear
    return r
  end

  def credentials
    if @@no_prompt
      raise ExitException.new("--no-prompt parameter prevents prompting for input")
    else
      logger.info "credentials #{@environment}"
      # ml will error on invalid environment
      # ask user for admin username and password
      puts "What is the admin username?"
      user = STDIN.gets.chomp
      puts "What is the admin password?"
      # we don't want to install highline
      # we can't rely on STDIN.noecho with older ruby versions
      system "stty -echo"
      password = STDIN.gets.chomp
      system "stty echo"

      # Create or update environment properties file
      filename = "#{@environment}.properties"
      properties = {}
      properties_file = ServerConfig.expand_path("#{@@path}/#{filename}")
      begin
        if (File.exists?(properties_file))
          properties = ServerConfig.load_properties(properties_file, "")
        else
          logger.info "#{properties_file} does not yet exist"
        end
      rescue => err
        puts "Exception: #{err}"
      end
      properties["user"] = user
      properties["password"] = password
      File.open(properties_file, 'w') do |f|
        properties.each do |k,v|
          f.write "#{k}=#{v}\n"
        end
      end
      logger.info "wrote #{properties_file}"
      return true
    end
  end

  def capture
    full_config = find_arg(['--full-ml-config'])
    config = find_arg(['--ml-config'])
    target_db = find_arg(['--modules-db'])
    appbuilder = find_arg(['--app-builder'])

    if (appbuilder != nil)
      serverstats = execute_query %Q{
        xquery version "1.0-ml";

        let $status := xdmp:server-status(xdmp:host(), xdmp:server("#{appbuilder}"))
        return (
          string($status//*:port),
          $status//*:modules/xdmp:database-name(.)
        )
      }

      logger.debug parse_body(serverstats.body)

      serverstats.body = parse_body(serverstats.body).split(/[\r\n]+/)

      port = serverstats.body[0]
      target_db = serverstats.body[1]
    end

    # check params
    if full_config == nil && config == nil && target_db == nil
      raise HelpException.new("capture", "either full-ml-config, ml-config, app-builder or modules-db is required")
    end

    # retrieve full setup config from environment
    if full_config != nil || config != nil
      capture_environment_config(full_config)
    end

    # retrieve modules from selected database from environment
    if target_db != nil
      tmp_dir = Dir.mktmpdir
      logger.debug "using temp dir " + tmp_dir

      if (port != nil)
        logger.info "Retrieving source and REST config from #{target_db}..."
      else
        logger.info "Retrieving source from #{target_db}..."
      end

      # send the target db, and the destination directory
      save_files_to_fs(target_db, "#{tmp_dir}/src")

      # check if this is a REST project to capture REST configuration
      if (port != nil)

        # make sure that REST	options directory exists
        if Dir.exists? @properties['ml.rest-options.dir']

          # set up the options
          FileUtils.cp_r(
            "#{tmp_dir}/src/#{@properties['ml.group']}/" + target_db.sub("-modules", "") + "/rest-api/.",
            @properties['ml.rest-options.dir']
          )
          FileUtils.rm_rf("#{tmp_dir}/src/#{@properties['ml.group']}/")

          # Make sure REST properties are in accurate format, so you can directly deploy them again..
          r = go("http://#{@hostname}:#{port}/v1/config/properties", "get")
          r.body = parse_body(r.body)
          File.open("#{@properties['ml.rest-options.dir']}/properties.xml", 'wb') { |file| file.write(r.body) }

        else
          raise HelpException.new("capture", "attempting --app-builder REST capture into non-REST project, you may try capture with --modules-db to only capture modules without the REST configuration")
        end
      end

      # If we have an application/custom directory, we've probably done a capture
      # before. Don't overwrite that directory. Kill the downloaded custom directory
      # to avoid overwriting.
      if Dir.exists? "#{@properties["ml.xquery.dir"]}/application/custom"
        FileUtils.rm_rf("#{tmp_dir}/src/application/custom")
      end

      FileUtils.cp_r("#{tmp_dir}/src/.", @properties["ml.xquery.dir"])

      FileUtils.rm_rf(tmp_dir)
    end
    return true
  end

  def settings
    arg = ARGV.shift
    if arg
      setup = File.read ServerConfig.expand_path("#{@@path}/lib/xquery/setup.xqy")
      r = execute_query %Q{#{setup} setup:list-settings("#{arg}")}
      r.body = parse_body(r.body)
      logger.info r.body
    else
      logger.info %Q{
Usage: ml [env] settings [group|host|database|task-server|http-server|odbc-server|xdbc-server|webdav-server]

Provides listings of various kinds of settings supported within ml-config.xml.
      }
    end
    return true
  end

  def deploy_triggers
    @ml_username = @properties['ml.deploy-user'] || @properties['ml.user']
    if @ml_username == @properties['ml.deploy-user']
      @ml_password = @properties['ml.deploy-password']
    else
      @ml_password = @properties['ml.password']
    end

    logger.info "Deploying Triggers"
    if !@properties["ml.triggers-db"]
      raise ExitException.new("Deploy triggers requires a triggers database")
    end

    target_config = ServerConfig.expand_path(@properties["ml.triggers.file"])

    if !File.exist?(target_config)
      logger.error "ml.triggers.file=#{@properties['ml.triggers.file']}"
      logger.error <<-ERR.strip_heredoc
        Before you can deploy triggers, you must define a configuration. Steps:
        1. Copy deploy/sample/triggers-config.sample.xml to #{target_config}
          The location of this file is controlled by the triggers.file property.
        2. Edit #{target_config} to specify your trigger(s)
        3. Run 'ml <env> deploy triggers')
      ERR
      return false
    else
      triggers_config = File.read target_config
      replace_properties(triggers_config, target_config)
      triggers_code = File.read ServerConfig.expand_path("#{@@path}/lib/xquery/triggers.xqy")
      query = %Q{#{triggers_code} triggers:load-from-config(#{triggers_config})}
      logger.debug(query)
      r = execute_query(query, :db_name => @properties["ml.triggers-db"])
      logger.info "... triggers deployed"
      return true
    end
  end

  def clean_triggers
    if @properties['ml.triggers-db']
      triggers_code = File.read ServerConfig.expand_path("#{@@path}/lib/xquery/triggers.xqy")
      r = execute_query %Q{#{triggers_code} triggers:clean-triggers()}, :db_name => @properties["ml.triggers-db"]
      return true
    else
      logger.error "No triggers db is configured"
    end
  end

private

  def filter_to_newer_files(files, options)
    logger.info "Filtering to files which are newer locally than on the server"

    if @server_version < 6
      raise ExitException.new("Can only filter files on MarkLogic 6 and later")
    end

    uris = files.map { |f| xcc.build_target_uri(f, options) }
    stamps_db = get_db_timestamps(uris, options[:db])
    stamps_local = files.map { |file_uri| File.mtime(file_uri).getgm.iso8601(5) }

    files_with_stamps = files.zip(stamps_local, stamps_db)

    filtered = files_with_stamps.select do |file_uri, stamp_locally, stamp_in_db|

      stamp_in_db = stamp_in_db || ""

      newer = (stamp_locally > stamp_in_db || stamp_in_db.strip.empty?)

      if (!newer)
        logger.debug "Ignoring #{file_uri} as server version is newer"
      end

      newer
    end

    filtered.map { |f, stamp1, stamp2| f}
  end

  def get_db_timestamps(uris, target_db)
    uris_as_string = uris.map{|i| "\"#{i}\""}.join(",")
    q = %Q{for $u in (#{uris_as_string}) return "" || adjust-dateTime-to-timezone(xdmp:timestamp-to-wallclock(xdmp:document-timestamp($u)), xs:dayTimeDuration("PT0H"))}

    result = execute_query q, :db_name => target_db
    parse_body(result.body).split("\n")
  end

  def save_files_to_fs(target_db, target_dir)
    # Get the list of URIs. We get them in order because Ruby's Dir.mkdir
    # command doesn't have a -p option (create parent).
    dirs = execute_query %Q{
      xquery version "1.0-ml";

      try {
        for $uri in cts:uris()
        order by $uri
        return $uri

      } catch ($ignore) {
        (: In case URI lexicon has not been enabled :)
        for $doc in collection()
        let $uri := xdmp:node-uri($doc)
        order by $uri
        return $uri
      }
    },
    { :db_name => target_db }

    if dirs.body.empty?
      raise ExitException.new("Found no URIs in the modules database -- no code to capture")
    end

    # target_dir gets created when we do mkdir on "/"
    if ['5', '6'].include? @properties['ml.server-version']
      # In ML5 and ML6, the response was a bunch of text. Split on the newlines.
      dirs.body.split(/\r?\n/).each do |uri|
        r = execute_query %Q{
          fn:doc("#{uri}")
        },
        { :db_name => target_db }

        path = "#{target_dir}#{uri}"
        parentdir = File.dirname path
        FileUtils.mkdir_p(parentdir) unless File.exists?(parentdir)
        if ! uri.end_with?("/")
          File.open("#{path}", 'wb') { |file| file.write(r.body) }
        end
      end
    elsif @properties['ml.server-version'] == '7'
      # In ML7, the response is JSON
      # [
      #  {"qid":null, "type":"string", "result":"\/"},
      #  {"qid":null, "type":"string", "result":"\/application\/"}
      #  ...
      db_id = get_db_id(target_db)

      JSON.parse(dirs.body).each do |item|
        uri = item['result']
        r = go("#{@protocol}://#{@hostname}:#{@bootstrap_port}/qconsole/endpoints/view.xqy?dbid=#{db_id}&uri=#{URI.escape(uri).gsub(/\$/, '%24')}", "get")

        path = "#{target_dir}#{uri}"
        parentdir = File.dirname path
        FileUtils.mkdir_p(parentdir) unless File.exists?(parentdir)
        if ! uri.end_with?("/")
          File.open("#{path}", 'wb') { |file| file.write(r.body) }
        end
      end
    else
      # ML8, we're using /v1/eval, so we get a multi-part response
      uris = parse_body(dirs.body)
      uris.split(/\r?\n/).each do |uri|
        if ! uri.end_with?("/")

          r = execute_query %Q{
            fn:doc("#{uri}")
          },
          { :db_name => target_db }

          delimiter = r.body.split("\r\n")[1].strip
          parts = r.body.split(delimiter)

          # The first part will always be an empty string. Just remove it.
          parts.shift
          # The last part will be the "--". Just remove it.
          parts.pop

          # Get rid of part headers
          parts = parts.map{ |part|
            sections = part.split("\r\n\r\n");
            sections.slice(1, sections.length).join("\r\n\r\n")
          }

          # Return all parts as one long string, like we were used to.
          parts = parts.join().chomp("\r\n")

          path = "#{target_dir}#{uri}"
          parentdir = File.dirname path
          FileUtils.mkdir_p(parentdir) unless File.exists?(parentdir)
          if ! uri.end_with?("/")
            File.open("#{path}", 'wb') { |file| file.write(parts) }
          end
        end
      end
    end
  end

  # Note: this is the beginning of a feature; not really useful yet. What we want is to specify one or more app servers,
  # get all configuration related to them, and write that into the ml-config.xml format. This format is very similar to
  # MarkLogic's databases.xml and other config files, but there are some differences.
  # The related configuration is to include any databases connected to the app server(s) -- modules, content, triggers,
  # schemas; CPF configuration; along with users and roles. For users and roles, we probably need an interactive system --
  # we don't want or need to capture built-in users and roles. If the application uses app-level security, then we
  # could start with "Capture user #{default user}?" and then check on each role that user has.
  def capture_environment_config(full_config)
    raise ExitException.new("Capture requires the target environment's hostname to be defined") unless @hostname.present?

    if (full_config == nil)
      databases = quote_arglist(find_arg(['--databases']) || "#{@properties["ml.content-db"]},#{@properties["ml.modules-db"]},#{@properties["ml.triggers-db"]},#{@properties["ml.schemas-db"]}")
      # TODO: take content-forests-per-host into account properly, just taking first by default
      forests = quote_arglist(find_arg(['--forests']) || "#{@properties["ml.content-db"]},#{@properties["ml.content-db"]}-001-1,#{@properties["ml.modules-db"]},#{@properties["ml.triggers-db"]},#{@properties["ml.schemas-db"]}")
      # TODO: include dav, xdbc, odbc servers?
      servers = quote_arglist(find_arg(['--servers']) || "#{@properties["ml.app-name"]},#{@properties["ml.app-name"]}-xdbc,#{@properties["ml.app-name"]}-odbc,#{@properties["ml.app-name"]}-test,#{@properties["ml.app-name"]}-webdav")
      mimes = quote_arglist(find_arg(['--mime-types']) || "##none##")
      users = quote_arglist(find_arg(['--users']) || "#{@properties["ml.app-name"]}-user,#{@properties["ml.default-user"]}")
      roles = quote_arglist(find_arg(['--roles']) || "#{@properties["ml.app-role"]}")
    end

    logger.info "Capturing configuration of MarkLogic on #{@hostname}..."
    logger.debug %Q{calling setup:get-configuration((#{databases}), (#{forests}), (#{servers}), (#{users}), (#{roles}), (#{mimes}))..}
    setup = File.read(ServerConfig.expand_path("#{@@path}/lib/xquery/setup.xqy"))
    r = execute_query %Q{#{setup} setup:get-configuration((#{databases}), (#{forests}), (#{servers}), (#{users}), (#{roles}), (#{mimes}))}
    r.body = parse_body(r.body)

    if r.body.match("error log")
      logger.error r.body
      logger.error "... Capture FAILED"
      return false
    else
      name = "#{@properties["ml.config.file"].sub( %r{.xml}, '' )}-#{@properties["ml.environment"]}.xml"
      File.open(name, 'wb') { |file| file.write(r.body) }
      logger.info("... Captured configuration into #{name}")
      return true
    end
  end

  def quote_arglist(arglist)
    if arglist != nil
      # TODO: remove duplicates
      # TODO: what happens when strings and numbers are combined as arguments?
      args = arglist.split(/[,]+/).reject { |arg| arg.empty? }
      if !/\A\d+\z/.match(args[0])
        arglist = args.join("\",\"")
        return "\"#{arglist}\""
      else
        arglist = args.join(",")
        return "#{arglist}"
      end
    end
  end

  # Build an array of role/capability objects.
  def permissions(role, capabilities)
    if capabilities.is_a?(Array)
      capabilities.map do |c|
        {
          :capability => c,
          :role => role
        }
      end
    else
      [
        {
          :capability => capabilities,
          :role => role
        }
      ]
    end
  end

  def deploy_tests?(target_db)
    @properties['ml.test-content-db'].present? &&
    @properties['ml.test-port'].present? &&
    !@properties['ml.do-not-deploy-tests'].split(",").include?(@environment) &&
    conditional_prop('ml.test-modules-db', 'ml.modules-db') == target_db
  end

  def modules_databases
    dbs = [@properties['ml.modules-db']]
    dbs << @properties['ml.test-modules-db'] if @properties['ml.test-modules-db'].present? &&
                                                @properties['ml.test-modules-db'] != @properties['ml.modules-db']
    dbs
  end

  def deploy_modules
    deploy_src()
    deploy_rest()
  end

  def deploy_src
    test_dir = @properties['ml.xquery-test.dir']
    xquery_dir = @properties['ml.xquery.dir']
    app_configs = @properties['ml.application-conf-file']
    test_config_file = File.join test_dir, "/test-config.xqy"
    load_html_as_xml = @properties['ml.load-html-as-xml']
    load_js_as_binary = @properties['ml.load-js-as-binary']
    load_css_as_binary = @properties['ml.load-css-as-binary']
    folders_to_ignore = @properties['ml.ignore-folders']

    if @properties['ml.save-commit-info'] == 'true'

      if File.exists? ".svn"
        svn_info_file = File.new("#{xquery_dir}/svn-info.xml", "w")
        svn_info_file.puts(`svn info --xml`)
        svn_info_file.close
        @logger.info "Saved commit info as #{xquery_dir}/svn-info.xml"

      elsif File.exists? ".git"
        git_info_file = File.new("#{xquery_dir}/git-info.xml", "w")
        git_info_file.puts(`git log -1 --pretty=format:"<entry><id>%H</id><author>%an</author><date>%ai</date><subject>%s</subject><body>%b</body></entry>"`)
        git_info_file.close
        @logger.info "Saved commit info as #{xquery_dir}/git-info.xml"

      else
        @logger.warn "Only SVN and GIT supported for save-commit-info"
      end

    end

    total_count = 0
    modules_databases.each do |dest_db|
      if dest_db == "filesystem"
        logger.info "Skipping deployment of src to #{dest_db}.."
        break
      end

      ignore_us = []
      ignore_us << "^#{test_dir}.*$" unless test_dir.blank? || deploy_tests?(dest_db)
      ignore_us << "^#{test_config_file}$"
      ignore_us << "^#{folders_to_ignore}$" unless folders_to_ignore.blank?

      src_permissions = permissions(@properties['ml.app-role'], Roxy::ContentCapability::ERU)

      if ['rest', 'hybrid'].include? @properties["ml.app-type"]
        # This app uses the REST API, so grant permissions to the rest roles. This allows REST extensions to call
        # modules not deployed through the REST API.
        # These roles are present in MarkLogic 6+.
        src_permissions.push permissions('rest-admin', Roxy::ContentCapability::RU)
        src_permissions.push permissions('rest-extension-user', Roxy::ContentCapability::EXECUTE)
        src_permissions.flatten!
      end

      @logger.debug "source permissions: #{src_permissions}"
      if app_configs.present?
        logger.debug "Deploying application configurations"

        app_configs.split(',').each do |item|
          buffer = File.read item
          replace_properties(buffer, File.basename(item))

          item_name = item
          prefix = '/'
          if item_name === 'src/app/config/config.xqy'
            item_name = '/config.xqy'
            ignore_us << '/app/config/config.xqy'
            prefix = 'app/config/'
          elsif item.start_with?("src/")
            item_name = '/' + item[4, item.length]
            ignore_us << item_name
          end

          logger.debug "deploying application configuration #{item} with name #{item_name} on #{dest_db}"
          total_count += xcc.load_buffer item_name,
                                         buffer,
                                         :db => dest_db,
                                         :add_prefix => File.join(@properties["ml.modules-root"], prefix),
                                         :permissions => src_permissions
        end
        logger.debug "Done deploying application configurations"
      end

      total_count = load_data xquery_dir,
                              :add_prefix => @properties["ml.modules-prefix"],
                              :remove_prefix => xquery_dir,
                              :db => dest_db,
                              :ignore_list => ignore_us,
                              :load_html_as_xml => load_html_as_xml,
                              :load_js_as_binary => load_js_as_binary,
                              :load_css_as_binary => load_css_as_binary,
                              :permissions => src_permissions


      if deploy_tests?(dest_db) && File.exist?(test_config_file)
        buffer = File.read test_config_file
        replace_properties(buffer, File.basename(test_config_file))

        total_count += xcc.load_buffer "/test-config.xqy",
                                       buffer,
                                       :db => dest_db,
                                       :add_prefix => File.join(@properties["ml.modules-root"], "test"),
                                       :permissions => src_permissions
      end

      # REST API applications need some files put into a collection.
      # Note that this is for extensions and transforms captured as-is from a modules database. The normal
      # deploy process takes care of this for files under rest-api/.
      if ['rest', 'hybrid'].include? @properties["ml.app-type"]
        r = execute_query %Q{
            xquery version "1.0-ml";

            for $uri in cts:uri-match("/marklogic.rest.*")
            return xdmp:document-set-collections($uri, "http://marklogic.com/extension/plugin")
          },
          { :db_name => dest_db }

      end

      logger.info "\nLoaded #{total_count} #{pluralize(total_count, "document", "documents")} from #{xquery_dir} to #{xcc.hostname}:#{xcc.port}/#{dest_db} at #{DateTime.now.strftime('%m/%d/%Y %I:%M:%S %P')}\n"
    end
  end

  def deploy_rest(test = false)
    # Deploy options, extensions to the REST API server
    if ['rest', 'hybrid'].include? @properties["ml.app-type"]
      # Verify that we're not trying to run REST from the filesystem
      rest_modules_db = ''
      if @properties.has_key?('ml.rest-port') and @properties['ml.rest-port'] != ''
        rest_modules_db = conditional_prop('ml.rest-modules-db', 'ml.modules-db')
      else
        rest_modules_db = @properties['ml.modules-db']
      end

      if ['filesystem', 'file-system', '0'].include? rest_modules_db
        logger.warn "\nWARN: Cannot deploy REST features to a REST-api running from file-system!\n"
        return
      end

      deploy_rest_config()
      deploy_ext()
      deploy_transform()

      if !test &&
         @properties['ml.test-content-db'].present? &&
         @properties['ml.test-port'].present? &&
         !@properties['ml.do-not-deploy-tests'].split(",").include?(@environment)

         # preserve original mlRest client
         org_mlRest = @mlRest

         # recreate client, with test settings
         @mlRest = Roxy::MLRest.new({
           :user_name => @ml_username,
           :password => @ml_password,
           :server => @hostname,
           :app_port => @properties["ml.app-port"],
           :rest_port => @properties["ml.test-port"],
           :logger => @logger,
           :server_version => @server_version,
           :http_connection_retry_count => @properties["ml.http.retry-count"].to_i,
           :http_connection_open_timeout => @properties["ml.http.open-timeout"].to_i,
           :http_connection_read_timeout => @properties["ml.http.read-timeout"].to_i,
           :http_connection_retry_delay => @properties["ml.http.retry-delay"].to_i,
           :use_https_for_rest => @properties["ml.ssl-certificate-template"].present? || @properties["ml.use-https-for-rest"] == "true"
         })

         # rerun deploy rest
         deploy_rest(true)

         # restore original client
         @mlRest = org_mlRest
      end
    end
  end

  def deploy_rest_config ()
    if (@properties.has_key?('ml.rest-options.dir') && File.exist?(@properties['ml.rest-options.dir']))

      prop_path = "#{@properties['ml.rest-options.dir']}/properties.xml"
      if (File.exist?(prop_path))
        mlRest.install_properties(ServerConfig.expand_path(prop_path))
      end

      options_path = "#{@properties['ml.rest-options.dir']}/options"
      if (File.exist?(options_path))
        mlRest.install_options(ServerConfig.expand_path(options_path))
      end

    else
      logger.info "\nNo REST API options found in: #{@properties['ml.rest-options.dir']}";
    end
  end

  def deploy_ext
    extension = find_arg(['--file'])
    path = @properties['ml.rest-ext.dir']
    if !extension.blank?
      path += "/#{extension}"
    end

    # Deploy extensions to the REST API server
    if (@properties.has_key?('ml.rest-ext.dir') && File.exist?(@properties['ml.rest-ext.dir']))
      logger.info "\nLoading REST extensions from #{path}\n"
      mlRest.install_extensions(ServerConfig.expand_path(path))
    else
      logger.info "\nNo REST extensions found in: #{path}";
    end
  end

  def deploy_transform
    transform = find_arg(['--file'])
    path = @properties['ml.rest-transforms.dir']
    if !transform.blank?
      path += "/#{transform}"
    end

    # Deploy transforms to the REST API server
    if ['rest', 'hybrid'].include? @properties["ml.app-type"]
      if (@properties.has_key?('ml.rest-transforms.dir') && File.exist?(@properties['ml.rest-transforms.dir']))
        logger.info "\nLoading REST transforms from #{path}\n"
        mlRest.install_transforms(ServerConfig.expand_path(path))
      else
        logger.info "\nNo REST transforms found in: #{path}";
      end
      logger.info("")
    end
  end

  def deploy_schemas
    if @properties.has_key?('ml.schemas-db')
      schema_db = @properties['ml.schemas-db']
    else
      logger.info "\nWarning: app-specific schemas database not defined. Deploying schemas to the Schemas database. The clean and wipe commands will not remove these schemas.\n"
      schema_db = "Schemas"
    end
    total_count = load_data @properties["ml.schemas.dir"],
      :add_prefix => @properties["ml.schemas-root"],
      :remove_prefix => @properties["ml.schemas.dir"],
      :db => schema_db
    logger.info "\nLoaded #{total_count} #{pluralize(total_count, "schema", "schemas")} from #{@properties["ml.schemas.dir"]} to #{xcc.hostname}:#{xcc.port}/#{schema_db}\n"
  end

  def clean_modules
    logger.info "Cleaning #{@properties['ml.modules-db']} on #{@hostname}"

    r = execute_query %Q{
      for $id in xdmp:database-forests(xdmp:database("#{@properties['ml.modules-db']}"))
      return
        try { xdmp:forest-clear($id) } catch ($ignore) { fn:concat("Skipped forest ", xdmp:forest-name($id), "..") }
    }
    r.body = parse_body(r.body)
    logger.info r.body

    if @properties['ml.test-modules-db'].present? && @properties['ml.test-modules-db'] != @properties['ml.modules-db']
      logger.info "Cleaning #{@properties['ml.test-modules-db']} on #{@hostname}"
      r = execute_query %Q{
        for $id in xdmp:database-forests(xdmp:database("#{@properties['ml.test-modules-db']}"))
        return
          try { xdmp:forest-clear($id) } catch ($ignore) { fn:concat("Skipped forest ", xdmp:forest-name($id), "..") }
      }
    end
  end

  def clean_schemas
    if @properties['ml.schemas-db']
      logger.info "Cleaning #{@properties['ml.schemas-db']} on #{@hostname}"
      r = execute_query %Q{
        for $id in xdmp:database-forests(xdmp:database("#{@properties['ml.schemas-db']}"))
        return
          try { xdmp:forest-clear($id) } catch ($ignore) { fn:concat("Skipped forest ", xdmp:forest-name($id), "..") }
      }
    else
      logger.error "No schemas db is configured"
    end
  end

  def deploy_content
    count = load_data @properties["ml.data.dir"],
                      :remove_prefix => @properties["ml.data.dir"],
                      :db => @properties['ml.content-db'],
                      :permissions => permissions(@properties['ml.app-role'], Roxy::ContentCapability::RU)
    logger.info "\nLoaded #{count} #{pluralize(count, "document", "documents")} from #{@properties["ml.data.dir"]} to #{xcc.hostname}:#{xcc.port}/#{@properties['ml.content-db']}\n"
  end

  def clean_content
    logger.info "Cleaning #{@properties['ml.content-db']} on #{@hostname}"
    r = execute_query %Q{
      for $id in xdmp:database-forests(xdmp:database("#{@properties['ml.content-db']}"))
      return
        try { xdmp:forest-clear($id) } catch ($ignore) { fn:concat("Skipped forest ", xdmp:forest-name($id), "..") }
    }
    r.body = parse_body(r.body)
    logger.info r.body
  end

  def deploy_cpf
    default_cpf_config_file = ServerConfig.expand_path(ServerConfig.properties["ml.pipeline-config-file"])
    cpf_config_file = ServerConfig.expand_path(@properties["ml.pipeline-config-file"])

    if @properties["ml.triggers-db"].blank? || @properties["ml.data.dir"].blank?
      logger.error "To use CPF, you must define the triggers-db property in your deploy/build.properties file"
    elsif !File.exist?(cpf_config_file)
      msg = "Before you can deploy CPF, you must define a configuration. Steps:"
      if !File.exist?(default_cpf_config_file) && !File.exist?(cpf_config_file)
        msg = msg + "\n- CPF requires a pipeline-config file, run ml initcpf to create a sample."
      end
      if !File.exist?(cpf_config_file) && cpf_config_file != default_cpf_config_file
        msg = msg + "\n- Copy #{ServerConfig.strip_path(default_cpf_config_file)} to #{ServerConfig.strip_path(cpf_config_file)}."
      end
      msg = msg + "\n- Edit #{ServerConfig.strip_path(cpf_config_file)} to customize your domain and pipelines for the given environment."
      logger.error msg
    else
      cpf_config = File.read cpf_config_file
      replace_properties(cpf_config, ServerConfig.strip_path(cpf_config_file))
      cpf_code = File.read ServerConfig.expand_path("#{@@path}/lib/xquery/cpf.xqy")
      query = %Q{#{cpf_code} cpf:load-from-config(#{cpf_config})}
      logger.debug(query)
      r = execute_query(query, :db_name => @properties["ml.content-db"])
    end
  end

  def clean_cpf
    cpf_code = File.read ServerConfig.expand_path("#{@@path}/lib/xquery/cpf.xqy")
    r = execute_query %Q{#{cpf_code} cpf:clean-cpf()}, :db_name => @properties["ml.content-db"]
  end

  def xcc
    @xcc ||=
      begin
        password_prompt
        @xcc = Roxy::Xcc.new({
          :user_name => @ml_username,
          :password => @ml_password,
          :xcc_server => @hostname,
          :xcc_port => @properties["ml.xcc-port"],
          :logger => logger,
          :http_connection_retry_count => @properties["ml.http.retry-count"].to_i,
          :http_connection_open_timeout => @properties["ml.http.open-timeout"].to_i,
          :http_connection_read_timeout => @properties["ml.http.read-timeout"].to_i,
          :http_connection_retry_delay => @properties["ml.http.retry-delay"].to_i
        })
      end
  end

  def mlRest
    if (!@mlRest)
      @mlRest = Roxy::MLRest.new({
        :user_name => @ml_username,
        :password => @ml_password,
        :server => @hostname,
        :app_port => @properties["ml.app-port"],
        :rest_port => @properties["ml.rest-port"],
        :logger => @logger,
        :server_version => @server_version,
        :http_connection_retry_count => @properties["ml.http.retry-count"].to_i,
        :http_connection_open_timeout => @properties["ml.http.open-timeout"].to_i,
        :http_connection_read_timeout => @properties["ml.http.read-timeout"].to_i,
        :http_connection_retry_delay => @properties["ml.http.retry-delay"].to_i,
        :use_https_for_rest => @properties["ml.ssl-certificate-template"].present? || @properties["ml.use-https-for-rest"] == "true"
      })
    else
      @mlRest
    end
  end

  def get_config
    if @server_version > 7 && @properties["ml.app-type"] == 'rest' && @properties["ml.url-rewriter"] == "/MarkLogic/rest-api/rewriter.xqy"
      @logger.info "WARN: XQuery REST rewriter has been deprecated since MarkLogic 8"
      @properties["ml.url-rewriter"] = "/MarkLogic/rest-api/rewriter.xml"

    elsif @server_version < 8 && @properties["ml.app-type"] == 'rest' && @properties["ml.url-rewriter"] == "/MarkLogic/rest-api/rewriter.xml"
      @logger.info "WARN: XML REST rewriter not supported on MarkLogic 7 or less"
      @properties["ml.url-rewriter"] = "/MarkLogic/rest-api/rewriter.xqy"

    elsif @server_version > 7 && @properties["ml.app-type"] == 'hybrid'
      @logger.info "WARN: Running the hybrid app-type with MarkLogic 8 is not recommended."
      @logger.info "      Doing so requires manual patching of the Roxy rewriter."
      @logger.info "      You will be unable to access all of the MarkLogic REST features."
      @logger.info "      See https://github.com/marklogic/roxy/issues/416 for details."
    end

    @config ||= build_config(@options[:config_file])
  end

  def execute_query_4(query, properties)
    url = "#{@protocol}://#{@hostname}:#{@bootstrap_port}/use-cases/eval2.xqy"
    params = {
      :queryInput => query
    }
    r = go(url, "post", {}, params)
  end

  def get_any_db_id
    url = "#{@protocol}://#{@hostname}:#{@bootstrap_port}/manage/LATEST/databases?format=xml"
    r = go(url, "get")
    return nil unless r.code.to_i == 200
    dbid = $1 if r.body =~ /.*<idref>([^<]+)<\/idref>.*/
  end

  def get_db_id(db_name)
    url = "#{@protocol}://#{@hostname}:#{@bootstrap_port}/manage/LATEST/databases?format=xml"
    r = go(url, "get")
    return nil unless r.code.to_i == 200

    use_next_line = false
    r.body.split("\n").each do |line|
      if use_next_line == true
        dbid = $1 if line =~ /.*<idref>([^<]+)<\/idref>.*/
        return dbid
      end

      use_next_line = true if line.match(db_name)
    end

    nil
  end

  def get_sid(app_name)
    url = "#{@protocol}://#{@hostname}:#{@bootstrap_port}/manage/LATEST/servers?format=xml"
    r = go(url, "get")
    return nil unless r.code.to_i == 200

    previous_line = ""
    r.body.split("\n").each do |line|
      if line.match "<nameref>#{app_name}</nameref>"
        dbid = $1 if previous_line =~ /.*<idref>([^<]+)<\/idref>.*/
        return dbid
      end

      previous_line = line
    end

    nil
  end

  def create_roxy_workspace
    ws_id = nil
    q_id = nil

    url = "#{@protocol}://#{@hostname}:#{@qconsole_port}/qconsole/endpoints/workspaces.xqy"

    # weird stuff on windows is fixed by {} for params
    r = go(url, "post", {}, {})
    return nil unless r.code.to_i == 200

    r.body.split("\n").each do |line|
      ws_id = $1 if line =~ /.*"workspace":\{"id":"(\d+)".*/
      q_id = $1 if line =~ /.*"queries":\[\{"id":"(\d+)".*/
    end

    return ws_id, q_id
  end

  def delete_workspace(ws_id)
    url = "#{@protocol}://#{@hostname}:#{@qconsole_port}/qconsole/endpoints/workspaces.xqy?wsid=#{ws_id}"
    r = go(url, "delete")
    return ws_id unless r.code.to_i == 200
  end

  def execute_query_5(query, properties = {})
    # We need a context for this query. Here's what we look for, in order of preference:
    # 1. A caller-specified database
    # 2. A caller-specified application server
    # 3. An application server that is present by default
    # 4. Any database
    if properties[:db_name] != nil
      db_id = get_db_id(properties[:db_name])
      logger.warn "WARN: No Database with name #{properties[:db_name]} found" if db_id.nil?
    elsif properties[:app_name] != nil
      sid = get_sid(properties[:app_name])
      logger.warn "WARN: No App-Server with name #{properties[:app_name]} found" if sid.nil?
    else
      sid = get_sid("Manage")
    end

    db_id = get_any_db_id if db_id.nil? && sid.nil?

    url = "#{@protocol}://#{@hostname}:#{@qconsole_port}/qconsole/endpoints/eval.xqy"
    if db_id.present?
      logger.debug "using dbid: #{db_id}"
      params = {
        :dbid => db_id,
        :resulttype => "text",
        :q => query
      }
      r = go(url, "post", {}, params)
      logger.debug r.body
    else
      logger.debug "using sid: #{sid}"
      params = {
        :sid => sid,
        :resulttype => "text",
        :q => query
      }
      r = go(url, "post", {}, params)
      logger.debug r.body
    end

    raise ExitException.new(JSON.pretty_generate(JSON.parse(r.body))) if r.body.match(/\{"error"/)

    r
  end

  def execute_query_7(query, properties = {})
    # We need a context for this query. Here's what we look for, in order of preference:
    # 1. A caller-specified database
    # 2. A caller-specified application server
    # 3. An application server that is present by default
    # 4. Any database
    if properties[:db_name] != nil
      db_id = get_db_id(properties[:db_name])
      logger.warn "WARN: No Database with name #{properties[:db_name]} found" if db_id.nil?
    elsif properties[:app_name] != nil
      sid = get_sid(properties[:app_name])
      logger.warn "WARN: No App-Server with name #{properties[:app_name]} found" if sid.nil?
    else
      sid = get_sid("Manage")
    end

    ws_id, q_id = create_roxy_workspace()
    raise ExitException.new("Can't create Roxy workspace in QConsole") unless ws_id && q_id

    db_id = get_any_db_id if db_id.nil? && sid.nil?

    # necessary to work around weirdness on windows
    headers = {
      'content-type' => 'text/plain'
    }

    url = "#{@protocol}://#{@hostname}:#{@qconsole_port}/qconsole/endpoints/evaler.xqy?wsid=#{ws_id}&qid=#{q_id}&action=eval&querytype=xquery&dirty=true"
    if db_id.present?
      url = url + "&dbid=#{db_id}"
      r = go(url, "post", headers, nil, query)
    else
      url = url + "&sid=#{sid}"
      r = go(url, "post", headers, nil, query)
    end

    delete_workspace(ws_id) if ws_id

    raise ExitException.new(JSON.pretty_generate(JSON.parse(r.body))) if r.body.match(/\{"error"/)

    r
  end

  def execute_query_8(query, properties = {})
    # check input like in older versions
    if properties[:db_name] != nil
      db_id = get_db_id(properties[:db_name])
      raise ExitException.new("No Database with name #{properties[:db_name]} found") if db_id.nil?
    elsif properties[:app_name] != nil
      sid = get_sid(properties[:app_name])
      raise ExitException.new("No Server with name #{properties[:app_name]} found") if sid.nil?
    end

    headers = {
      "Content-Type" => "application/x-www-form-urlencoded"
    }
    params = {}

    # If app_name is specified, wrap the eval in an xdmp:eval to create an eval context
    # that matches that of the selected app-server
    if properties[:app_name] != nil
      params[:xquery] = %Q{
        xquery version "1.0-ml";

        (: derived from qconsole-amped.xqy :)
        declare function local:eval-options(
          $server-id as xs:unsignedLong
        ) as element()
        {
          let $database-id := xdmp:server-database($server-id)
          let $collation := xdmp:server-collation($server-id)
          let $modules-id := xdmp:server-modules-database($server-id)
          let $xquery-version := xdmp:server-default-xquery-version($server-id)
          let $modules-root := xdmp:server-root($server-id)
          let $default-coordinate-system :=
            (: xdmp:server-coordinate-system not supported in ML8 and older :)
            for $f in fn:function-lookup(xs:QName("xdmp:server-coordinate-system"), 1)
            return $f($server-id)
          return
            <options xmlns="xdmp:eval">{
              if ($database-id eq xdmp:database()) then ()
              else element database { $database-id },

              if ($modules-id eq xdmp:modules-database()) then ()
              else element modules { $modules-id },

              if ($collation eq default-collation()) then ()
              else element default-collation { $collation },

              if (empty($default-coordinate-system)) then ()
              else element default-coordinate-system { $default-coordinate-system },

              if ($xquery-version eq xdmp:xquery-version()) then ()
              else element default-xquery-version { $xquery-version },

              (: we should always have a root path, but better safe than sorry :)
              if (empty($modules-root) or $modules-root eq xdmp:modules-root()) then ()
              else element root { $modules-root },

              element isolation { "different-transaction" }
            }</options>
        };

        let $query := <query><![CDATA[#{query}]]></query>
        return xdmp:eval(
          string($query),
          (),
          local:eval-options(xdmp:server("#{properties[:app_name]}"))
        )
      }
    else
      # No app_name, just run the straight query
      params[:xquery] = query

      # Pass through selected database if specified, otherwise run against App-Services
      if properties[:db_name] != nil
        params[:database] = properties[:db_name]
      end
    end

    r = go "#{@protocol}://#{@hostname}:#{@qconsole_port}/v1/eval", "post", headers, params

    raise ExitException.new(JSON.pretty_generate(JSON.parse(r.body))) if r.body.match(/\{"error"/)

    r
  end

  def ServerConfig.substitute_properties(sub_me, with_me, prefix = "")
    dangling_vars = {}
    begin
      needs_rescan = false
      sub_me.each do |k,v|
        if v.match(/\$\{basedir\}/)
          sub_me[k] = ServerConfig.expand_path(v.gsub("${basedir}", Dir.pwd))
          matches = v.scan(/\$\{([^}]+)\}/)
          needs_rescan = true if matches.length > 1
        else
          matches = v.scan(/\$\{([^}]+)\}/)
          if matches.length > 0
            var = "#{prefix}#{matches[0][0]}"
            sub = with_me[var]
            if sub
              new_val = v.sub(/\$\{[^}]+\}/, sub)
              sub_me[k] = new_val
              needs_rescan = true if matches.length > 1
            else
              dangling_vars[k] = v
            end
          end
        end
      end
    end while (needs_rescan == true)

    raise DanglingVarsException.new(dangling_vars) if dangling_vars.length > 0

    sub_me
  end

  def ServerConfig.load_properties(properties_filename, prefix = "")
    properties = {}
    File.open(properties_filename, 'r') do |properties_file|
      properties_file.read.each_line do |line|
        line.strip!
        if (line[0] != ?#) && (line[0] != ?=) && (line[0] != "")
          i = line.index('=')
          if i
            key = prefix + line[0..i - 1].strip
            value = line[i + 1..-1].strip
            properties[key] = ENV[key.gsub(/[^0-9A-Za-z_]/, '_')] || value
          end
        end
      end
    end

    properties
  end

  def conditional_prop(prop, default_prop)

    value = @properties[prop]
    if !@properties[prop].present?
      value = @properties[default_prop]
    end

    value
  end

  def triggers_db_xml
    %Q{
      <database>
        <database-name>@ml.triggers-db</database-name>
        <forests>
          <forest-id name="@ml.triggers-db"/>
        </forests>
      </database>
    }
  end

  def triggers_assignment
    %Q{
      <assignment>
        <forest-name>@ml.triggers-db</forest-name>
      </assignment>
    }
  end

  def xdbc_server
    xdbc_auth_method = conditional_prop('ml.xdbc-authentication-method', 'ml.authentication-method')
    %Q{
      <xdbc-server>
        <xdbc-server-name>@ml.app-name-xcc</xdbc-server-name>
        <port>@ml.xcc-port</port>
        <database name="@ml.content-db"/>
        <modules name="@ml.modules-db"/>
        <authentication>#{xdbc_auth_method}</authentication>
      </xdbc-server>
    }
  end

  def odbc_server
    odbc_auth_method = conditional_prop('ml.odbc-authentication-method', 'ml.authentication-method')
    %Q{
      <odbc-server>
        <odbc-server-name>@ml.app-name-odbc</odbc-server-name>
        <port>@ml.odbc-port</port>
        <database name="@ml.content-db"/>
        <modules name="@ml.modules-db"/>
        <authentication>#{odbc_auth_method}</authentication>
      </odbc-server>
    }
  end

  def schemas_db_xml
    %Q{
      <database>
        <database-name>@ml.schemas-db</database-name>
        <forests>
          <forest-id name="@ml.schemas-db"/>
        </forests>
      </database>
    }
  end

  def schemas_assignment
    %Q{
      <assignment>
        <forest-name>@ml.schemas-db</forest-name>
      </assignment>
    }
  end

  def test_content_db_xml
    %Q{
      <database import="@ml.content-db">
        <database-name>@ml.test-content-db</database-name>
        <forests>
          <forest-id name="@ml.test-content-db"/>
        </forests>
      </database>
    }
  end

  def test_content_db_assignment
    %Q{
      <assignment>
        <forest-name>@ml.test-content-db</forest-name>
      </assignment>
    }
  end

  def test_appserver
    # The modules database for the test server can be different from the app one
    test_modules_db = conditional_prop('ml.test-modules-db', 'ml.modules-db')
    test_auth_method = conditional_prop('ml.test-authentication-method', 'ml.authentication-method')
    test_default_user = conditional_prop('ml.test-default-user', 'ml.default-user')

    %Q{
      <http-server import="@ml.app-name">
        <http-server-name>@ml.app-name-test</http-server-name>
        <port>@ml.test-port</port>
        <database name="@ml.test-content-db"/>
        <modules name="#{test_modules_db}"/>
        <authentication>#{test_auth_method}</authentication>
        <default-user name="#{test_default_user}"/>
      </http-server>
    }
  end

  def test_modules_db_xml
    %Q{
      <database import="@ml.modules-db">
        <database-name>@ml.test-modules-db</database-name>
        <forests>
          <forest-id name="@ml.test-modules-db"/>
        </forests>
      </database>
    }
  end

  def test_user_xml
    %Q{
      <user>
        <user-name>${test-user}</user-name>
        <description>A user for the ${app-name} unit tests</description>
        <password>${test-user-password}</password>
        <role-names>
          <role-name>${app-role}-unit-test</role-name>
        </role-names>
        <permissions/>
        <collections/>
      </user>
    }
  end

  def test_modules_db_assignment
    %Q{
      <assignment>
        <forest-name>@ml.test-modules-db</forest-name>
      </assignment>
    }
  end

  def rest_appserver
    rest_modules_db = conditional_prop('ml.rest-modules-db', 'ml.modules-db')
    rest_auth_method = conditional_prop('ml.rest-authentication-method', 'ml.authentication-method')
    rest_default_user = conditional_prop('ml.rest-default-user', 'ml.default-user')

    rest_url_rewriter = nil
    if @properties['ml.rest-url-rewriter'].present?
      rest_url_rewriter = @properties['ml.rest-url-rewriter']
    elsif @server_version > 7
      rest_url_rewriter = '/MarkLogic/rest-api/rewriter.xml'
    else
      rest_url_rewriter = '/MarkLogic/rest-api/rewriter.xqy'
    end

    %Q{
      <http-server import="@ml.app-name">
        <http-server-name>@ml.app-name-rest</http-server-name>
        <port>@ml.rest-port</port>
        <database name="@ml.content-db"/>
        <modules name="#{rest_modules_db}"/>
        <authentication>#{rest_auth_method}</authentication>
        <default-user name="#{rest_default_user}"/>
        <url-rewriter>#{rest_url_rewriter}</url-rewriter>
        <error-handler>/MarkLogic/rest-api/error-handler.xqy</error-handler>
        <rewrite-resolves-globally>true</rewrite-resolves-globally>
      </http-server>
    }
  end

  def rest_modules_db_xml
    rest_modules_db = conditional_prop('ml.rest-modules-db', 'ml.modules-db')

    %Q{
      <database>
        <database-name>#{rest_modules_db}</database-name>
        <forests>
          <forest-id name="#{rest_modules_db}"/>
        </forests>
      </database>
    }
  end

  def rest_modules_db_assignment
    rest_modules_db = conditional_prop('ml.rest-modules-db', 'ml.modules-db')

    %Q{
      <assignment>
        <forest-name>#{rest_modules_db}</forest-name>
      </assignment>
    }
  end

  def ssl_certificate_xml
    %Q{
      <certificate>
        <name>@ml.ssl-certificate-template</name>
        <countryName>@ml.ssl-certificate-countryName</countryName>
        <stateOrProvinceName>@ml.ssl-certificate-stateOrProvinceName</stateOrProvinceName>
        <localityName>@ml.ssl-certificate-localityName</localityName>
        <organizationName>@ml.ssl-certificate-organizationName</organizationName>
        <organizationalUnitName>@ml.ssl-certificate-organizationalUnitName</organizationalUnitName>
        <emailAddress>@ml.ssl-certificate-emailAddress</emailAddress>
      </certificate>
    }
  end

  def build_config(config_files)
    configs = []
    config_files.split(",").each do |config_file|
      config = File.read(config_file)

      # Build the triggers db if it is provided
      if @properties['ml.triggers-db'].present?

        if @properties['ml.triggers-db'] != @properties['ml.modules-db']
          config.gsub!("@ml.triggers-db-xml", triggers_db_xml)
          config.gsub!("@ml.triggers-assignment", triggers_assignment)
        else
          config.gsub!("@ml.triggers-db-xml", "")
          config.gsub!("@ml.triggers-assignment", "")
        end

        config.gsub!("@ml.triggers-mapping",
          %Q{
          <triggers-database name="@ml.triggers-db"/>
          })

      else
        config.gsub!("@ml.triggers-db-xml", "")
        config.gsub!("@ml.triggers-assignment", "")
        config.gsub!("@ml.triggers-mapping", "")
      end

      if @properties['ml.xcc-port'].present? and @properties['ml.install-xcc'] != 'false'
        config.gsub!("@ml.xdbc-server", xdbc_server)
      else
        config.gsub!("@ml.xdbc-server", "")
      end

      if @properties['ml.odbc-port'].present?
        config.gsub!("@ml.odbc-server", odbc_server)
      else
        config.gsub!("@ml.odbc-server", "")
      end

      # Build the schemas db if it is provided
      if @properties['ml.schemas-db'].present?

        if @properties['ml.schemas-db'] != @properties['ml.modules-db']
          config.gsub!("@ml.schemas-db-xml", schemas_db_xml)
          config.gsub!("@ml.schemas-assignment", schemas_assignment)
        else
          config.gsub!("@ml.schemas-db-xml", "")
          config.gsub!("@ml.schemas-assignment", "")
        end

        config.gsub!("@ml.schemas-mapping",
          %Q{
          <schema-database name="@ml.schemas-db"/>
          })

      else
        config.gsub!("@ml.schemas-db-xml", "")
        config.gsub!("@ml.schemas-assignment", "")
        config.gsub!("@ml.schemas-mapping", "")
      end

      # Build the test appserver and db if it is provided
      if @properties['ml.test-content-db'].present? &&
         @properties['ml.test-port'].present? &&
         @environment != "prod"

        config.gsub!("@ml.test-content-db-xml", test_content_db_xml)
        config.gsub!("@ml.test-content-db-assignment", test_content_db_assignment)
        config.gsub!("@ml.test-appserver", test_appserver)

      else
        config.gsub!("@ml.test-content-db-xml", "")
        config.gsub!("@ml.test-content-db-assignment", "")
        config.gsub!("@ml.test-appserver", "")
      end

      # Build the test modules db if it is different from the app modules db
      if @properties['ml.test-modules-db'].present? &&
         @properties['ml.test-modules-db'] != @properties['ml.modules-db']

        config.gsub!("@ml.test-modules-db-xml", test_modules_db_xml)
        config.gsub!("@ml.test-modules-db-assignment", test_modules_db_assignment)

      else
        config.gsub!("@ml.test-modules-db-xml", "")
        config.gsub!("@ml.test-modules-db-assignment", "")
      end

      if @properties['ml.test-user'].present?

        config.gsub!("@ml.test-user-xml", test_user_xml)

      else
        config.gsub!("@ml.test-user-xml", "")
      end

      if @properties['ml.rest-port'].present?

        # Set up a REST API app server, distinct from the main application.
        config.gsub!("@ml.rest-appserver", rest_appserver)

        if @properties['ml.rest-modules-db'].present? &&
           @properties['ml.rest-modules-db'] != @properties['ml.modules-db']
           config.gsub!("@ml.rest-modules-db-xml", rest_modules_db_xml)
           config.gsub!("@ml.rest-modules-db-assignment", rest_modules_db_assignment)
        else
          config.gsub!("@ml.rest-modules-db-xml", "")
          config.gsub!("@ml.rest-modules-db-assignment", "")
        end

      else
        config.gsub!("@ml.rest-appserver", "")
        config.gsub!("@ml.rest-modules-db-xml", "")
        config.gsub!("@ml.rest-modules-db-assignment", "")
      end

      if @properties['ml.forest-data-dir'].present?
        config.gsub!("@ml.forest-data-dir-xml",
          %Q{
            <data-directory>@ml.forest-data-dir</data-directory>
          })
      else
        config.gsub!("@ml.forest-data-dir-xml", "")
      end

      if !@properties['ml.rewrite-resolves-globally'].nil?
        config.gsub!("@ml.rewrite-resolves-globally",
          %Q{
            <rewrite-resolves-globally>#{@properties['ml.rewrite-resolves-globally']}</rewrite-resolves-globally>
          })
      elsif ['rest', 'hybrid'].include?(@properties["ml.app-type"])
        config.gsub!("@ml.rewrite-resolves-globally",
          %Q{
            <rewrite-resolves-globally>true</rewrite-resolves-globally>
          })
      else
        config.gsub!("@ml.rewrite-resolves-globally", "")
      end

      if @properties['ml.ssl-certificate-template'].present?
        config.gsub!("@ml.ssl-certificate-xml", ssl_certificate_xml)
      else
        config.gsub!("@ml.ssl-certificate-xml", "")
      end

      replace_properties(config, File.basename(config_file), true)

      # escape unresolved braces, they have special meaning in XQuery
      config.gsub!("{", "{{")
      config.gsub!("}", "}}")

      configs << config
    end

    %Q{(#{configs.join(", ")})}
  end

  def replace_properties(contents, name, xquery = false)
    # warn for deprecated properties
    deprecated={
      "app-modules-db" => "modules-db"
    }
    contents.scan(/(@ml.|[@$]\{)(app-modules-db)(\}?)/).each do |match|
      key=match[1]
      logger.warn("Deprecated property #{match.join} used in #{name}, please use ${#{deprecated[key]}} instead!")
    end

    # make sure to apply descending order to replace @ml.foo-bar before @ml.foo
    @properties.sort {|x,y| y <=> x}.each do |k, v|
      if xquery
        # escape XML specials, they have special meaning in XQuery
        v = v.xquery_safe
      end

      # new property syntax: @{app-name} or ${app-name}
      n = k.sub("ml.", "")
      contents.gsub!("@{#{n}}", v)
      contents.gsub!("${#{n}}", v)

      # backwards compat, old syntax: @ml.app-name
      contents.gsub!("@#{k}", v)
    end

    # warn for unresolved properties
    contents.scan(/[@$]\{[^}]+\}/).each do |match|
      logger.warn("Unresolved property #{match} in #{name}")
    end
  end

  def ServerConfig.properties(prop_file_location = @@path)
    default_properties_file = ServerConfig.expand_path("#{prop_file_location}/default.properties")
    properties_file = ServerConfig.expand_path("#{prop_file_location}/build.properties")

    raise ExitException.new("You must run ml init to configure your application.") unless File.exist?(properties_file)

    properties = ServerConfig.load_properties(default_properties_file, "ml.")
    properties.merge!(ServerConfig.load_properties(properties_file, "ml."))

    #Look for optional shared_config, if it is set grab the properties from path relative to the root of the roxy project
    if properties['ml.shared_config']
      shared_properties_file = ServerConfig.expand_path("#{@@path}/../#{properties['ml.shared_config']}")
      properties.merge!(ServerConfig.load_properties(shared_properties_file))
    end

    environments = properties['ml.environments'].split(",") if properties['ml.environments']
    environments = ["local", "dev", "prod"] unless environments

    if environments.index(ARGV[0])
      environment = ARGV.shift
    end

    properties["environment"] = environment if environment
    properties["ml.environment"] = environment if environment

    env_properties_file = ServerConfig.expand_path("#{prop_file_location}/#{environment}.properties")

    properties.merge!(ServerConfig.load_properties(env_properties_file, "ml.")) if File.exists? env_properties_file

    properties = load_prop_from_args(properties)

    properties = ServerConfig.substitute_properties(properties, properties, "ml.")
  end

end
