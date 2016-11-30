require 'webrick'
#require 'sinatra'
#require 'erb'
#require 'csv'
#require 'json'
#require 'fastercsv'
##require 'hasherize_csv'


#set :port, 8888
=begin
set :static, true
#set :public_folder, "static"
set :public_folder, "/"
set :views, "views"
set :public, "views"
=end

class String
  def to_bool
    return true if self == true || self =~ (/^(true|t|yes|y|1)$/i)
    return false if self == false || self =~ (/^(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end


class Object
  def is_number?
    self.to_f.to_s == self.to_s || self.to_i.to_s == self.to_s
  end
end

class Object
  def even?
    self%1==0 && self.to_i.even?
  end
end


SEPARATOR=","
PORT = 8888
RESTART_BATCH_PATH = "C:\restartApp.bat"

=begin
get '/' do
  "DUMMY STUB - use the service :)"
end

get '/getKvProps' do
  @kv_file_path=params[:kv_file_path] || ""
  return "Please specify valid path for KV file" if (@kv_file_path.nil? || @kv_file_path.to_s.empty?)


  @kvData = parseKvFile(@kv_file_path) || nil
  return "KV file DOESNT contain valid data " if (@kvData.nil? || @kvData.empty?)

  erb :kv
end


post "/setKv" do
  #params.to_s
  #erb :postkv
  "Posted!"
end
=end



def getKvFile(filePath)
  data = {}
  form_header = """
  <form method='POST' action='/saveKvFile'>
  <table>
  <tr> <input type='hidden' name='kv_file_path' value='#{filePath}'> </tr>
  <tr> <td>Restart</td> <td><select  name='restart'><option value='True'>True</option><option value='False'>False</option> </select></td></tr>
  """
  form_body=""
  form_footer = """
      <tr><td colspan=2 align='center'><input type='submit'></td></tr>
  </table>
  </form>
  """


  begin
    file=File.open(filePath)
    file.readlines.each_with_index do |line,index|
      kv=line.gsub("\n","").split("=")
      data[kv[0]] = (kv[1].nil? || kv[1].empty? ? "NOT_SET" : kv[1].to_s) if !kv.nil? && !kv[0].nil?
      #data[kv[0]] = kv[1] if !kv.nil? && !kv[0].nil? && !kv[1].nil?

    end
  rescue Exception => e
    raise("IO error " + filePath + ' ' +e.backtrace.to_s)
  end


  @response = nil
  if(data.length>0)
    data.each{|k,v|
      form_body += "<tr><td> #{k.to_s} </td> <td> <input type='text' name='#{k.to_s.strip}' value=' #{v.nil? ? "" : v.to_s.strip} ' > </td></tr>"
    }
    @response=form_header+form_body+form_footer
  else
    @response = "NO DATA !!!"
  end

  return @response
end


#http://localhost:8888/getKvFile?kv_file_path=c:/kv.properties
#https://www.igvita.com/2007/02/13/building-dynamic-webrick-servers-in-ruby/
class WebForm < WEBrick::HTTPServlet::AbstractServlet

  def do_GET(request,response)
    kv_file_path = request.query['kv_file_path']
    if(kv_file_path.nil? || kv_file_path.empty?)
      response.status = 404
      response['Content-Type'] = "text/html"
      response.body = "NO DATA !!! - pls. insert valid KV file path"
    else
      content = getKvFile(kv_file_path)
      response.status = 200
      response['Content-Type'] = "text/html"
      response.body = content
    end
  end


  # Process the request, return response
  def do_POST(request, response)
=begin
    status, content_type, body = print_questions(request)
    response.status = status
    response['Content-Type'] = content_type
    response.body = body
=end

  new_data = ""
  request.query.each{|k,v| new_data+=k.to_s.strip+'='+(v.nil? || v.empty? ? "NOT_SET" : v.to_s.strip) + "\n" if k!="kv_file_path"  && k!="restart"}
  begin

    restart = request.query['restart'].to_bool
    kv_file_path = request.query['kv_file_path']
    File.write(kv_file_path,new_data) if(!new_data.nil? && !new_data.empty?)
    response_str = "#{kv_file_path} updated !"
    if(restart)
      response_str << " + Going to restart #{RESTART_BATCH_PATH.inspect}"
      #system(RESTART_BATCH_PATH)
    end
    response.body = response_str
  rescue Exception=>e
    raise "ERROR - onSaveFile " +kv_file_path+ ' ' + e.backtrace.to_s if(!e.backtrace.nil?)
  end

  end

  # Construct the return HTML page
  def print_questions(request)
    html   = "<html><body><form method='POST' action='/saveKvFile'>"
    html += "Name: <input type='textbox' name='first_name' /><br /><br />";

    #dbh = DBI.connect("DBI:Mysql:webarchive:localhost", "root", "pass")
    #sth = dbh.execute("SELECT headline, story, id FROM yahoo_news where date >= '2004-12-01' and date <= '2005-01-01'")

    # iterate over every returned news-story from the database
=begin
    while row = sth.fetch_hash do
      html += "<b>#{row['headline']}</b><br />\n"
      html += "#{row['story']}<br />\n"
      html += "<input type='textbox' name='#{row['id']}' /><br /><br />\n"
    end
=end
    #sth.finish

    html += "<input type='submit'></form></body></html>"

    # Return OK (200), content-type: text/html, followed by the HTML itself
    return 200, "text/html", html
  end
end

server = WEBrick::HTTPServer.new(:Port => PORT)
server.mount "/getKvFile", WebForm
server.mount "/saveKvFile", WebForm
trap("INT"){  server.shutdown }
server.start





#http://localhost:8888/getKvProps?kv_file_path=c:/kv.properties
def parseKvFile(filePath)
  #system("c:/test.bat")

  #fork { exec 'sleep 60' } # you see a new process in top, "sleep", but no extra ruby process.
  #exec 'echo hi' # prints 'hi'
  #`"C:\Documents and Settings\test.exe"`  or  `exec "C:\Documents and Settings\test.exe"`
  #spawn 'sleep 1; echo one'
  #io = IO.popen 'cat', 'r+'

=begin
  require 'open3'
  stdout,stderr,status = Open3.capture3('C:\Documents and Settings\test.exe','')
  stdout,stderr,status = Open3.capture3(some_command)
  STDERR.puts stderr
  if status.successful?
    puts stdout
  else
    STDERR.puts "OH NO!"
  end
=end


  data = {}
=begin
  form_header = """
  <form method="POST" action="/setKv">
  <table>
  """
  form_footer = """
      <tr><td colspan=2 align="center"><input type="submit"></td></tr>
  </table>
  </form>
  """
=end
  begin
    file=File.open(filePath)
    file.readlines.each_with_index do |line,index|
      kv=line.gsub("\n","").split("=")
      data[kv[0]] = kv[1] if !kv.nil? && !kv[0].nil? && !kv[1].nil?

    end
  rescue Exception => e
   raise("IO error " + filePath + ' ' +e.backtrace.to_s)
  end
  return data
end

=begin
require 'webrick'
include WEBrick
require 'erb'

s = HTTPServer.new( :Port => 8080,:DocumentRoot    => Dir::pwd + "/public" )

class MyServlet < HTTPServlet::AbstractServlet
  def do_GET(req, response)
    File.open('public/my.rhtml','r') do |f|
      @template = ERB.new(f.read)
    end
    response.body = @template.result(binding)
    response['Content-Type'] = "text/html"
  end
end

s.mount("/my", MyServlet)

trap("INT"){
  s.shutdown
}
s.start
=end


__END__
The current time is <%= @time %>.