require 'webrick'

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
end

server = WEBrick::HTTPServer.new(:Port => PORT)
server.mount "/getKvFile", WebForm
server.mount "/saveKvFile", WebForm
trap("INT"){  server.shutdown }
server.start

