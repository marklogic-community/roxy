module Roxy
  class MLRest < MLClient
    def initialize(options)
      super(options)
      @hostname = options[:server]
      @port = options[:rest_port]
      if !@port or @port == ""
        @port = options[:app_port]
      end
      @http = Roxy::Http.new({
        :logger => @logger,
        :http_connection_retry_count => options[:http_connection_retry_count],
        :http_connection_open_timeout => options[:http_connection_open_timeout],
        :http_connection_read_timeout => options[:http_connection_read_timeout],
        :http_connection_retry_delay => options[:http_connection_retry_delay]
      })
      @request = {}
      @gmt_offset = Time.now.gmt_offset
      @server_version = options[:server_version]
      @rest_protocol = "http#{options[:use_https_for_rest] ? 's' : ''}"

    end

    def get_files(path, data = [])
      @logger.debug "getting files for #{path}"
      if (File.directory?(path))
        Dir.glob("#{path}/*.{xqy,xqe,xq,xquery,xslt,xsl,sjs}") do |entry|
          if File.directory?(entry)
            get_files(entry, data)
          else
            data << entry
          end
        end
      else
        data = [path]
      end
      data
    end

    def install_properties(path)
      @logger.info("Loading REST properties in #{path}")
      if (File.exists?(path))
        headers = {
          'Content-Type' => 'application/xml'
        }

        data = [path]

        data.each_with_index do |d, i|
          file = open(d, "rb")
          contents = file.read

          if contents.match('<map:map')
            # Properties file needs to be updated
            raise ExitException.new "#{d} is in an old format; changes to this file won't take effect. See https://github.com/marklogic/roxy/wiki/REST-properties-format-change"
          else
            copy = ""+ contents
            copy = copy.gsub(/<!--.*?-->/m, '')
            if @server_version > 7 && copy.match('<error-format')
              @logger.info "WARN: REST property error-format has been deprecated since MarkLogic 8"
              contents = copy.gsub(/<error-format[^>]*>[^<]+<\/error-format>/m, '')
            end
            # Properties is in the correct format
            # @logger.debug "methods: #{methods}"
            url = "#{@rest_protocol}://#{@hostname}:#{@port}/v1/config/properties"

            r = go(url, "put", headers, nil, contents)
            if (r.code.to_i < 200 && r.code.to_i > 206)
              @logger.error("code: #{r.code.to_i} body:#{r.body}")
            end
          end
        end
      else
        @logger.error "#{path} does not exist"
      end
    end

    def install_options(path)
      @logger.info("Loading REST options in #{path}")
      if (File.exists?(path))
        Dir.foreach(path) do |item|
          next if item == '.' or item == '..'

          file = open("#{path}/#{item}", "rb")
          ext = File.extname(item)
          basename = File.basename(item, ext)

          headers = {}
          if (ext == '.xml')
            headers['Content-Type'] = 'application/xml'
          elsif (ext == '.json')
            headers['Content-Type'] = 'application/json'
          else
            @logger.error("Unrecognized REST options format: #{item}")
          end

          contents = file.read

          r = go("#{@rest_protocol}://#{@hostname}:#{@port}/v1/config/query/#{basename}", "put", headers, nil, contents)
          if (r.code.to_i < 200 && r.code.to_i > 206)
            @logger.error("code: #{r.code.to_i} body:#{r.body}")
          end
        end
      else
        @logger.error "#{path} does not exist"
      end
    end

    def install_extensions(path)
      if (File.exists?(path))

        data = get_files(path)
        size = data.length

        data.each_with_index do |d, i|
          file = open(d, "rb")
          contents = file.read

          file_ext = File.extname(d)[1..-1]
          file_name = File.basename(d, ".*")

          is_sjs = (file_ext == "sjs")
          is_xsl = file_ext.include?("xsl")
          next if is_xsl # XSLT rest extension not supported

          @logger.debug "Deploying #{File.basename(d)}"

          headers = {
            'Content-Type' => (is_sjs ? 'application/vnd.marklogic-javascript' : 'application/xquery')
          }
          params = []

          extensionName = file_name

          if (is_sjs)

            contents.scan(/@name\s+(\b\w*\b)/).each do |m|
               if (!m[0].nil? || !m[0].to_s.empty?)
                 extensionName = m[0]
               end
            end

            contents.scan(/exports+[.]+(GET|PUT|POST|DELETE)/).each do |m|
              params << "method=#{m[0].downcase}"
            end

            # look for annotations of this form:
            # /**
            #  * @param {string} myString The string
            #  * @param {int} myInt The integer
            #  */
            # exports.GET = get;
            args = []
            contents.scan(/exports+[.]+(GET|PUT|POST|DELETE)|@param\s+[\{]+(string|int)+[\}]\s+(\b\w*\b)/m).each do |m|
              if (!m[1].nil? && !m[1].to_s.empty? && !m[2].nil? && !m[2].to_s.empty?)
                args << ":#{m[2]}=xs:#{m[1]}"
              end
              if (!m[0].nil? || !m[0].to_s.empty?)
                args.each do |arg|
                  params << "#{m[0].downcase}#{arg}"
                end
                args = []
              end
            end

          else
            # XQuery

            extensionName = $1 if contents =~ /module\s*namespace\s*[\w\-]+\s*=\s*"http:\/\/marklogic.com\/rest-api\/resource\/([^"]+)"/

            contents.scan(/function\s+[^:]+:(get|put|post|delete)/).each do |m|
              params << "method=#{m[0]}"
            end

            # look for annotations of this form:
            # %roxy:params("argname=type", "anotherarg=type")
            contents.scan(/declare\s+(\%\w+:\w+\(([\"\w\-\=\,\s:?*+]*)\))*\s*function\s+[^:]+:(get|put|post|delete)/m).each do |m|
              args = '';
              verb = m[2]
              if (m[0] && (m[0].include? "%roxy:params"))
                if (m[1].match(/\"/))
                  m[1].gsub!(/\"/, '').split(',').each do |p|
                    arg = p.strip
                    parts = arg.split('=')
                    param = parts[0]
                    type = parts[1]
                    @logger.debug("param: #{param}")
                    @logger.debug("type: #{type}")
                    params << "#{verb}:#{param}=#{url_encode(type)}"
                  end
                end
              end
            end

          end

          @logger.debug "extensionName: #{extensionName}"
          @logger.debug "headers: #{headers}"
          @logger.debug "params: #{params}"

          url = "#{@rest_protocol}://#{@hostname}:#{@port}/v1/config/resources/#{extensionName}"
          if (params.length > 0)
            url << "?" << params.join("&")
          end
          @logger.debug "loading: #{d}"

          r = go(url, "put", headers, nil, contents)
          if (r.code.to_i < 200 && r.code.to_i > 206)
            @logger.error("code: #{r.code.to_i} body:#{r.body}")
          end
        end
      else
        @logger.error "#{path} does not exist"
      end
    end

    def install_transforms(path)
      if (File.exists?(path))

        data = get_files(path)
        size = data.length

        data.each_with_index do |d, i|
          @logger.debug "Deploying #{File.basename(d)}"

          file = open(d, "rb")
          contents = file.read

          file_ext = File.extname(d)[1..-1]
          file_name = File.basename(d, ".*")

          is_sjs = (file_ext == "sjs")
          is_xsl = file_ext.include?("xsl")
          is_xqy = file_ext.include?("xq")

          headers = {
            'Content-Type' => (is_sjs ? 'application/vnd.marklogic-javascript' : (is_xsl ? 'application/xslt+xml': 'application/xquery'))
          }

          transformName = file_name
          params = []

          if (is_sjs)

            # look for annotations of this form:
            # /**
            #  * @param {string} myString The string
            #  * @param {int} myInt The integer
            #  */
            # exports.GET = get;
            args = []
            contents.scan(/exports+[.]+(GET|PUT|POST|DELETE)|@param\s+[\{]+([^\}]+)+[\}]\s+(\b\w*\b)/m).each do |m|
              if (!m[1].nil? && !m[1].to_s.empty? && !m[2].nil? && !m[2].to_s.empty?)
                args << ":#{m[2]}=xs:#{m[1]}"
              end
              if (!m[0].nil? || !m[0].to_s.empty?)
                args.each do |arg|
                  params << "#{m[0].downcase}#{arg}"
                end
                args = []
              end
            end

          elsif (is_xsl)

            # look for annotations of this form:
            # %roxy:params("argname=type", "anotherarg=type")
            contents.scan(/<!--\s*(\%\w+:\w+\(([\"\w\-\=\,\s:?*+]*)\))*\s*-->/m).each do |m|
              args = '';
              if (m[0] && (m[0].include? "%roxy:params"))
                if (m[1].match(/\"/))
                  m[1].gsub!(/\"/, '').split(',').each do |p|
                    arg = p.strip
                    parts = arg.split('=')
                    param = parts[0]
                    type = parts[1]
                    @logger.debug("param: #{param}")
                    @logger.debug("type: #{type}")
                    params << "trans:#{param}=#{url_encode(type)}"
                  end
                end
              end
            end

          else # XQuery

            # look for annotations of this form:
            # %roxy:params("argname=type", "anotherarg=type")
            contents.scan(/declare\s+(\%\w+:\w+\(([\"\w\-\=\,\s:?*+]*)\))*\s*function/m).each do |m|
              args = '';
              if (m[0] && (m[0].include? "%roxy:params"))
                if (m[1].match(/\"/))
                  m[1].gsub!(/\"/, '').split(',').each do |p|
                    arg = p.strip
                    parts = arg.split('=')
                    param = parts[0]
                    type = parts[1]
                    @logger.debug("param: #{param}")
                    @logger.debug("type: #{type}")
                    params << "trans:#{param}=#{url_encode(type)}"
                  end
                end
              end
            end
          end

          @logger.debug "transformName: #{transformName}"
          @logger.debug "headers: #{headers}"
          @logger.debug "params: #{params}"
          url = "#{@rest_protocol}://#{@hostname}:#{@port}/v1/config/transforms/#{transformName}"
          if (params.length > 0)
            url << "?" << params.join("&")
          end
          @logger.debug "loading: #{d}"

          r = go(url, "put", headers, nil, contents)
          if (r.code.to_i < 200 && r.code.to_i > 206)
            @logger.error("code: #{r.code.to_i} body:#{r.body}")
          end
        end

      else
        @logger.error "#{path} does not exist"
      end
    end
  end
end
