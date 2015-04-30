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
require 'rbconfig'
require 'rexml/text'

def find_arg(args = [])
  args.each do |arg|
    ARGV.each do |a|
      if a == arg || a.match("^#{arg}=")
        index = ARGV.index(a)
        ARGV.slice!(index)

        return arg if a == arg

        if arg.match("^--")
          split = a.split '='
          return a.split("=")[1] if split.length == 2
          return arg
        end
      end
    end
  end
  nil
end

def load_prop_from_args(props)
  ARGV.each do |a|
    if a.match(/(^--)(ml\..*)(=)(.*)/)
      matches = a.match(/(^--)(ml\..*)(=)(.*)/).to_a
      ml_key = matches[2]
      ml_val = matches[4]
      if props.has_key?("#{ml_key}")
        props["#{ml_key}"] = ml_val
      else
        logger.warn "Property #{ml_key} does not exist. It will be skipped."
      end
    end
  end
  props
end

def pluralize(count, singular, plural = nil)
  count == 1 || count =~ /^1(\.0+)?$/ ? singular : plural
end

def is_windows?
  (RbConfig::CONFIG['host_os'] =~ /mswin|mingw/).nil? == false
end

def path_separator
	is_windows? ? ";" : ":"
end

def is_jar?
  __FILE__.match(/.*\.jar.*/) != nil
end

def copy_file(src, target)
  if is_jar?
    contents = read_file(src)
    File.open(target, "w") { |file| file.write(contents) }
  else
    FileUtils.cp(src, target)
  end
end

def read_file(filename)
  if is_jar?
    require 'java'
    stream = self.to_java.get_class.get_class_loader.get_resource_as_stream(filename)
    br = java.io.BufferedReader.new(java.io.InputStreamReader.new(stream))
    contents = ""
    while (line = br.read_line())
      contents = contents + line + "\n"
    end
    br.close()
    return contents
  else
    File.read(filename)
  end
end

def file_exists?(filename)
  if is_jar?
    require 'java'
    self.to_java.get_class.get_class_loader.get_resource_as_stream(filename) != nil
  else
    return File.exists?(filename)
  end
end

class String
  unless respond_to? :try
    def try(method)
      send method if respond_to? method
    end
  end

  def strip_heredoc
    indent = scan(/^[ \t]*(?=\S)/).min.try(:size) || 0
    gsub(/^[ \t]{#{indent}}/, '')
  end

  def xquery_safe
    REXML::Text::normalize(self).gsub(/\{/, '{{').gsub(/\}/, '}}')
  end

  def xquery_unsafe
    REXML::Text::unnormalize(self).gsub(/\{\{/, '{').gsub(/\}\}/, '}')
  end

end

class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def present?
    !blank?
  end

  def to_b
    present? && ['true', 'TRUE', 'yes', 'YES', 'y', 'Y', 't', 'T'].include?(self)
  end
  
  def optional_require(feature)
    begin
      require feature
    rescue LoadError
    end
  end
end

def parse_json(body)
  if (body.match('^\[\{"qid":'))
    items = []
    JSON.parse(body).each do |item|
      items.push item['result']
    end
    return items.join("\n")
  else
    return body
  end
end

def find_jar(jarname, jarpath = "../java/")
  matches = Dir.glob(ServerConfig.expand_path("#{jarpath}*#{jarname}*.jar"))
  raise "Missing #{jarname} jar." if matches.length == 0
  matches[0]
end
