#!/usr/bin/ruby

class Object
  def optional_require(feature)
    begin
      require feature
    rescue LoadError
    end
  end
end

begin
  optional_require 'open-uri'
  optional_require 'rubygems'
  optional_require 'nokogiri'

  def howto
    search = ARGV.first
#    doc = Nokogiri::HTML(open('https://github.com/marklogic/roxy/wiki/_pages'))
    doc = Nokogiri::HTML(open('http://localhost:8765/show-request.xqy', http_basic_authentication: ['admin', 'admin']))

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
        exit
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
  end

  howto

#rescue LoadError => e
#  puts "Missing library: #{e}"
rescue NameError => e
  puts "Missing library: #{e}"
end
