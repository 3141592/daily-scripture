#!/usr/bin/ruby
require 'pry'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'erb'
require 'yaml'
require 'date'

class Verse
  attr_accessor :number, :text

  def initialize params = {}
    params.each { |key, value| send "#{key}=", value }
  end

  def print
    return "#{@number} #{@text}"
  end
end

class Scripture
  attr_accessor :template, :reference, :book, :verses, :date, :number, :vol, :curl

  def initialize params = {}
    @verses = []
    params.each { |key, value| send "#{key}=", value }
  end

  def render
    ERB.new(@template, 0, '>').result(binding)
  rescue => ex
    binding.pry
  end

  def save(file)
	file = File.open(file, "w")
    file.write(render.gsub('\n',''))
  rescue => ex
    binding.pry
  ensure
   file.flush
   file.close unless file.nil?
  end

  def print
    puts @book
    @verses.each do |verse|
      puts "#{verse.number} #{verse.text}"
    end
  end

end

def main
  @scriptures = []
  references =
  ['Leviticus 26:3-13',
   'Psalms 39:4-5',
   'Titus 3:4-7',
   'Philemon 1:6',
   'Hebrews 1:1-2']

  cleanup_previous_files
  references = read_references

  references.each do |ref|
    #binding.pry
    ascii_ref = ref['reference'].encode("UTF-8", "Windows-1252")
    doc = get_scripture_doc(ascii_ref)
    @scriptures << create_scripture(ref, doc)
    #sleep(3)
  end

  @scriptures.each_with_index do |scripture, index|
    create_html_email(scripture, index)
  end

  @scriptures.each_with_index do |scripture, index|
    list_references(scripture, index)
    open("DailyScripture.#{Time.now.strftime("%Y.%m.%d")}.txt", 'a') {|f|
      f.puts
    }
  end

  @scriptures.each_with_index do |scripture, index|
    create_facebook_posts(scripture, index)
  end

  @scriptures.each_with_index do |scripture, index|
    create_website_posts(scripture, index)
  end

rescue => ex
  puts ex.message
  puts ex.backtrace
end

def cleanup_previous_files
  filename = "DailyScripture.#{Time.now.strftime("%Y.%m.%d")}.txt"
  if File.file?(filename)
    FileUtils.rm filename, :verbose => true
  end
  Dir.glob('*.html').each do |file|
    FileUtils.rm file, :verbose => true
  end
end

def read_references
  references_yaml = YAML.load_file('references.yml')
end

def get_scripture_doc(reference)
  page = String.new
  #url = URI.parse("http://api.preachingcentral.com/bible.php?passage=#{reference}&version=eng-NASB")
  url = URI.parse("http://api.preachingcentral.com/bible.php?passage=#{reference}")
  puts url
  req = Net::HTTP::Get.new(url.to_s)
  res = Net::HTTP.start(url.host, url.port) {|http|
    http.request(req)
  }
  #binding.pry
  #puts "Subject: Daily Scripture-#{Date.today.strftime('%B %d, %Y')}-Vol 5 Num 264"
  doc = Nokogiri::XML(res.body)
rescue => ex

end

def create_scripture(ref, doc)
  scripture = Scripture.new
  scripture.curl = "curl -s http://api.preachingcentral.com/bible.php?passage=#{ref['reference']}&version=nasb"
  scripture.reference = ref['reference']
  scripture.book = scripture.reference.split(' ')[0]
  scripture.date = ref['date']
  scripture.number = Date.parse(scripture.date).yday()
  scripture.vol = ref['vol']

  verse = Verse.new
  #return
  result = []
  doc.traverse {|node| result << node }

  result.each do |item|
    if item.name == 'item' and item.children.count == 9
      item.children.each do |child|
        #binding.pry
        if child.name == 'verse'
          verse = Verse.new
          verse.number = child.text
        elsif child.name = 'text' and child.type == 1 and !scripture.reference.include?(child.text)
          verse.text = child.text
          verse.text.gsub!(/\A"|"\Z/, '') unless verse.text.nil?
          verse.text.gsub!(/\A'|'\Z/, '') unless verse.text.nil?
          #binding.pry
          scripture.verses << verse
        end
      end
    end
  end
  return scripture
end

def create_html_email(scripture, index)
  # Fill in the template
  template_string = IO.read("email.erb")
  scripture.template = template_string
  #binding.pry
  # Daily Scripture-Leviticus 26:3-13
  scripture.save("#{scripture.date.gsub(" ","-").gsub(",","-")}-DailyScripture-#{scripture.reference.gsub(' ','-').gsub(":","-")}.html")
rescue => ex
  puts ex.message
  puts ex.backtrace
end

def list_references(scripture, index)
  open("DailyScripture.#{Time.now.strftime("%Y.%m.%d")}.txt", 'a') {|f|
    #f.print scripture.reference + " (NASB)"
	f.print scripture.reference
    f.puts "," + scripture.date
  }
end

def create_facebook_posts(scripture, index)
  open("DailyScripture.#{Time.now.strftime("%Y.%m.%d")}.txt", 'a') {|f|
    f.puts "Facebook Post #{scripture.date}"
    f.puts
    scripture.verses.each do |verse|
      f.puts verse.print
    end
    f.puts
    #f.puts scripture.reference + " (NASB)"
	f.puts scripture.reference
    f.puts
    f.puts "="*80
  }
end

def create_website_posts(scripture, index)
  open("DailyScripture.#{Time.now.strftime("%Y.%m.%d")}.txt", 'a') {|f|
    f.puts "Website Post #{scripture.date}"
    f.puts
    f.puts "Daily Scripture - #{scripture.reference}"
    scripture.verses.each do |verse|
      f.puts verse.print
    end
    f.puts
    f.puts scripture.reference
    f.puts
    f.puts "="*80
  }
end

main
