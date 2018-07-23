#!/usr/bin/ruby
require 'json'
require 'pry'

# 8AP2CyblNwx14SY2TBhqpPBA81jtclusNMNAjUIc
# curl -u 8AP2CyblNwx14SY2TBhqpPBA81jtclusNMNAjUIc:X -k https://bibles.org/v2/versions.js

begin

  rs_raw = `curl -s -u 8AP2CyblNwx14SY2TBhqpPBA81jtclusNMNAjUIc:X -k https://bibles.org/v2/versions.js`
  rs_hash = JSON.parse rs_raw
  
  #puts JSON.pretty_generate(rs_hash)
  rs_hash.each do |element|
    first_hash = element[1]
    versions = first_hash['versions']
    versions.each do |version|
      puts "#{version['id']}: #{version['lang_name_eng']}"
    end
  end
  
rescue => ex
  puts ex.message
  puts ex.backtrace
end