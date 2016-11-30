require 'sinatra'
require 'erb'
require 'csv'
require 'json'
#require 'fastercsv'
require 'hasherize_csv'

set :port, 8888
set :static, true
set :public_folder, "/"
set :views, "views"
set :public, "views"

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

get '/' do
  "DUMMY STUB - use the service :)"
end

get '/getChartFromCsv' do

  @csv_file_path=params[:csv_file_path] || ""
  @treshhold_ms = params[:treshhold_ms] || "0"
  return "Please specify valid path for CSV file" if (@csv_file_path.nil? || @csv_file_path.to_s.empty?)

  @csvHeaders = nil
  @csvData = getJsonArrFromCsv(@csv_file_path) || nil
  return "CSV file DOESNT contain valid data " if (@csvData.nil? || @csvData.empty?)

  erb :index
end


def getJsonArrFromCsv(filePath)
  $csv_hash_arr =[]
  begin
    @f = File.new(filePath)
    @csv = HasherizeCsv::Csv.new(@f)
    @csv.each do |hash|
      $csv_hash_arr << hash
    end
    @csvHeaders = $csv_hash_arr[0].keys
  rescue Exception => e
    #puts e.message #ToDo Logger
    return nil #$csv_hash_arr
  ensure
  end

  @timestamp_axis = [] #id - 1st Column in CSV,2  - date logTimeStamp  - id,date are MANDATORY headers in csv,the rest are msMetrics
  @latency_arr_hashes = []
  x_axis=0
  start=1
  last=$csv_hash_arr[0].keys.length-1

  while(start<=last)
    if start==1
      tmp_arr=$csv_hash_arr.collect{|e| e[$csv_hash_arr[0].keys[0]]}
      #tmp_arr=$csv_hash_arr.collect{|e| e[$csv_hash_arr[0].keys[0]]}.sort{|a,b| a <=> b   } #Sort ascending a <=> b || (a && 1) || -1
      tmp_arr.sort!{|a,b| a.to_i <=> b.to_i } #byID
      @timestamp_axis=tmp_arr
    end
    start+=1 if(start==1 || start==2) #id-for x plot axis,date-for display in popup/list
    tmp_arr=$csv_hash_arr.collect{|e| e[$csv_hash_arr[0].keys[start]] }
    tmp_arr.delete_if {|e| e.nil? || !e.is_number?}
    #tmp_arr=$csv_hash_arr.collect{|e| e[$csv_hash_arr[0].keys[start]] }.sort {|a,b| b <=> a } #Sort descending b <=> a b <=> a || (b && 1) || -1
    tmp_arr.sort! {|a,b| b.to_f <=> a.to_f } #byDeltaMS
    arr_name = $csv_hash_arr[0].keys[start]
    tmp_hash_values = Hash.new(arr_name+"_values")
    tmp_hash_times = Hash.new(arr_name+"_times")
    length = tmp_arr.length-1
    tmp_hash_values = {"100%"=>tmp_arr.first, "99.9%"=>tmp_arr[(tmp_arr.length-length*0.999).to_i], "99.8%"=>tmp_arr[(tmp_arr.length-length*0.998).to_i], "99.5%"=>tmp_arr[(tmp_arr.length-length*0.995).to_i] , "99%"=>tmp_arr[(tmp_arr.length-length*0.99).to_i], "95%"=>tmp_arr[(tmp_arr.length-length*0.95).to_i]}
    @latency_arr_hashes.push({arr_name=>tmp_hash_values})

    start+=1
  end

  return @latency_arr_hashes if(@latency_arr_hashes.nil? || @latency_arr_hashes.empty?)
  @latency_tables="<table>"
  #Headers
    col=@latency_arr_hashes[0].keys[0]
    rows=@latency_arr_hashes[0][col]
    @latency_tables+="<tr><th><font color='black'>Type</font></th>"
    rows.keys.each{ |k|  @latency_tables+="<th> #{k.to_s}	</th>"  }
    @latency_tables+="</tr>"


  #Columns
  @latency_arr_hashes.each_with_index{|name,index|
    col=@latency_arr_hashes[index].keys[0]
    rows=@latency_arr_hashes[index][col]

    @latency_tables+="<tr>"
    @latency_tables+="<td><b>#{col}</b></td>"
    rows.values.each_with_index { |v,k|
        color="black"
        v.to_f>@treshhold_ms.to_f && @treshhold_ms.to_f>0 ? color="red" : color="green"
        @latency_tables+='<td alt="Click for details..." onclick="'+"getChartSortedByColumnLatency(chartData,'"+col+"',"+rows.keys[k].to_s.gsub('%','')+')";'"><font color=#{color}> #{v.to_s}ms	<font></td>"
    }
    @latency_tables+="</tr>"

  }
  @latency_tables+="</table>"

  return $csv_hash_arr if $csv_hash_arr.empty?
  return $csv_hash_arr.to_json
end


__END__
The current time is <%= @time %>.