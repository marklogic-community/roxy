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

def pluralize(count, singular, plural = nil)
  count == 1 || count =~ /^1(\.0+)?$/ ? singular : plural
end

def is_windows?
  (Config::CONFIG['host_os'] =~ /mswin|mingw/).nil? == false
end

def path_separator
	is_windows? ? ";" : ":"
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
end