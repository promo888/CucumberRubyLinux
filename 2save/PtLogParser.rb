#require 'cucumber'
#require 'net/ssh'
#require 'net/scp'
require 'time'
#require "hamster/hash"
#require 'fastercsv'
#require 'hasherize_csv'
#require 'csv_hasher'
require 'in_threads'
#require 'thread_storm'
#require 'thread'
#require 'ruby-prof'

$mutex = Mutex.new




#CORE & TIDY & DB
CORE_LOGS="pts_core*log"
TIDY_LOGS="pts_tidy*log"
CORE_ER_EVENT="PTS-C832"
TIDY_ER_EVENT="PTS-C607"
DB_EVENT="PTS-C550"
DB_EVENT_FX_DEAL_MSG="FX_DEAL"
DB_EVENT_FX_TICKET_LEG_MSG="FX_TICKET_LEG"

#ADAPTERS
TIDY_CSV_COMMON_EVENT="PTS-C601"
TIDY_CSV_COMMON_EVENT_MSG1="routed"
TIDY_CSV_COMMON_EVENT_MSG2="common"
TIDY_CSV_MYT_EVENT="PTS-C601"
TIDY_CSV_MYT_EVENT_MSG1="routed"
TIDY_CSV_MYT_EVENT_MSG2="myt"
TIDY_JSON_SAPPHIRE_EVENT="PTS-C601"                       #PTS-C650
TIDY_JSON_SAPPHIRE_MSG="routed by Persistent RedisSender" #"Message was successfully sent to redis"
TIDY_FIX4_4_EVENT="PTS-C7316"
TIDY_FIX4_4_EVENT_MSG="FIX44_ADAPTER"
TIDY_TUDOR_EVENT="PTS-C7316"
TIDY_TUDOR_EVENT_MSG="TUDOR_ADAPTER"
TIDY_RTNS_EVENT="PTS-C7316"
TIDY_RTNS_EVENT_MSG="RTNS"

CORE_ER_IN_EVENT = "PTS-C306"
CORE_ER_IN_EVENT_MSG1 = "Received MSL message" #Redundant
CORE_ER_IN_REGEX = "sequence=(\\d+)"
CORE_ER_OUT_EVENT = "PTS-C832"
CORE_ER_OUT_REGEX = " mid: (\\d+)"
TIDY_ER_IN_EVENT = "PTS-C306"
TIDY_ER_IN_EVENT_MSG1 = "Received MSL message" #Redundant
TIDY_ER_IN_REGEX  = "sequence=(\\d+)"
TIDY_ER_OUT_REGEX = " mid: (\\d+)"




$regex_time=0
def line_include?(str,search1_str,search2_str=nil,search3_str=nil,search4_str=nil,search5_str=nil)
  ###start_time=Time.now

  if !search1_str.nil? && !search2_str.nil? && !search3_str.nil? && !search4_str.nil? && !search5_str.nil?
    return str.downcase.include?(search1_str.downcase) && str.downcase.include?(search2_str.downcase) && str.downcase.include?(search3_str.downcase) && str.downcase.include?(search4_str.downcase) && str.downcase.include?(search5_str.downcase)
  end
  if !search1_str.nil? && !search2_str.nil? && !search3_str.nil? && !search4_str.nil?
    return str.downcase.include?(search1_str) && str.downcase.include?(search2_str.downcase) && str.downcase.include?(search3_str.downcase) && str.downcases.include?(search4_str.downcase)
  end
  if !search1_str.nil? && !search2_str.nil? && !search3_str.nil?
    return str.downcase.include?(search1_str.downcase) && str.downcase.include?(search2_str.downcase) && str.downcase.include?(search3_str.downcase)
  end
  if !search1_str.nil? && !search2_str.nil?
    return str.downcase.include?(search1_str.downcase) && str.downcase.include?(search2_str.downcase)
  end
  if !search1_str.nil?
    return true if str.downcase.include?(search1_str.downcase)
  end

  ###end_time=Time.now
  ###$regex_time+=(end_time-start_time)*1000

  return false
end

$core_parsed_rows_count = 0
$tidy_parsed_rows_count = 0
#$adapter_queue =  Queue.new
$adapter_data2 = {} #Hamster::Hash.new() #{}
$core_finished = false
$tidy_finished = false

def persistRemainder
  remainder_count = $adapter_data2["CORE_OUT_CORE"].length
  puts "Remainder #{remainder_count}"
  if !remainder_count.nil? && remainder_count > 0
    $ROWS_TO_PERSIST = remainder_count
    persistToFileRemainder()
  end
end

def parse_adapters2(search_in_dir,file_pattern,arrAdapters,logsId=0)
  files_sorted_by_time_asc = Dir[search_in_dir+"/"+file_pattern].sort_by{ |f| File.mtime(f) } #Dir['pts_core*']
  files_sorted_by_time_asc.each {|file_name|
      parseFilePartial(arrAdapters,file_name,logsId)
      #syncBlock(&parseFile(arrAdapters,file_name))
  }
  $core_finished = true if logsId == 0
  $tidy_finished = true if logsId == 1

=begin
  if( $core_parsed_rows_count > 0  && $tidy_finished)
    puts "--DEBUG4-- going to persist #{$core_parsed_rows_count.to_s} - core_parsed: " + $core_parsed_rows_count.to_s + " tidy_parsed: " + $tidy_parsed_rows_count.to_s
    $ROWS_TO_PERSIST = $tidy_parsed_rows_count #$core_parsed_rows_count #$tidy_parsed_rows_count
    persistToFilePartial()
    $core_parsed_rows_count-=$tidy_parsed_rows_count ##$core_parsed_rows_count #$tidy_parsed_rows_count #
    $tidy_parsed_rows_count-=$tidy_parsed_rows_count ##$core_parsed_rows_count #$tidy_parsed_rows_count
  end
  $ROWS_TO_PERSIST = $core_parsed_rows_count
=end
#persistToFilePartial()




end



def syncBlock(code)
=begin
  proc = Proc.new {code}
  proc.call
=end

  #ret = lambda { code }
  #ret.call

  #yield
end

def persistToFile
    #createPartialChartCsv
    #$adapter_data2 = {}
    createChartCsv
end

def persistToFilePartial
  $threads.each {|thr| thr.stop }
  #p = Thread.new {
  #$mutex.synchronize do
    createPartialChartCsv
    $adapter_data2.each{|adapter|
      current_adapter_size = $adapter_data2[adapter[0]].length
      rows_to_remove = $ROWS_TO_PERSIST > current_adapter_size ? $ROWS_TO_PERSIST-current_adapter_size : $ROWS_TO_PERSIST
      $adapter_data2[adapter[0]].slice!(0..rows_to_remove)

     # $adapter_data2[adapter[0]].delete_if.with_index{|element,index| index < $ROWS_TO_PERSIST && !element[:delta_ms].nil?}
    }
  #end
  #}
 # p.join
=begin
  Thread.list.each {|thr| p.transfer }
=end
  $threads.each {|thr| thr.resume }

end

def persistToFileRemainder
  #$mutex.synchronize do
    createPartialChartCsv
    $adapter_data2.each{|adapter|
      current_adapter_size = $adapter_data2[adapter[0]].length
      rows_to_remove = $ROWS_TO_PERSIST > current_adapter_size ? $ROWS_TO_PERSIST-current_adapter_size : $ROWS_TO_PERSIST
      $adapter_data2[adapter[0]].slice!(0..rows_to_remove)

      #$adapter_data2[adapter[0]].delete_if.with_index{|element,index| index < $ROWS_TO_PERSIST && !element[:delta_ms].nil?}
    }
   # end
end

$ROWS_TO_PERSIST = 10000
def parseFilePartial(arrAdapters,file_name,counterId=0)
  begin
    file=File.open(file_name)
    file.readlines.each_with_index do |line,index|
      arrAdapters.each_with_index {|adapter,i|
        $adapter_data2[adapter[:adapter_label]]=[] if $adapter_data2[adapter[:adapter_label]].nil? #Array impl
        #$adapter_data2[adapter[:adapter_label]]={} if $adapter_data2[adapter[:adapter_label]].nil? #Hash impl
        #$adapter_data2.put(adapter[:adapter_label],[]) #Hamster::Hash.new []
        #next if(i >= $ROWS_TO_PERSIST)
        if line_include?(line,adapter[:event],adapter[:search2_str],adapter[:search3_str],adapter[:search4_str])
          begin
            id=line.scan(/#{adapter[:regex_id]}/)[0][0]
          rescue
            next if id.nil?
          end

          time = line.split[0]+' '+line.split[1]
          last_index = $adapter_data2[adapter[:adapter_label]].length
          count = last_index + 1

          $adapter_data2[adapter[:adapter_label]].push({:id => count,:date => time, :ticket_id => id}) #Array impl

          $core_parsed_rows_count+=1 if counterId==1 && adapter[:adapter_label]==arrAdapters.last[:adapter_label]
          $tidy_parsed_rows_count+=1 if counterId==2 && adapter[:adapter_label]==arrAdapters.last[:adapter_label]


        end
      }



     if( $core_parsed_rows_count >= $ROWS_TO_PERSIST && $tidy_parsed_rows_count >= $ROWS_TO_PERSIST && !$core_finished && !$tidy_finished )
        puts "--DEBUG1-- going to persist 1000 - core_parsed: " + $core_parsed_rows_count.to_s + " tidy_parsed: " + $tidy_parsed_rows_count.to_s
        persistToFilePartial #()
        #puts "--DEBUG1-- 1000 persisted - core_parsed: " + $core_parsed_rows_count.to_s + " tidy_parsed: " + $tidy_parsed_rows_count.to_s
        $core_parsed_rows_count-=$ROWS_TO_PERSIST
        $tidy_parsed_rows_count-=$ROWS_TO_PERSIST
     end

=begin
      if( $core_parsed_rows_count >= $ROWS_TO_PERSIST && $tidy_parsed_rows_count > 0 && !$core_finished  && $tidy_finished )
        puts "--DEBUG2-- going to persist 1000 - core_parsed: " + $core_parsed_rows_count.to_s + " tidy_parsed: " + $tidy_parsed_rows_count.to_s
        persistToFilePartial()
        #puts "--DEBUG2-- 1000 persisted - core_parsed: " + $core_parsed_rows_count.to_s + " tidy_parsed: " + $tidy_parsed_rows_count.to_s
        $core_parsed_rows_count-=$ROWS_TO_PERSIST
        $tidy_parsed_rows_count-=$ROWS_TO_PERSIST
      end

      if( $core_parsed_rows_count > 0  && $core_finished  && $tidy_finished)
        puts "--DEBUG3-- going to persist Remainder " #"#{$core_parsed_rows_count.to_s} - core_parsed: " + $core_parsed_rows_count.to_s + " tidy_parsed: " + $tidy_parsed_rows_count.to_s
        persistToFilePartial()
        #puts "--DEBUG3-- CORE_REMAINDER persisted - core_parsed: " + $core_parsed_rows_count.to_s + " tidy_parsed: " + $tidy_parsed_rows_count.to_s
        $core_parsed_rows_count-=$core_parsed_rows_count
        $tidy_parsed_rows_count-=$core_parsed_rows_count
      end
=end


    end

    puts " => " + file_name + " parsed "
=begin
    if(!$adapter_data2.empty?)
      createPartialCsv($adapter_data2)
      $adapter_data2 = {}
    end
=end
  rescue Exception => e
    raise("Exception in #{file_name} " + e.backtrace.to_s)
  ensure
    file.close
  end
  #puts "--finished parsing #{file_name} \n"
end


def parseFile(arrAdapters,file_name,counterId=0)
  begin
    file=File.open(file_name)
    file.readlines.each_with_index do |line,index|
      arrAdapters.each_with_index {|adapter,i|
        $adapter_data2[adapter[:adapter_label]]=[] if $adapter_data2[adapter[:adapter_label]].nil? #Array impl
        #$adapter_data2[adapter[:adapter_label]]={} if $adapter_data2[adapter[:adapter_label]].nil? #Hash impl
        #$adapter_data2.put(adapter[:adapter_label],[]) #Hamster::Hash.new []
        #next if(i >= $ROWS_TO_PERSIST)
        if line_include?(line,adapter[:event],adapter[:search2_str],adapter[:search3_str],adapter[:search4_str])
          begin
            id=line.scan(/#{adapter[:regex_id]}/)[0][0]
          rescue
            next if id.nil?
          end
          time = line.split[0]+' '+line.split[1]
          last_index = $adapter_data2[adapter[:adapter_label]].length
          count = last_index + 1

          $adapter_data2[adapter[:adapter_label]].push({:id => count,:date => time, :ticket_id => id}) #Array impl
          #$adapter_data2[adapter[:adapter_label]].store(count,{:id => count,:date => time, :ticket_id => id}) #Hash impl

          $core_parsed_rows_count+=1 if counterId==1 && adapter[:adapter_label]==arrAdapters.last[:adapter_label]
          $tidy_parsed_rows_count+=1 if counterId==2 && adapter[:adapter_label]==arrAdapters.last[:adapter_label]

          #$adapter_queue << {adapter[:adapter_label] => {:id => count,:date => time, :ticket_id => id}}

        end
      }

    end

    #puts " => " + file_name + " parsed "

  rescue Exception => e
    raise("Exception in #{file_name} " + e.backtrace.to_s)
  ensure
    file.close
  end
  puts "--finished parsing #{file_name} \n"
end

def addDeltas

  types = ["CORE", "TIDY"]
  incoming = $adapter_data2.keys.select { |v| v.upcase.include? "IN" }
  outgoing = $adapter_data2.keys.select { |v| v.upcase.include? "OUT" }

  types.each { |adapter_type|
    type_in = incoming.select { |v| v.include? adapter_type }
    type_out = outgoing.select { |v| v.include? adapter_type }
    next if type_in.nil? && type_in.length>0

    type_out.each_with_index { |v,i |
      matched_adapter_in = $adapter_data2[type_in[0]].each_with_index { |v2,i2 |
        i2<$adapter_data2[v].length && v2[:ticket_id] == $adapter_data2[v][i2][:ticket_id] #Array impl
      }

      $adapter_data2[v].each_with_index { |type, index|
        #Validation ToDo return error if $adapter_data2[outgoing][index][:ticket_id] != matched_adapter_in[index][:ticket_id]
        out_time = Time.strptime($adapter_data2[v][index][:date], "%d-%m-%y %H:%M:%S.%L")
        in_time = Time.strptime(matched_adapter_in[index][:date], "%d-%m-%y %H:%M:%S.%L")
        delta_ms = out_time - in_time
        $adapter_data2[v][index][:delta_ms] = delta_ms
      }
    }

  }
  return outgoing
end



def addDeltasPartial

  types = ["CORE", "TIDY"]
  incoming = $adapter_data2.keys.select { |v| v.upcase.include? "IN" }
  outgoing = $adapter_data2.keys.select { |v| v.upcase.include? "OUT" }

  types.each { |adapter_type|
    type_in = incoming.select { |v| v.include? adapter_type }
    type_out = outgoing.select { |v| v.include? adapter_type }
    next if ( (type_in.nil? && type_in.length>0) || (type_out.nil? && type_out.empty?) )


    type_out.each_with_index { |a_out|
      matched_adapter_in = $adapter_data2[type_in[0]].each_with_index { |a_in,i |
        #i < $ROWS_TO_PERSIST &&
          matched =  i < $adapter_data2[a_out].length && a_in[:ticket_id] == $adapter_data2[a_out][i][:ticket_id] #Array impl
          next if !matched

=begin
      intersection = $adapter_data2[type_in[0]].map{|inc| inc[:ticket_id]} & $adapter_data2[a_out].map{|outc| outc[:ticket_id]}
      matched_adapter_in_arr = $adapter_data2[type_in[0]].select {|t| intersection.include? t[:ticket_id] }
      #matched_adapter_out_arr = $adapter_data2[a_out].select {|t| intersection.include? t[:ticket_id] }
      #in_indexes = matched_adapter_in_arr.map{|t| t[:id].to_i}
      out_indexes = matched_adapter_in_arr.map{|t| t[:id].to_i}
=end

} #

      debug_count = 0
      $adapter_data2[a_out].each_with_index { |ticket, index|
      #matched_adapter_in_arr.each_with_index{|ticket,index|
        next if index >= $ROWS_TO_PERSIST
        #next if($adapter_data2[a_out][index].nil? || matched_adapter_in_arr[index].nil?)

        next if($adapter_data2[a_out][index].nil? || $adapter_data2[type_in[0]][index].nil?)
        out_time = Time.strptime(ticket[:date], "%d-%m-%y %H:%M:%S.%L")
        in_time = Time.strptime($adapter_data2[type_in[0]][index][:date], "%d-%m-%y %H:%M:%S.%L")

        #search_out_time = $adapter_data2[a_out].select{ |t|  t[:ticket_id] == ticket[:ticket_id]}[0]
=begin
        search_out_time = $adapter_data2[a_out][out_indexes[index]-1]
        out_time = Time.strptime(search_out_time[:date], "%d-%m-%y %H:%M:%S.%L") if !search_out_time.nil?
        in_time = Time.strptime(ticket[:date], "%d-%m-%y %H:%M:%S.%L")
=end

        delta_ms = out_time - in_time
        $adapter_data2[a_out][index][:delta_ms] = delta_ms if $adapter_data2[a_out][index][:delta_ms].nil? #if delta_ms > 0

        #current_ticket = $adapter_data2[a_out].select{ |t|  t[:ticket_id] == ticket[:ticket_id]}[0]
        ##$adapter_data2[a_out][out_indexes[index]-1][:delta_ms] =  out_time - in_time  if !ticket.nil? &&  !out_time.nil? && !in_time.nil?

        if delta_ms < 0
        puts "debug Negative"
        end


        debug_count+=1
      }
      puts "#{a_out} count - " + debug_count.to_s
    }

  }
  return outgoing
end



def getDeltaMs(in_hash,out_hash)
  out_time = Time.strptime(out_hash[:date], "%d-%m-%y %H:%M:%S.%L")
  in_time = Time.strptime(in_hash[:date], "%d-%m-%y %H:%M:%S.%L")
  delta_ms = out_time - in_time

  delta_ms
end

def createCsv(outgoing)
  max_tickets = -1
  $adapter_data2.each { |k, v| max_tickets = v.length if v.length > max_tickets && k.upcase.include?("OUT") }
  csv_name = Time.now().strftime('%d_%m_%Y-%H_%M_%S')+'.csv'
  csv_path = Dir.getwd+'/'+csv_name #TODO local if no argumentPath
  puts csv_path + ' file created'

  begin
    File.open(csv_path, "w")
    outgoing_names = $adapter_data2.keys.select { |v| v.upcase.include? "OUT" }
    new_outgoing_names = ["id", "date"]
    outgoing.each { |adapter_name| new_outgoing_names.push(adapter_name.gsub(/.*_OUT_/, "")) }
    headers = new_outgoing_names.join(",")


    count = 0
    arr_values = [] #[] #{}
    arr_values.push(headers)
    while (count < max_tickets)
      values = (count+1).to_s+"," #"TICKET_ID_WAITING_4KOGAN,"
      values << $adapter_data2["CORE_OUT_CORE"][count][:date] << "," #CORE IN Event Time #TODO change to execID or seqID
      outgoing_names.each { |adapter|
        values << $adapter_data2[adapter][count][:delta_ms].to_s if count < $adapter_data2[adapter].length
        values << "," if adapter != outgoing_names.last
      }
      arr_values.push(values)
      count+=1
    end
    File.open(csv_path, "a") do |f|  f.puts(arr_values)   end



  rescue Exception => e
    #IO errors - send NOT_PARSE to Automation service + update stats file #TODO
    puts "IO error"
  end
end

$headers_persisted = false
$file_created = false
$csv_path = nil
$last_recorded_row = 0
def createPartialCsv(outgoingArr,incomingName)

  if (!$file_created) # create file if not exist
    csv_name = Time.now().strftime('%d_%m_%Y-%H_%M_%S')+'.csv'
    $csv_path = Dir.getwd+'/'+csv_name
    File.open($csv_path, "w")
    $file_created = true
    puts $csv_path + ' file created'
  end

  max_tickets = -1
  $adapter_data2.each { |k, v| max_tickets = v.length if v.length > max_tickets && k.upcase.include?("OUT") }

  begin

    outgoing_names = $adapter_data2.keys.select { |v| v.upcase.include? "OUT" }
    new_outgoing_names = ["id", "date"]
    outgoingArr.each { |adapter_name|
      new_outgoing_names.push(adapter_name.gsub(/.*_OUT_/, ""))
    }
    new_outgoing_names.reject!{|adapter_name| adapter_name.to_s.upcase =~ /IN/}
    headers = new_outgoing_names.join(",")


    count = $last_recorded_row #0
    arr_values = []
    arr_values.push(headers) if !$headers_persisted
    $headers_persisted = true
    max_tickets = ( max_tickets.nil? || max_tickets > $ROWS_TO_PERSIST  ) ? $ROWS_TO_PERSIST : max_tickets

    i = 0
    while (i < max_tickets ) #Core out to Tidy length
      break if( $adapter_data2[incomingName][i].nil? )
      values = (count+1).to_s+"," #",TICKET_ID_WAITING_4KOGAN,"
      values << $adapter_data2[incomingName][i][:ticket_id] << "," #[:date] CORE IN id->id ,Tidy TicketID->date
      outgoing_names.each { |adapter|
        values << $adapter_data2[adapter][i][:delta_ms].to_s if i < $adapter_data2[adapter].length && !$adapter_data2[adapter][i].nil?
        values << "," if adapter != outgoing_names.last
      }
      arr_values.push(values)
      i+=1
      count+=1
    end
    $last_recorded_row = count
    if !arr_values.nil? && !arr_values.empty?
      File.open($csv_path, "a") do |f|  f.puts(arr_values)   end
      puts "### - Data Appended, last_recorded_row: #{$last_recorded_row.to_s}"
    else
      puts "!!! - Data Not Appended, last_recorded_row: #{$last_recorded_row.to_s}"
    end


  rescue Exception => e
    #IO errors - send NOT_PARSE to Automation service + update stats file #TODO
    puts outgoingArr.to_s + ' parsed count = ' + count.to_s + " Error " + e.backtrace.to_s
  end
end

def createChartCsv
   outgoing = addDeltas
   createCsv(outgoing)
end


def createPartialChartCsv
  outgoing = addDeltasPartial
  createPartialCsv(outgoing,"CORE_OUT_CORE")
end

LOGS_DIR = "C:/Automation/CPT_1M_LOGS/logsM" #Dir.getwd+"/tmp/logs2" #"C:/Automation/CPT_1M_LOGS/logsM" #Dir.getwd+"/tmp/logs2" #"C:/Automation/CPT_1M_LOGS/logsM" #TODO as script param
def runPartial
  #RubyProf.start
  start = Time.now
  puts("Parsing Started at #{start}")


  threads = []

  #New Thread
  coreAdapters = []
  core_file_search_pattern = "pts_core_*" #TODO as script param
  core_in_adapter = {:adapter_label=>"CORE_IN",:event=>CORE_ER_IN_EVENT,:search2_str=>nil,:search3_str=>nil,:search4_str=>nil,:regex_id=>CORE_ER_IN_REGEX}
  coreAdapters.push core_in_adapter
  core_out_adapter = {:adapter_label=>"CORE_OUT_CORE",:event=>CORE_ER_OUT_EVENT,:search2_str=>nil,:search3_str=>nil,:search4_str=>nil,:regex_id=>CORE_ER_OUT_REGEX}
  coreAdapters.push core_out_adapter
  ##parse_adapters2(LOGS_DIR,core_file_search_pattern,coreAdapters,1)

  #New Thread
  tidyAdapters = []
  tidy_file_search_pattern = "pts_tidy_*" #TODO as script param
  tidy_in_adapter = {:adapter_label=>"TIDY_IN",:event=>TIDY_ER_IN_EVENT,:search2_str=>nil,:search3_str=>nil,:search4_str=>nil,:regex_id=>TIDY_ER_IN_REGEX}
  tidyAdapters.push tidy_in_adapter
  tidy_out_CSV_COMMON_adapter = {:adapter_label=>"TIDY_OUT_CSV_COMMON",:event=>TIDY_CSV_COMMON_EVENT,:search2_str=>TIDY_CSV_COMMON_EVENT_MSG1,:search3_str=>TIDY_CSV_COMMON_EVENT_MSG2,:search4_str=>nil,:regex_id=>TIDY_ER_OUT_REGEX}
  tidyAdapters.push tidy_out_CSV_COMMON_adapter
  tidy_out_CSV_MYT_adapter = {:adapter_label=>"TIDY_OUT_CSV_MYT",:event=>TIDY_CSV_MYT_EVENT,:search2_str=>TIDY_CSV_MYT_EVENT_MSG1,:search3_str=>TIDY_CSV_MYT_EVENT_MSG2,:search4_str=>nil,:regex_id=>TIDY_ER_OUT_REGEX}
  tidyAdapters.push tidy_out_CSV_MYT_adapter
  tidy_out_JSON_SAPPHIRE_adapter = {:adapter_label=>"TIDY_OUT_JSON_SAPPHIRE",:event=>TIDY_JSON_SAPPHIRE_EVENT,:search2_str=>TIDY_JSON_SAPPHIRE_MSG,:search3_str=>nil,:search4_str=>nil,:regex_id=>TIDY_ER_OUT_REGEX}
  tidyAdapters.push tidy_out_JSON_SAPPHIRE_adapter
  ##parse_adapters2(LOGS_DIR,tidy_file_search_pattern,tidyAdapters,2)

=begin
  adapters_arr = [ {:search_pattern => core_file_search_pattern, :logs_pattern => coreAdapters, :adapter_index => 1 },
                  {:search_pattern => tidy_file_search_pattern, :logs_pattern => tidyAdapters, :adapter_index => 2 }  ]
  adapters_arr.in_threads(2).each {|adapter|
    parse_adapters2(LOGS_DIR,adapter[:search_pattern], adapter[:logs_pattern], adapter[:adapter_index])
  }
=end

  $threads=[]
  atttachAdapterThread(LOGS_DIR,core_file_search_pattern,coreAdapters,1)
  atttachAdapterThread(LOGS_DIR,tidy_file_search_pattern,tidyAdapters,2)
  ThreadsWait.all_waits(*$threads)

=begin
  threads = []
  t1=Thread.new{ parse_adapters2(LOGS_DIR,core_file_search_pattern, coreAdapters, 1)}
  t1.abort_on_exception = true
  threads << t1
  t2=Thread.new{ parse_adapters2(LOGS_DIR,tidy_file_search_pattern, tidyAdapters, 2)}
  t2.abort_on_exception = true
  t1.join
  threads << t2
  t2.join
  ThreadsWait.all_waits(*threads )
=end


  persistRemainder

  puts("Parsing Ended at #{Time.now}")
  puts("Duration: #{(Time.now-start)}secs")
  $adapter_data2.each{|k,v| puts "#{k} - #{v.length} "}

  puts "end"

#RubyProf.start

=begin
  start = Time.now
  puts("Create CSV Started at #{start}")
  createChartCsv
  puts("Create CSV Ended at #{Time.now}")
  puts("Duration: #{(Time.now-start)}secs")
=end

=begin
  result = RubyProf.stop
  # print a flat profile to text
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(STDOUT)
=end

end

def atttachAdapterThread(search_in_dir,file_pattern,arrAdapters,logsId=0)
  t=Thread.new{parse_adapters2(search_in_dir,file_pattern,arrAdapters,logsId=0)}
  t.abort_on_exception = true
  $threads << t

  return true
end

def parse_adapters(search_in_dir,file_pattern,arrAdapters,logsId=0)
  files_sorted_by_time_asc = Dir[search_in_dir+"/"+file_pattern].sort_by{ |f| File.mtime(f) } #Dir['pts_core*']
  files_sorted_by_time_asc.each {|file_name|
    parseFile(arrAdapters,file_name,logsId)
    #syncBlock(&parseFile(arrAdapters,file_name))
  }
  $core_finished = true if logsId == 0
  $tidy_finished = true if logsId == 1

end



def run

  start = Time.now
  puts("Parsing Started at #{start}")


  threads = []

  #New Thread
  coreAdapters = []
  core_file_search_pattern = "pts_core_*" #TODO as script param
  core_in_adapter = {:adapter_label=>"CORE_IN",:event=>CORE_ER_IN_EVENT,:search2_str=>nil,:search3_str=>nil,:search4_str=>nil,:regex_id=>CORE_ER_IN_REGEX}
  coreAdapters.push core_in_adapter
  core_out_adapter = {:adapter_label=>"CORE_OUT_CORE",:event=>CORE_ER_OUT_EVENT,:search2_str=>nil,:search3_str=>nil,:search4_str=>nil,:regex_id=>CORE_ER_OUT_REGEX}
  coreAdapters.push core_out_adapter
   parse_adapters(LOGS_DIR,core_file_search_pattern,coreAdapters,1)

  #New Thread
  tidyAdapters = []
  tidy_file_search_pattern = "pts_tidy_*" #TODO as script param
  tidy_in_adapter = {:adapter_label=>"TIDY_IN",:event=>TIDY_ER_IN_EVENT,:search2_str=>nil,:search3_str=>nil,:search4_str=>nil,:regex_id=>TIDY_ER_IN_REGEX}
  tidyAdapters.push tidy_in_adapter
  tidy_out_CSV_COMMON_adapter = {:adapter_label=>"TIDY_OUT_CSV_COMMON",:event=>TIDY_CSV_COMMON_EVENT,:search2_str=>TIDY_CSV_COMMON_EVENT_MSG1,:search3_str=>TIDY_CSV_COMMON_EVENT_MSG2,:search4_str=>nil,:regex_id=>TIDY_ER_OUT_REGEX}
  tidyAdapters.push tidy_out_CSV_COMMON_adapter
  tidy_out_CSV_MYT_adapter = {:adapter_label=>"TIDY_OUT_CSV_MYT",:event=>TIDY_CSV_MYT_EVENT,:search2_str=>TIDY_CSV_MYT_EVENT_MSG1,:search3_str=>TIDY_CSV_MYT_EVENT_MSG2,:search4_str=>nil,:regex_id=>TIDY_ER_OUT_REGEX}
  tidyAdapters.push tidy_out_CSV_MYT_adapter
  tidy_out_JSON_SAPPHIRE_adapter = {:adapter_label=>"TIDY_OUT_JSON_SAPPHIRE",:event=>TIDY_JSON_SAPPHIRE_EVENT,:search2_str=>TIDY_JSON_SAPPHIRE_MSG,:search3_str=>nil,:search4_str=>nil,:regex_id=>TIDY_ER_OUT_REGEX}
  tidyAdapters.push tidy_out_JSON_SAPPHIRE_adapter
  parse_adapters(LOGS_DIR,tidy_file_search_pattern,tidyAdapters,2)


  createChartCsv

  puts("Parsing Ended at #{Time.now}")
  puts("Duration: #{(Time.now-start)}secs")
  $adapter_data2.each{|k,v| puts "#{k} - #{v.length} "}



end



runPartial

#$adapter_data2 = {}
#run