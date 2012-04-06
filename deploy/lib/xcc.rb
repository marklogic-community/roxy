###############################################################################
# Copyright 2012 MarkLogic Corporation
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
require 'uri'
require 'net/http'
require File.expand_path('../Http', __FILE__)
require File.expand_path('../MLClient', __FILE__)

RUBY_XCC_VERSION = "0.9a"
XCC_VERSION = "5.0-2"
LOCALE = "en_US"

module Net
  class HTTPGenericRequest
    def set_path(path)
      @path = path
    end

    def write_header(sock, ver, path)
      buf = "#{@method} #{path} XDBC/1.0\r\n"
      each_capitalized do |k,v|
        buf << "#{k}: #{v}\r\n"
      end
      buf << "\r\n"
      sock.write buf
    end
  end

  class << HTTPResponse
    def read_status_line(sock)
      str = sock.readline
      m = /\A(?:HTTP|XDBC)(?:\/(\d+\.\d+))?\s+(\d\d\d)\s*(.*)\z/in.match(str) or
        raise HTTPBadResponse, "wrong status line: #{str.dump}"
      m.captures
  	end
  end

  # Turns on keep-alive for xcc in Ruby 1.8.x
  class HTTP
    def keep_alive?(req, res)
      true
    end
  end

  # Turns on keep-alive for xcc in Ruby 1.9.x
  module HTTPHeader
    def connection_keep_alive?
      true
    end
  end
end

module Roxy
  class ContentCapability
    READ = "R"
    INSERT = "I"
    UPDATE = "U"
    EXECUTE = "E"
  end

  class Xcc < MLClient
    def initialize(options)
      super(options)
      @hostname = options[:xcc_server]
      @port = options[:xcc_port]
      @http = Roxy::Http.new({
        :logger => @logger
      })
      @request = {}
      @gmt_offset = Time.now.gmt_offset
    end

    def go(url, verb, headers = {}, params = nil, body = nil)
      headers['User-Agent'] = "Roxy RubyXCC/#{RUBY_XCC_VERSION}  MarkXDBC/#{XCC_VERSION}"
      super(url, verb, headers, params, body)
    end

    def xcc_query(options)
      headers = {}

      params = {
        :xquery => options[:query],
        :locale => LOCALE,
        :tzoffset => "-18000",
        :dbname => options[:db]
      }

      r = go "http://#{options[:host]}:#{options[:port]}/eval", "post", headers, params
    end

    def get_files(path, options = {}, data = [])
      @logger.debug "getting files for #{path}"
      if (File.directory?(path))
        Dir.foreach(path) do |entry|
          next if (entry == '..' || entry == '.' || entry == '.svn' || entry == '.git' || entry == '.DS_Store' || entry == "Thumbs.db" || entry == "thumbs.db")
          full_path = File.join(path, entry)
          skip = false
          if (options && options[:ignore_list])
            options[:ignore_list].each do |ignore|
              if full_path.match(ignore)
                skip = true
                break
              end
            end
          end
          next if skip == true
          if File.directory?(full_path)
            get_files(full_path, options, data)
          else
            data << full_path
          end
        end
      else
        data = [path]
      end
      data
    end

    def build_load_uri(file_uri, options, commit)
      url = "http://#{@hostname}:#{@port}/insert?"

      file_uri = file_uri.sub(options[:remove_prefix] || "", "")
      if (options[:add_prefix])
        prefix = options[:add_prefix].chomp("/")
        file_uri = prefix + file_uri
      end

      url << "uri=#{url_encode(file_uri)}"

      if (options[:locale])
        url << "&locale=#{options[:locale]}"
      end

      if (options[:language])
        url << "&lang=#{options[:language]}"
      end

      if (options[:namespace])
        url << "&defaultns=#{options[:namespace]}"
      end

      if (options[:quality])
        url << "&quality=#{options[:quality]}"
      end

      if (options[:repairlevel] == "none")
        url << "&repair=none"
      elsif(options[:repairlevel] == "full")
        url << "&repair=full"
      end

      if (options[:format] == "xml")
        url << "&format=xml"
      elsif(options[:format] == "text")
        url << "&format=text"
      elsif(options[:format] == "binary")
        url << "&format=binary"
      end

      if (options[:collections])
        options[:collections].each do |collection|
          url << "&col=#{collection}"
        end
      end

      if (options[:permissions])
        options[:permissions].each do |perm|
          url << "&perm=#{perm[:capability]}#{perm[:role]}"
        end
      end

      url << "&tzoffset=#{@gmt_offset}"

      if (options[:db])
        url << "&dbname=#{options[:db]}"
      end
      # "&perm=Eapp-user&perm=Rapp-user&locale=#{LOCALE}&tzoffset=-18000&dbname=#{options[:db]}"

      if (false == commit)
        url << "&nocommit"
      end

      url
    end

    def prep_body(path, commit)
      file = open(path, "rb")

      #flag that ML server is expecting
      flag = commit ? "10" : "20"

      # oh so special format that xcc needs to send
      body = "0#{file.lstat.size}\r\n#{file.read}#{flag}\r\n"
    end

    def prep_buffer(buffer, commit)
      #flag that ML server is expecting
      flag = commit ? "10" : "20"

      # oh so special format that xcc needs to send
      body = "0#{buffer.length}\r\n#{buffer}#{flag}\r\n"      
    end

    def load_files(path, options)
      if (File.exists?(path))
        headers = {
          'Content-Type' => "text/xml",
          'Accept' => "text/html, text/xml, image/gif, image/jpeg, application/vnd.marklogic.sequence, application/vnd.marklogic.document, */*"
        }

        data = get_files(path, options)
        size = data.size

        @logger.info "Loading #{size} #{pluralize(size, "document", "documents")} from #{path} to #{@hostname}:#{@port}/#{options[:db]}"

        batch_commit = options[:batch_commit] == true
        @logger.debug "Using Batch commit: #{batch_commit}"
        data.each_with_index do |d, i|
          commit = ((false == batch_commit) || (i >= (size - 1)))

          file_uri = d
          url = build_load_uri(file_uri, options, commit)
          @logger.debug "loading: #{file_uri}"

          r = go url, "put", headers, nil, prep_body(d, commit)
          if (r.code.to_i != 200)
            @logger.error(r.body)
          end
        end
      else
        @logger.error "#{path} does not exist"
      end
    end

    def load_buffer(uri, buffer, options)
      headers = {
        'Content-Type' => "text/xml",
        'Accept' => "text/html, text/xml, image/gif, image/jpeg, application/vnd.marklogic.sequence, application/vnd.marklogic.document, */*"
      }

      url = build_load_uri(uri, options, true)
      @logger.debug "loading: #{uri}"

      r = go url, "put", headers, nil, prep_buffer(buffer, true)
      if (r.code.to_i != 200)
        @logger.error(r.body)
      end
    end

    def pluralize(count, singular, plural = nil)
      ((count == 1 || count =~ /^1(\.0+)?$/) ? singular : plural)
    end

  end
end