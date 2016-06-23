require 'nokogiri'

#ruby C:\updateReport.rb C:\Users\ibershtein\sap-automation\sapphire-automation 120
#ruby C:\report_remove_backtrace.rb %WORKSPACE% %BUILD_NUMBER%
#ruby C:\report_remove_backtrace.rb C:\Jenkins\jobs\Sapphire-UI-Sanity\workspace 119
arg1 = ARGV[0]
if arg1.to_s.empty?
  abort('Error: WORKSPACE and BUILD_NUMBER arguments are empty')
end

puts 'Arg1 (WORKSPACE): '+arg1.to_s

arg2 = ARGV[1]
if arg1.to_s.empty?
  abort('Error: BUILD_NUMBER argument is empty')
end

puts 'Arg2 (BUILD_NUMBER): '+arg2.to_s

###JVM Reports Start
def removeBacktraceFromJvmReport(file_path)
  begin
    read_file = File.new(file_path, "r").read
    write_file = File.new(file_path, "w")

    read_file.each_line do |line|
      write_file.write(line) unless line.include?('./features')
    end
  rescue Exception=>e
    puts 'removeBacktraceFromJvmReport Exception: ' + e.message if !e.message.nil?
  end
end


def changeDomForFile(file_path,arrSelectorsToRemove)
  begin
	  removeBacktraceFromJvmReport(file_path)
  rescue Exception=>e
    puts 'Error: cannot removeBacktraceFromJvmReport from file "'+file_path+'"'
  end
  sleep 1

  pageOpened=''
  begin
    pageOpened = Nokogiri::HTML(open(file_path))
      # puts 'pageOpened.class --> '+pageOpened.class.to_s # => Nokogiri::HTML::Document
  rescue Exception=>e
    # fail('Error: cannot open file "'+file_path+'"')
    puts 'Error: cannot open file "'+file_path+'"'
  end
  sleep 1


  #puts 'Removing css elements "'+arrSelectorsToRemove.to_s+'"'
  begin
    arrSelectorsToRemove.each {|selector| pageOpened.css(selector).remove }
  rescue Exception=>e
    puts 'Error: cannot remove element on the web page'
  end
  sleep 1

  #puts 'Saving updated web page'
  begin
    File.open(file_path, 'w') { |file|  file.write(pageOpened.to_html) }
  rescue Exception=>e
    #fail('Error while writing to file "'+file_path+'"')
    puts 'Error while writing to file "'+file_path+'"'
  end
end


def refineJvmReport
  #dirTarget = ARGV[0].to_s[0...-9]+'builds'+'\\'+ARGV[1].to_s+'\cucumber-html-reports' if(ARGV[0].to_s.include?('Jenkins')) 
  dirTarget = ARGV[0].to_s.gsub('workspace','builds')+'\\'+ARGV[1].to_s+'\\cucumber-html-reports' if(ARGV[0].to_s.downcase.include?('jenkins'))
  dirTarget = ARGV[0].to_s+'\\'+ARGV[1].to_s+'\\cucumber-html-reports' if(!ARGV[0].to_s.downcase.include?('jenkins'))
  #dirTarget = Dir.getwd+'\reports\cucumber-html-reports'
  puts 'Parsing dir: '+dirTarget.to_s
  html_files = Dir.entries(dirTarget).select{|f| f.include?('html')}
  css_selectors = ['div.inner-level.hooks-before','div.inner-level.hooks-after','div.hook']
  html_files.each {|html_file| changeDomForFile(dirTarget+'/'+html_file,css_selectors)}
end

begin
  refineJvmReport
rescue Exception=>e
  puts 'refineJvmReport Error: ' +e.message if(!e.message.nil?)
  puts 'Stacktrace: ' + e.backtrace.to_s
end
###JVM Reports End


###HTML_Report start
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
  # fail('Error: cannot open file "'+localPath+'"')
  puts 'Error: cannot open file "'+localPath+'"'
end

sleep 1

puts 'Saving original web page as "'+localPathOrig+'"'

begin
  File.open(localPathOrig, 'w') { |file|
    file.write(pageOpened.to_html)
  }
rescue Exception=>e
  # fail('Error while writing to file "'+localPathOrig+'"')
  puts 'Error while writing to file "'+localPathOrig+'"'
end

cssToRemove1='div.backtrace'
cssToRemove2='pre.ruby'

puts 'Removing css elements "'+cssToRemove1+'", "'+cssToRemove2+'"'

begin
  pageOpened.css(cssToRemove1).remove
  pageOpened.css(cssToRemove2).remove
rescue Exception=>e
  # fail('Error: cannot execute JS on the web page')
  puts 'Error: cannot execute JS on the web page'
end

sleep 1

puts 'Saving updated web page as "'+localPathUpdated+'"'

begin
  File.open(localPathUpdated, 'w') { |file|
    file.write(pageOpened.to_html)
  }
rescue Exception=>e
  # fail('Error while writing to file "'+localPathUpdated+'"')
  puts 'Error while writing to file "'+localPathUpdated+'"'
end
###HTML_Report End

