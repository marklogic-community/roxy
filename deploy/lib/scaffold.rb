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

require 'fileutils'

module Roxy
  class Scaffold

    attr_reader :logger

    def initialize(options)
      @logger = options[:logger]
      @rest_ext_dir = options[:properties]["ml.rest-ext.dir"]
      @rest_trans_dir = options[:properties]["ml.rest-transforms.dir"]
    end

    def extend(resource)
      raise HelpException.new("extend", "Missing resource name") unless resource

      prefix = "ext"
      if resource.match(':')
        parts = resource.split(':')
        prefix = parts[0]
        resource = parts[1]
      end

      puts "Creating REST service extension #{resource} with prefix #{prefix} in #{@rest_ext_dir}\n"

      sample_ext = File.expand_path("../../sample/rest-ext.sample.xqy", __FILE__)
      ext = File.read sample_ext
      ext.gsub!(/(http:\/\/marklogic.com\/rest-api\/resource\/)extension/, "\\1#{resource}")
      ext.gsub!(/yourNSAlias/, prefix)

      # Create the rest extension directory if it doesn't already exist
      FileUtils.mkdir_p "#{@rest_ext_dir}"
      # Create the extension
      new_ext = File.expand_path("#{@rest_ext_dir}/#{resource}.xqy", __FILE__)

      open(new_ext, 'w') {|f| f.write(ext) }

    end

    def transform(transform, type = nil)
      raise HelpException.new("extend", "Missing resource name") unless transform
      if type == nil
        type = 'xslt'
      end
      if type != 'xslt' && type != 'xqy'
        Help.doHelp(@logger, 'transform')
        return
      end

      prefix = nil
      if transform.match(':')
        parts = transform.split(':')
        prefix = parts[0]
        transform = parts[1]
      end

      puts "Creating REST transformation #{transform} of type #{type} in #{@rest_trans_dir}\n"

      sample_trans = File.expand_path("../../sample/rest-transform.sample.#{type}", __FILE__)
      trans = File.read sample_trans

      trans.gsub!(/(http:\/\/marklogic.com\/rest-api\/transform\/)sample/, "\\1#{transform}")
      if prefix != nil
        trans.gsub!(/trns/, prefix)
      end

      # Create the rest extension directory if it doesn't already exist
      FileUtils.mkdir_p "#{@rest_trans_dir}"
      # Create the extension
      new_trans = File.expand_path("#{@rest_trans_dir}/#{transform}.#{type}", __FILE__)

      open(new_trans, 'w') {|f| f.write(trans) }

    end

  end
end