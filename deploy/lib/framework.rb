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

module Roxy
  class Framework

    attr_reader :logger

    def initialize(options)
      @logger = options[:logger]
      @src_dir = options[:properties]["ml.xquery.dir"]
      @test_dir = options[:properties]["ml.xquery-test.dir"]

      @is_jar = is_jar?

      if (@is_jar)
        @template_base = 'roxy/lib/templates'
      else
        @template_base = File.expand_path('../templates', __FILE__)
      end
      
      @no_prompt = options[:no_prompt]
    end

    def create
      create_what = ARGV.shift

      case create_what
      when "model"
        str = ARGV.shift
        if str
          model, function = str.split('/')
          create_object('model', model, function, ARGV.shift || model)
        else
          Help.doHelp(logger, "create")
        end
      when "test"
        if str = ARGV.shift
          suite, test = str.split('/')
          create_suite(suite, test) if suite != nil
        else
          Help.doHelp(logger, "create")
        end
      when "layout"
        layout = ARGV.shift
        format = ARGV.shift || "html"

        if !layout.nil?
          create_layout(layout, format)
        else
          Help.doHelp(logger, "create")
        end
      when nil
        Help.doHelp(logger, "create")
      else
        force = find_arg(['-f']) != nil
        controller, view = create_what.split('/')
        view = view || "main"
        format = ARGV.shift || "html"
        logger.debug "controller: #{controller}\nview: #{view}\n\nformat: #{format}\n"

        if !(controller.nil? || view.nil?)
          if force == false
            view_type = (format != nil && format != "none") ? ((format == "json") ? "a" : "an") + " #{format} view" : "no view"
            print "\nAbout to create a #{view}() function in the #{controller}.xqy controller with #{view_type}. Proceed?\n> "
            if @no_prompt
              raise ExitException.new("--no-prompt parameter prevents prompting for input. Use -f to force.")
            else
              answer = STDIN.gets.downcase.strip
              return if answer != "y" && answer != "yes"
            end
          end

          create_object('controller', controller, view, controller)
          create_view(controller, view, format) unless format == nil || format == "none"
        end
      end
    end

    def create_object(type, namespace, function, target_filename)
      target_file_path = File.expand_path("#{@src_dir}/app/#{type}s/#{target_filename}.xqy", __FILE__)

      if File.exists?(target_file_path)
        if (function != nil)
          target_file = File.read(target_file_path)

          if (target_file.index("#{type[0]}:#{function}(") != nil)
            logger.warn "Function #{namespace}:#{function}() already exists. Skipping..."
            return
          end
        else
          logger.warn "#{type} #{namespace} already exists. Skipping..."
          return
        end
      else
        target_file = read_file(@template_base + "/#{type}.xqy")
        target_file.gsub!("##{type}-name", namespace)
      end

      if !function.nil?
        target_file << read_file(@template_base + "/#{type}-function.xqy")
        target_file.gsub!("#function-name", function)
      end

      File.open(target_file_path, 'w') { |f| f.write(target_file) }
    end

    def create_suite(suite, test)
      suite_dir = File.expand_path("#{@test_dir}/suites/#{suite}/", __FILE__)
      Dir.mkdir(suite_dir) unless File.directory? suite_dir

      if test
        target_file = "#{suite_dir}/#{test}.xqy"

        if File.exists? target_file
          logger.warn "Test #{test} already exists. Skipping..."
          return
        end

        File.open(target_file, 'a') {|f| f.write(read_file(@template_base + '/test.xqy')) }
      end
    end

    def create_layout(layout, format)
      layout_dir = File.expand_path("#{@src_dir}/app/views/layouts/", __FILE__)
      Dir.mkdir(layout_dir) unless File.directory? layout_dir

      target_file = "#{layout_dir}/#{layout}.#{format}.xqy"

      layout_file = nil
      if File.exists? target_file
        logger.warn "Layout #{layout}.#{format} already exists. Skipping..."
        return
      end

      layout_file = @template_base + "/layout.#{format}.xqy"
      layout_file = @template_base + "/layout.xqy" unless file_exists?(layout_file)

      File.open(target_file, 'a') {|f| f.write(read_file(layout_file)) }
    end

    def create_view(controller, view, format)
      dir = File.expand_path("#{@src_dir}/app/views/#{controller}/", __FILE__)
      Dir.mkdir(dir) unless File.directory? dir

      out_file = "#{dir}/#{view}.#{format}.xqy"

      template_file = @template_base + "/view.#{format}.xqy"
      template_file = @template_base + "/view.xqy" unless file_exists?(template_file)

      if File.exists?(out_file) == false
        view_template = read_file(template_file)
        view_template.gsub!("#location", out_file)
        view_template.gsub!("#controller", controller)
        view_template.gsub!("#view", view)
        File.open(out_file, 'w') {|f| f.write(view_template) }
      else
        logger.warn "View #{out_file} already exists. Skipping..."
      end
    end
  end
end