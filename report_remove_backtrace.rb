=begin
require 'nokogiri'

arg1 = ARGV[0]
fail('Error: WORKSPACE and BUILD_NUMBER arguments not given') if(arg1.to_s.empty?)
puts 'Arg1: '+arg1.to_s

arg2 = ARGV[1]
fail('Error: BUILD_NUMBER argument not given') if(arg2.to_s.empty?)
puts 'Arg2: '+arg2.to_s

dirTarget = arg1.to_s[0...-9]+'builds'+'\\'+arg2.to_s+'\htmlreports\HTML_Report'

localPath=dirTarget+'\report.html'
localPathOrig=dirTarget+'\report_orig.html'
localPathUpdated=localPath

puts 'Opening web page "'+localPath+'"'

pageOpened=''
begin

  pageOpened = Nokogiri::HTML(open(localPath))
  # puts 'pageOpened.class --> '+pageOpened.class.to_s # => Nokogiri::HTML::Document

rescue Exception=>e
  fail('Error: cannot open file "'+localPath+'"')
end

sleep 1

puts 'Saving original web page as "'+localPathOrig+'"'

begin
  File.open(localPathOrig, 'w') { |file|
    file.write(pageOpened.to_html)
  }
rescue Exception=>e
  fail('Error while writing to file "'+localPathOrig+'"')
end

cssToRemove1='div.backtrace'
cssToRemove2='pre.ruby'

puts 'Removing css elements "'+cssToRemove1+'", "'+cssToRemove2+'"'

begin
  pageOpened.css(cssToRemove1).remove
  pageOpened.css(cssToRemove2).remove
rescue Exception=>e
  fail('Error: cannot execute JS on the web page')
end

sleep 1

puts 'Saving updated web page as "'+localPathUpdated+'"'

begin
  File.open(localPathUpdated, 'w') { |file|
    file.write(pageOpened.to_html)
  }
rescue Exception=>e
  fail('Error while writing to file "'+localPathUpdated+'"')
end
=end