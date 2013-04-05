module Roxy
  class MLRest < MLClient
    def initialize(options)
      super(options)
      @hostname = options[:server]
      @port = options[:port]
      @http = Roxy::Http.new({
        :logger => @logger
      })
      @request = {}
      @gmt_offset = Time.now.gmt_offset
    end

    def get_files(path, data = [])
      @logger.debug "getting files for #{path}"
      if (File.directory?(path))
        Dir.glob("#{path}/*.xqy") do |entry|
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

    def install_extensions(path)
      if (File.exists?(path))
        headers = {
          'Content-Type' => 'application/xquery'
        }

        data = get_files(path)
        size = data.length

        data.each_with_index do |d, i|
          file = open(d, "rb")
          contents = file.read
          extensionName = $1 if contents =~ /"http:\/\/marklogic.com\/rest-api\/resource\/([^"]+)"/
          params = []
          contents.scan(/function\s+[^:]+:(get|put|post|delete)/).each do |m|
            params << "method=#{m[0]}"
          end

          # look for annotations of this form:
          # %roxy:params("argname=type", "anotherarg=type")
          contents.scan(/declare\s+(\%\w+:\w+\(([\"\w\-\=\,\s:]*)\))*\s*function\s+[^:]+:(get|put|post|delete)/m).each do |m|
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

          @logger.debug "params: #{params}"
          @logger.debug "extensionName: #{extensionName}"
          # @logger.debug "methods: #{methods}"
          url = "http://#{@hostname}:#{@port}/v1/config/resources/#{extensionName}"
          if (params.length > 0)
            url << "?" << params.join("&")
          end
          @logger.debug "loading: #{d}"

          @logger.debug "url: #{url}"
          r = go url, "put", headers, nil, contents
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