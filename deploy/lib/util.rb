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

def get_files(path, options = {}, data = [])
  ignore_extensions = ['..', '.', '.svn', '.git', '.ds_store', 'thumbs.db']

  if File.directory?(path)
    Dir.foreach(path) do |entry|
      next if ignore_extensions.include?(entry.downcase)
      full_path = File.join(path, entry)
      skip = false

      options[:ignore_list].each do |ignore|
        if full_path.match(ignore)
          skip = true
          break
        end
      end if options[:ignore_list]

      next if skip == true

      if File.directory?(full_path)
        get_files(full_path, options, data)
      else
        data << full_path.encode("UTF-8")
      end
    end
  else
    data = [path.encode("UTF-8")]
  end
  data
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
    REXML::Text::normalize(self)
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

def parse_multipart(body)
  if (body.match("^\r\n--"))
    # Extract the delimiter from the response.
    delimiter = body.split("\r\n")[1].strip
    parts = body.split(delimiter)

    # The first part will always be an empty string. Just remove it.
    parts.shift
    # The last part will be the "--". Just remove it.
    parts.pop

    # Get rid of part headers
    # TODO: I think this is broken (DMC)
    # This line is intended to just drop the zeroth item, but actually only
    # keeps the index=1 item. Anything after that gets lost, which is bad if
    # the file has \r\n for line separators. Need to verify that this is a
    # problem and fix if so. See save_files_to_fs MarkLogic 8 section for an
    # alternative approach.

    parts = parts.map{ |part| part.split("\r\n\r\n")[1].strip }

    # Return all parts as one long string, like we were used to.
    return parts.join("\n")
  else
    return body
  end
end

def parse_body(body)
  parse_multipart(parse_json(body))
end

def find_jar(jarname, jarpath = "../java/")
  matches = Dir.glob(ServerConfig.expand_path("#{jarpath}*#{jarname}*.jar"))
  raise "Missing #{jarname} jar." if matches.length == 0
  matches[0]
end
