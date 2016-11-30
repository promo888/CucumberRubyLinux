require 'time'
require 'in_threads'
require 'thread'

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


DEBUG = true
LOGS_DIR = Dir.getwd+"/tmp/logs2" # "C:/Automation/CPT_1M_LOGS/logsM" #Dir.getwd+"/tmp/logs2" #


class LogParser

  def initialize(searchDir,filePattern,inAdapter,outAdapters,resultsPath="",rowsToPersist=10000)
    @logs_dir = searchDir
    @logs_pattern = filePattern
    @in_Adapter = inAdapter
    @out_adapters = outAdapters
    @parsed_data = {}
    @parsed_tickets_count = 0
    @parsed_out_adapters_count = 0
    @persisted_count = 0
    @csv_file_name = nil
    @total_chart_html = nil
    @zoom_chart_html = nil
    @results_path = resultsPath.empty? ? Dir.pwd : resultsPath
    @persist_each_count = rowsToPersist
    @parsing_finished = false
  end


  def line_include?(str,search1_str,search2_str=nil,search3_str=nil,search4_str=nil,search5_str=nil)
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

    return false
  end

  def addDeltasPartial
    @incoming = @parsed_data.keys.select { |v| v.upcase.include? "IN" }[0]
    @outgoing = @parsed_data.keys.select { |v| v.upcase.include? "OUT" }

    @parsed_data[@incoming].each_with_index { |in_a, index|
      @outgoing.each{|out_a|
        #@parsed_data[out_a] TODO to continue
        if @parsed_data[@incoming][index][:ticket_id] == @parsed_data[out_a][index][:ticket_id]
          out_time = Time.strptime(@parsed_data[out_a][index][:date], "%d-%m-%y %H:%M:%S.%L")
          in_time = Time.strptime(@parsed_data[@incoming][index][:date], "%d-%m-%y %H:%M:%S.%L")
          delta_ms = out_time - in_time
          @parsed_data[out_a][index][:delta_ms] = delta_ms if @parsed_data[out_a][index][:delta_ms].nil?
        end

        #TODO maybe BUGGY,since write is Async and not ordered -> Exact Matching is costly!!!
        if (index+1<in_a.length && index+1<out_a.length) && @parsed_data[in_a][index][:ticket_id] == @parsed_data[out_a][index+1][:ticket_id]
          out_time = Time.strptime(@parsed_data[out_a][index+1][:date], "%d-%m-%y %H:%M:%S.%L")
          in_time = Time.strptime(@parsed_data[@incoming][index][:date], "%d-%m-%y %H:%M:%S.%L")
          delta_ms = out_time - in_time
          @parsed_data[out_a][index+1][:delta_ms] = delta_ms if @parsed_data[out_a][index+1][:delta_ms].nil?
        end
      }
    }

    return @outgoing
  end

  def createPartialCsv(outgoingArr,incomingName)

    if (@csv_file_name.nil?) # create file if not exist
      csv_name = incomingName.gsub("_IN","")+'_'+Time.now().strftime('%d_%m_%Y-%H_%M_%S')+'.csv'
      dir = @results_path.empty? ? Dir.getwd : @results_path
      csv_path = dir+'/'+csv_name
      File.open(csv_path, "w")
      @file_created = true
      @csv_file_name = csv_name
      puts csv_path + ' file created' if(DEBUG)
    end

    max_tickets = -1
    @parsed_data.each { |k, v| max_tickets = v.length if v.length > max_tickets && k.upcase.include?("OUT") }

    begin

      outgoing_names = @parsed_data.keys.select { |v| v.upcase.include? "OUT" }
      new_outgoing_names = ["id", "date"]
      outgoingArr.each { |adapter_name|
        new_outgoing_names.push(adapter_name.gsub(/.*_OUT_/, ""))
      }
      new_outgoing_names.reject!{|adapter_name| adapter_name.to_s.upcase =~ /IN/}
      headers = new_outgoing_names.join(",")



      arr_values = []
      arr_values.push(headers) if @headers_persisted.nil?
      @headers_persisted = true
      max_tickets = ( max_tickets.nil? || max_tickets > @persist_each_count  ) ? @persist_each_count : max_tickets

      i = 0
      while (i < max_tickets ) #Core out to Tidy length
        break if( @parsed_data[incomingName][i].nil? )
        values = (@persisted_count+1).to_s+"," #",TICKET_ID_WAITING_4KOGAN,"
        values << @parsed_data[incomingName][i][:ticket_id] << "," #[:date] CORE IN id->id ,Tidy TicketID->date
        outgoing_names.each { |adapter|
          values << @parsed_data[adapter][i][:delta_ms].to_s if i < @parsed_data[adapter].length && !@parsed_data[adapter][i].nil?
          values << "," if adapter != outgoing_names.last
        }
        arr_values.push(values)
        i+=1
        #@persisted_count+=1

      end

      if !arr_values.nil? && !arr_values.empty? && arr_values.length>1
        File.open(csv_path, "a") do |f|  f.puts(arr_values)   end
        puts "### - Data Appended, last_recorded_row: #{$last_recorded_row.to_s}" if(DEBUG)
        @persisted_count = max_tickets
      else
        puts "!!! - Data Not Appended, last_recorded_row: #{$last_recorded_row.to_s}" if(DEBUG)
      end

    rescue Exception => e
      #IO errors - send NOT_PARSE to Automation service + update stats file #TODO
      puts outgoingArr.to_s + ' parsed count = ' + count.to_s + " Error " + e.backtrace.to_s
    end
  end

  def createPartialChartCsv
    outgoing = addDeltasPartial
    createPartialCsv(outgoing,@incoming[0]) if !@incoming[0].nil?
  end

  def persistToFilePartial
    createPartialChartCsv
    @parsed_data.each{|adapter|
      current_adapter_size = @parsed_data[adapter[0]].length
      rows_to_remove = @persist_each_count > current_adapter_size ? @persist_each_count-current_adapter_size : @persist_each_count
      @parsed_data[adapter[0]].slice!(0..rows_to_remove)
    }
  end

  def parseFilePartial(arrAdapters,file_name)
    begin
      file=File.open(file_name)
      file.readlines.each_with_index do |line,index|
        arrAdapters.each_with_index {|adapter,i|
          @parsed_data[adapter[:adapter_label]]=[] if @parsed_data[adapter[:adapter_label]].nil?

          if line_include?(line,adapter[:event],adapter[:search2_str],adapter[:search3_str],adapter[:search4_str])
            begin
              id=line.scan(/#{adapter[:regex_id]}/)[0][0]
            rescue
              next if id.nil?
            end

            time = line.split[0]+' '+line.split[1]
            last_index = @parsed_data[adapter[:adapter_label]].length
            @parsed_tickets_count = last_index + 1
            @parsed_data[adapter[:adapter_label]].push({:id => @parsed_tickets_count,:date => time, :ticket_id => id})
            @parsed_out_adapters_count+=1 if @parsed_tickets_count > @persist_each_count && adapter[:adapter_label] == arrAdapters.last[:adapter_label]
          end
        }

        if(@parsed_out_adapters_count >= @persist_each_count && !@parsing_finished)
          puts "--DEBUG1-- going to persist Total of #{@persist_each_count.to_s} ersORtickets - for #{arrAdapters.collect{|e| e[:adapter_label]}.to_s}" if(DEBUG)
          persistToFilePartial
          @parsed_out_adapters_count-=@persist_each_count
          #@persisted_count+=@persist_each_count
        end

        if(@parsing_finished)
          #persistRemainder #TODO
        end
      end
      puts "DEBUG => " + file_name + " parsed " if(DEBUG)
    rescue Exception => e
      raise("Exception in #{file_name} " + e.backtrace.to_s)
    ensure
      file.close
    end
  end

  def parse_adapters(arrAdapters)
    files_sorted_by_time_asc = Dir[@logs_dir+"/"+@logs_pattern].sort_by{ |f| File.mtime(f) }
    files_sorted_by_time_asc.each {|file_name| parseFilePartial(arrAdapters,file_name) }
    @parsing_finished = true
  end

end


coreAdapters = []
core_file_search_pattern = "pts_core_*" #TODO as script param
core_in_adapter = {:adapter_label=>"CORE_IN",:event=>CORE_ER_IN_EVENT,:search2_str=>nil,:search3_str=>nil,:search4_str=>nil,:regex_id=>CORE_ER_IN_REGEX}
coreAdapters.push core_in_adapter
core_out_adapter = {:adapter_label=>"CORE_OUT_CORE",:event=>CORE_ER_OUT_EVENT,:search2_str=>nil,:search3_str=>nil,:search4_str=>nil,:regex_id=>CORE_ER_OUT_REGEX}
coreAdapters.push core_out_adapter
#parse_adapters(LOGS_DIR,core_file_search_pattern,coreAdapters,1)

coreParser = LogParser.new(LOGS_DIR,core_file_search_pattern,core_in_adapter,core_out_adapter,"",1000)
coreParser.parse_adapters(coreAdapters)