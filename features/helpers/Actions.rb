require 'cucumber'
require 'net/ssh'
require 'net/scp'
require 'net/sftp'
require 'net/ftp'
#require 'net/ssh/shell'
require 'net/http'
require 'net/https'
require 'json'
#require 'json-comp'
require 'json-compare'
require 'dbi'
require 'oci8'
require 'fileutils'
require 'csv-diff'
require 'csv-mapper'
require 'csv2json'
require 'diff_dirs'
require 'diffy'
require 'time'
require 'csv'



class Actions
      #include Config
      #include CONFIG
#dummy

    def Actions.SSH(host, user, pwd, cmd, timeout_sec, bash_output, expected_output)
        begin
            #c 'Opening SSH session... '
            session_timeout = Integer(timeout_sec) rescue nil
            ssh = Net::SSH.start(host, user, :password => pwd)
            if (session_timeout)
               timeout session_timeout do
                   time = Time.new
                   cur_time = time.day.to_s+'-'+time.month.to_s+'-'+time.year.to_s+'_'+time.hour.to_s+'-'+time.min.to_s+'-'+time.sec.to_s
                    v ' Executing command "' +cmd.to_s+'"...'
                    $ssh_output = ssh.exec!(cmd)
                    v 'Command "' +cmd.to_s+'" finished'
                    #sleep(3)
                    #ssh.loop(3)
               end
            end
            ####ssh.close
            if (!expected_output.to_s.empty? && expected_output.is_a?(Array) && bash_output)
              not_found = false
              expected_output.each_with_index { |row, i|
                not_found = true  if(!$ssh_output=~row)
               # fail("Expected Regex ''"+row.to_s+"'  Not Found in SSH output: ")  if(not_found)
              }
              fail("Expected Regex ''"+expected_output.to_s+"'  Not Found in SSH output: "+$ssh_output)  if(not_found)
            else
              fail('Expected Regex '+expected_output.to_s+"' Not Found in SSH output: "+$ssh_output) if (!expected_output.to_s.empty? && !$ssh_output.to_s.include?(expected_output) && bash_output && !expected_output.is_a?(Array))
            end
        rescue Exception => e
            @@scenario_fails.push(e.message)
            f "SSH Error: " + e.to_s + " #{host} for #{user}@#{pwd} on cmd:#{cmd}"  if (e!=nil)
            fail("SSH Error: " + e.to_s + " #{host} for #{user}@#{pwd} on cmd:#{cmd}") if (e!=nil)
        ensure
            ssh.close if (ssh!=nil)
            #c 'SSH session closed!'
        end

      @@scenario_fails.push('SSH FAILED - ' + $ssh_output.to_s)   if (!$ssh_output.to_s.empty? && !bash_output || $ssh_output.to_s.downcase.include?('error') || $ssh_output.to_s.downcase.include?('No such file or directory'))
      fail('SSH FAILED - ' + $ssh_output.to_s) if (!$ssh_output.to_s.empty? && !bash_output)#bash_output for parsing bash results
      fail('SSH FAILED - ' + $ssh_output.to_s) if ($ssh_output.to_s.downcase.include?('not found') || $ssh_output.to_s.downcase.include?('error') || $ssh_output.to_s.downcase.include?('No such file or directory'))

      return $ssh_output

    end




    def Actions.SSH_NO_FAIL(host, user, pwd, cmd, timeout_sec)
      begin
        #v 'Opening SSH session... '
        session_timeout = Integer(timeout_sec) rescue nil
        ssh = Net::SSH.start(host, user, :password => pwd)
        if (session_timeout)
          timeout session_timeout do
            v ' Executing command  ' +cmd.to_s
            $ssh_output = ssh.exec!(cmd)

          end
        end

      rescue Exception => e
        #f "SSH Error: " + e.to_s + " #{host} for #{user}@#{pwd}"  if (e!=nil)
        #fail("SSH Error: " + e.to_s + " #{host} for #{user}@#{pwd}") if (e!=nil)
        #@@scenario_fails.push(e.message)
      ensure
        ssh.close if (ssh!=nil)
        #v 'SSH session closed!'
      end

      return $ssh_output

    end



    def Actions.SSH_SHELL(host, user, pwd, cmd_array, timeout_sec, bash_output, expected_output)
      begin
      session_timeout = Integer(timeout_sec) rescue nil
      ssh_shell = Net::SSH.start(host, user, :password => pwd)

        timeout session_timeout do
            ssh_shell.exec! "whoami"
            $r=ssh_shell.exec! " bash /export/home/oracle/Automation/sdata_schema_install_automatic.sh -v"#cmd_array #"cd ~/MSLErSender/bin && ./mslErSender.sh -s ~/data/tmp_ER2"
            self.v 'ssh_shell res:'+$r.to_s


          #  assert_match(/.txt with execId [....-....-....-..]+/, cmd.to_s,' Terminal Output Should contain execId')
          #  c ($r =~ /.txt with execId [....-....-....-..]+/)
          ##  c $r =~ /txt with execId/i
          ##  report_string = 'ExecId asserted ' + $r.scan(/\[(.*?)\]/).to_s
          ##  c report_string
        end

    rescue Exception => e
      self.f "SSH Error: " + e.to_s + " #{host} for #{user}@#{pwd}"
      fail("SSH Error: " + e.to_s + " #{host} for #{user}@#{pwd}")
      @@scenario_fails.push(e.message)
    ensure
      ssh_shell.close if (ssh_shell!=nil)
    end


    #fail('SSH FAILED - ' + $r.to_s) if (!$r.to_s.empty? && !bash_output)#bash_output for parsing bash results #TODO bashError
    #fail('SSH FAILED - ' + $r.to_s) if ($r.to_s.downcase.include?('not found') || $r.to_s.downcase.include?('error') )
  rescue Exception=>e
    self.f 'ssh_shell failed - '+ e.message

    #return $cmd

  end



  def Actions.WINCMD(cmd, timeout_sec, expected_output)
    self.v 'Executing local win command ' + cmd + (!expected_output.to_s.empty? ? ' expected_output - ' + expected_output : '')
    begin
      session_timeout = Integer(timeout_sec) rescue nil
      $cmd_output =[]
      if (session_timeout)
        timeout session_timeout do
          IO.popen(cmd).each do |line|
            p line.chomp
            $cmd_output  << line.chomp
          end
        end
      else
        IO.popen(cmd).each do |line|
          p line.chomp
          $cmd_output  << line.chomp
        end
      end
    #c  ('WinCMD  Response: ' + $cmd_output.to_s)
    fail('Expected Regex Not Found in CMD output: ' + expected_output ) if (!expected_output.to_s.empty? && !$cmd_output.to_s =~ expected_output.to_s)

    rescue Exception => e
      @@scenario_fails.push(e.message)
      f "Local WinCmd Error: " + e.to_s if (e!=nil)
      fail("Local WinCmd Error: " + e.to_s ) if (e!=nil)
    ensure
      #IO.close
    end


    fail('Local WinCmd  FAILED - ' + $cmd_output.to_s) if ( $cmd_output.to_s.downcase.include?('not found') || $cmd_output.to_s.downcase.include?('error')  || $cmd_output.to_s.downcase.include?('not recognized'))

    return $cmd_output

  end



  def Actions.WINCMD_NO_FAIL(cmd, timeout_sec)
      #self.c 'Executing local win command ' + cmd
      begin
        session_timeout = Integer(timeout_sec) rescue nil
        $cmd_output =[]
        if (session_timeout)
          timeout session_timeout do
            IO.popen(cmd).each do |line|
              #p line.chomp
              $cmd_output  << line.chomp
              $cmd_output
            end
          end
        else
          IO.popen(cmd).each do |line|
            #p line.chomp
            $cmd_output  << line.chomp
            v $cmd_output
          end
        end
        #c  ('WinCMD  Response: ' + $cmd_output.to_s)

      rescue Exception => e
        #NO_FAIL :-)
      ensure
        #Kill in Before Scenario
        #IO.close
      end

      return $cmd_output

  end




  def Actions.getHashFromJsonFile(json_file_path)
    c 'json_file_path ' + json_file_path
    c 'Current Dir ' + Dir.getwd
    $json_output = {}
    begin
      json_file =  File.read(json_file_path)
             # #er_file_path 'libs/MSLErSender/data/Scenario0/er_test.txt'
      json = json_file.to_json
      $json_output = JSON.parse(json, :quirks_mode => true)
    rescue Exception => e
      @@scenario_fails.push(e.message)
      f e.message if (!e.nil?)
      fail('Error in Json - ' + e.message ) if (!e.nil?)
    ensure
      #file.close if !file.nil?
    end

    return $json_output
  end



  def Actions.getDbQueryResults(query,expected_row_count,failed_file_name)
    host = @@CONFIG['ORACLE_HOST']
    port = @@CONFIG['ORACLE_HOST_PORT']
    service = @@CONFIG['ORACLE_HOST_SERVICE']
    usr = @@CONFIG['ORACLE_DB_USER']
    pwd = @@CONFIG['ORACLE_DB_PWD']

    v 'Connecting to ' + host.to_s+':'+port.to_s+'/'+service.to_s+' with ' +usr.to_s+'/'+pwd.to_s+'...'

    $query_results = []
    begin
      dbh = DBI.connect('DBI:OCI8:'+host.to_s+':'+port.to_s+'/'+service.to_s,usr.to_s,pwd.to_s)
      sth = dbh.prepare(query)
      sth.execute() #('SYSTEM')
      #$db_res = sth.fetch_hash #fetch 1row
      $row_count = 0
      while row=sth.fetch_hash do
        $row_count+= 1
       # c row[0].to_s
        $query_results << row
      end
      c (" Query Results <br> " + printDbTableHash($query_results) + " <br> ")
      fail (expected_row_count.to_s + " records expected for query but Actual is " + $row_count.to_s+" <br> Query <br>" + query + " <br> ")  if(!expected_row_count.to_s.empty? && expected_row_count.to_i!=$row_count)

      #c '<br> ASSERTED - '+ expected_row_count.to_s + ' rows amount for query - ' + query + '<br>'
    rescue Exception => e
      @@scenario_fails.push(e.message)
      f e.message if (!e.nil?)
      fail('DB Error  - ' + e.message) if (!e.nil?)
    ensure
      sth.finish if !dbh.nil?
      dbh.disconnect if dbh
    end

    c $query_results.to_s
    return $query_results


  end




  def Actions.compareDbTableResults(source_schema, target_schema, folder_timestamp)
    tables = @@CONFIG['ORACLE_TABLES_TO_COMPARE']
    results_dir =  folder_timestamp.nil? ? @@CONFIG['ORACLE_TABLES_COMPARE_RESULTS_DIR'] : @@CONFIG['ORACLE_TABLES_COMPARE_RESULTS_DIR']+'/'+folder_timestamp
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+@@CONFIG['ORACLE_TABLES_COMPARE_RESULTS_DIR']+' && mkdir ' +  folder_timestamp, 10) #if(!folder_timestamp.nil?)

    Actions.checkTablesChanges(source_schema, target_schema)
    Actions.compareSchemasStructure(source_schema, target_schema)

    tables.each_with_index { |table, index|
      Actions.compareTableStructure(source_schema, target_schema, table.keys[0].to_s) if(!table.keys[0].to_s.nil?)
      if(table.keys[0].nil?)
        Actions.f ' DB Error - Table '+ table.keys[0]
        @@scenario_fails.push(' DB Error - Table '+ table.keys[0] )
        fail(' DB Error - Table '+ table.keys[0] )
        return
      end

      $sql_query_source_diff=nil
      $sql_query_target_diff=nil
      $order_by=nil
      $order_by=tables[index].find { |key, value| key.to_s.match(/#{tables[index].keys[0]}/)}[1][0]['ORDER_BY']
      #puts 'order_by - ' +$order_by

      $source_cols_query = "SELECT column_name FROM  all_tab_columns WHERE  table_name = '" +tables[index].keys[0] +"'  AND owner = '"+source_schema+"' order by 1"
      $target_cols_query = "SELECT column_name FROM  all_tab_columns WHERE  table_name = '" +tables[index].keys[0] +"'  AND owner = '"+target_schema+"' order by 1"

      $source_cols = self.getDbQueryResultsWithoutFailure4(source_schema,source_schema.to_s.downcase,$source_cols_query)
      $target_cols = self.getDbQueryResultsWithoutFailure4(target_schema,target_schema.to_s.downcase,$target_cols_query)
      if($source_cols.nil? || $target_cols.nil?)
        #self.f(' Error ? - No Data Returned')
        @@scenario_fails.push('DB Error for '+tables[index].keys[0])
        fail(' DB Error '+tables[index].keys[0])
        return
      end

       if(!($source_cols-$target_cols).nil? && ($source_cols-$target_cols).length>0)
           $cols_list=''
           ($source_cols - $target_cols).each { |col_value|  $cols_list+=(col_value['COLUMN_NAME']+'<br>') }
           self.f(' Error ? - in table '+ tables[index].keys[0] + ' Removed fields: <br>'+  $cols_list) if(!$cols_list.to_s.empty?)
        end
        if( !($target_cols-$source_cols).nil? && ($target_cols-$source_cols).length>0)
          $cols_list=''
          ($target_cols-$source_cols).each { |col_value|  $cols_list+=(col_value['COLUMN_NAME']+'<br>') }
          self.f(' Error ? - in table '+ tables[index].keys[0] + ' Added fields: <br>'+  $cols_list) if(!$cols_list.to_s.empty?)
        end
        $exclude_cols = @@CONFIG['ORACLE_HOST_TABLES_EXCLUDED_COLUMNS'][index][table.keys[0]]
        $include_cols = $target_cols-($target_cols-$source_cols)-($source_cols-$target_cols)
        $include_cols = $include_cols - $exclude_cols if(!$exclude_cols.nil?)

        $include_cols.each_with_index { |elem, index|
          #puts elem['COLUMN_NAME']
          $exclude_cols.each { |elem2|
            $include_cols.delete_at(index) if(elem['COLUMN_NAME']==elem2)
          }
        }

          $sql_query_source_diff = "SELECT  "
        $include_cols.each_with_index{|val,i|
          $sql_query_source_diff << $include_cols[i]['COLUMN_NAME'].to_s
          $sql_query_source_diff << "," if(i+1!=$include_cols.length)
        }
        $sql_query_source_diff << " FROM " +source_schema+"."+tables[index].keys[0]
        #$sql_query_source_diff << ' order by 1 '
        $sql_query_source_diff << " MINUS "
        $sql_query_source_diff << "SELECT  "
        $include_cols.each_with_index{|val,i|
          $sql_query_source_diff << $include_cols[i]['COLUMN_NAME'].to_s
          $sql_query_source_diff << "," if(i+1!=$include_cols.length)
        }
        $sql_query_source_diff << " FROM " +target_schema+"."+tables[index].keys[0]
        #$sql_query_source_diff << ' order by 1 '



        $sql_query_target_diff = "SELECT  "
        $include_cols.each_with_index{|val,i|
          $sql_query_target_diff << $include_cols[i]['COLUMN_NAME'].to_s
          $sql_query_target_diff << "," if(i+1!=$include_cols.length)
        }
        $sql_query_target_diff << " FROM " +target_schema+"."+tables[index].keys[0]
        #$sql_query_target_diff << ' order by 1 '
        $sql_query_target_diff << " MINUS "
        $sql_query_target_diff << "SELECT  "
        $include_cols.each_with_index{|val,i|
          $sql_query_target_diff << $include_cols[i]['COLUMN_NAME'].to_s
          $sql_query_target_diff << "," if(i+1!=$include_cols.length)
        }
        $sql_query_target_diff << " FROM " +source_schema+"."+tables[index].keys[0]
        #$sql_query_target_diff << ' order by 1 '



      source_res = self.getDbQueryResultsWithoutFailure4(source_schema,source_schema.to_s.downcase,$sql_query_source_diff)
      target_res = self.getDbQueryResultsWithoutFailure4(target_schema,target_schema.to_s.downcase,$sql_query_target_diff)

      if(source_res.nil? || target_res.nil? || source_res!=target_res || !source_res.to_s.empty? || !target_res.to_s.empty?)
        $link_path = ''
        if Dir.getwd.include?(@@CONFIG['JENKINS_JOB_NAME']) # specific for a jenkins url and job remove C:/Jenkins/jobs/CPT-Sanity/workspace/
          if ((!source_res.nil? && !target_res.nil?) && (source_res-target_res).length>0)
            f ' Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + source_res.length.to_s  + ' Removed records in '+ target_schema
            source_file=Dir.getwd+results_dir+'/source_'+source_schema+'_'+tables[index].keys[0]+'.csv'
            target_file=Dir.getwd+results_dir+'/target_'+target_schema+'_'+tables[index].keys[0]+'.csv'
            $link_path_source = @@CONFIG['JENKINS_URL'].to_s+'job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +source_file
            $link_path_target = @@CONFIG['JENKINS_URL'].to_s+'job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +target_file
            $link_path_source.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
            $link_path_target.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
            f "Storing Diff <a href='" + $link_path_source+"'>"+source_file.to_s+"</a> and <a href='"+$link_path_target+"'>" + target_file.to_s+"</a> in " +results_dir
          elsif ((!source_res.nil? && !target_res.nil?) && (target_res-source_res).length>0)
            f ' Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + target_res.length.to_s  + ' Added records in '+ target_schema
            source_file=Dir.getwd+results_dir+'/source_'+source_schema+'_'+tables[index].keys[0]+'.csv'
            target_file=Dir.getwd+results_dir+'/target_'+target_schema+'_'+tables[index].keys[0]+'.csv'
            $link_path_source = @@CONFIG['JENKINS_URL'].to_s+'job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +source_file
            $link_path_target = @@CONFIG['JENKINS_URL'].to_s+'job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +target_file
            $link_path_source.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
            $link_path_target.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
            f "Storing Diff <a href='" + $link_path_source+"'>"+source_file.to_s+"</a> and <a href='"+$link_path_target+"'>" + target_file.to_s+"</a> in " +results_dir
          end
        else
          if ((!source_res.nil? && !target_res.nil?) && (source_res-target_res).length>0)
            f 'Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + source_res.length.to_s  + ' Removed records in '+target_schema
            source_file=Dir.getwd+results_dir+'/source_'+source_schema+'_'+tables[index].keys[0]+'.csv'
            target_file=Dir.getwd+results_dir+'/target_'+target_schema+'_'+tables[index].keys[0]+'.csv'
            f "Storing Diff <a href='" + source_file+"'>"+source_file.to_s+"</a> and <a href='"+target_file+"'>" + target_file.to_s+"</a> in " +results_dir
          elsif ((!source_res.nil? && !target_res.nil?) && (target_res-source_res).length>0)
            f 'Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + target_res.length.to_s  + ' Added records in '+target_schema
            source_file=Dir.getwd+results_dir+'/source_'+source_schema+'_'+tables[index].keys[0]+'.csv'
            target_file=Dir.getwd+results_dir+'/target_'+target_schema+'_'+tables[index].keys[0]+'.csv'
            f "Storing Diff <a href='" + source_file+"'>"+source_file.to_s+"</a> and <a href='"+target_file+"'>" + target_file.to_s+"</a> in " +results_dir
          end
        end

        begin
          source_csv_filename = 'source_'+source_schema+'_'+tables[index].keys[0]+'.csv' #Source file
          target_csv_filename = 'target_'+target_schema+'_'+tables[index].keys[0]+'.csv' #Target file


          File.write(Dir.getwd+results_dir+'/'+source_csv_filename, (!source_res.nil? && !source_res.empty?) ? convertHashMapToCsv(source_res) : '')
          File.write(Dir.getwd+results_dir+'/'+target_csv_filename, (!target_res.nil? && !target_res.empty?) ? convertHashMapToCsv(target_res) : '')

        rescue Exception=>e
          @@scenario_fails.push('Exception in Save File or Empty table '+tables[index].to_s+ ' - '  + e.message)
          f 'Exception in Save File or Empty table '+tables[index].to_s+ ' - '  + e.message
          fail('Exception in Save File  or Empty table '+tables[index].to_s+ ' - '  + e.message)
        ensure
          #$file_csv.close if !$file_csv.nil?
        end
      else
        c tables[index].keys[0]+' matched in ' + source_schema + ' and ' + target_schema + ' schemas '
      end


    }


  end



  def Actions.compareDbTableResultsVsBkp(folder_timestamp)
      tables = @@CONFIG['ORACLE_TABLES_TO_COMPARE']
      source_schema = @@CONFIG['ORACLE_HOST_TEMPLATE_SCHEMA'] #['ORACLE_HOST_BKP_SCHEMA']
      target_schema = @@CONFIG['ORACLE_HOST_SCHEMA']
      results_dir =  folder_timestamp.nil? ? @@CONFIG['ORACLE_TABLES_COMPARE_RESULTS_DIR'] : @@CONFIG['ORACLE_TABLES_COMPARE_RESULTS_DIR']+'/'+folder_timestamp
      self.WINCMD_NO_FAIL('cd '+Dir.getwd+@@CONFIG['ORACLE_TABLES_COMPARE_RESULTS_DIR']+' & mkdir ' +  folder_timestamp, 10) #if(!folder_timestamp.nil?) #TODO && !@@db_timestamp_dir.nil?)
#
      $source_tables_count_query = "select table_name  from all_tables t where t.owner='"+source_schema+"'"
      $target_tables_count_query = "select table_name  from all_tables t where t.owner='"+target_schema+"'"

      $source_tables_count_query_res = self.getDbQueryResultsWithoutFailure($source_tables_count_query)
      $target_tables_count_query_res = self.getDbQueryResultsWithoutFailure($target_tables_count_query)
      if($source_tables_count_query_res.nil? || $source_tables_count_query_res.nil?)
        self.f(' Error ? - No Data Returned')
        return
      end

      if ($source_tables_count_query_res.length != $source_tables_count_query_res.length)
        self.f(' Error ? - ' + ($source_tables_count_query_res.length-$target_tables_count_query_res.length+1).to_s + ' Removed Tables - '+ ($source_tables_count_query_res-$target_tables_count_query_res).to_s)  if($source_tables_count_query_res.length > $target_tables_count_query_res.length)
        self.f(' Error ? - ' + ($target_tables_count_query_res.length-$source_tables_count_query_res.length+1).to_s + ' Added Tables - ' + ($target_cols-$source_tables_count_query_res).to_s) if( $target_tables_count_query_res.length>$source_tables_count_query_res.length)
      end
#


      tables.each_with_index { |table, index|
        $sql_query_source_diff=nil
        $sql_query_target_diff=nil
        $order_by=nil
        $order_by=tables[index].find { |key, value| key.to_s.match(/#{tables[index].keys[0]}/)}[1][0]['ORDER_BY']
        #puts 'order_by - ' +$order_by

        $source_cols_query = "SELECT column_name FROM  all_tab_columns WHERE  table_name = '" +tables[index].keys[0] +"'  AND owner = '"+source_schema+"'"
        $target_cols_query = "SELECT column_name FROM  all_tab_columns WHERE  table_name = '" +tables[index].keys[0] +"'  AND owner = '"+target_schema+"'"

        $source_cols = self.getDbQueryResultsWithoutFailure($source_cols_query)
        $target_cols = self.getDbQueryResultsWithoutFailure($target_cols_query)
        if($source_cols.nil? || $target_cols.nil?)
          self.f(' Error ? - No Data Returned')
          return
        end

        if ($source_cols.length == $target_cols.length)
          $sql_query_source_diff = 'SELECT * FROM (select * from ' +  source_schema + '.'+tables[index].keys[0] + ' '
          $sql_query_source_diff=$sql_query_source_diff+' '+$order_by if(!$order_by.nil? && !$order_by.empty?)
          $sql_query_source_diff<< ') minus '
          $sql_query_source_diff<<'SELECT * FROM (select * from ' +  target_schema + '.'+tables[index].keys[0] + ' '
          $sql_query_source_diff=$sql_query_source_diff+' '+$order_by if(!$order_by.nil? && !$order_by.empty?)
          $sql_query_source_diff<< ')'

          $sql_query_target_diff = 'SELECT * FROM (select * from ' +  target_schema + '.'+tables[index].keys[0] + ' '
          $sql_query_target_diff=$sql_query_target_diff+' '+$order_by if(!$order_by.nil? && !$order_by.empty?)
          $sql_query_target_diff<< ') minus '
          $sql_query_target_diff<<'SELECT * FROM (select * from ' +  source_schema + '.'+tables[index].keys[0] + ' '
          $sql_query_target_diff=$sql_query_target_diff+' '+$order_by if(!$order_by.nil? && !$order_by.empty?)
          $sql_query_target_diff<< ')'

        else # Diff in columns is Found

          self.f(' Error ? - ' + ($source_cols.length-$target_cols.length+1).to_s + ' Missing fields - '+ ($source_cols-$target_cols).to_s)  if($source_cols.length > $target_cols.length)
          self.f(' Error ? - ' + ($target_cols.length-$source_cols.length+1).to_s + ' New fields - ' + ($target_cols-$source_cols).to_s) if( $target_cols.length>$source_cols.length)
          $include_cols = $target_cols-($target_cols-$source_cols)-($source_cols-$target_cols)#$source_cols - $exclude_cols


          $sql_query_source_diff = "SELECT  "
          $include_cols.each_with_index{|val,i|
            $sql_query_source_diff << $include_cols[i]['COLUMN_NAME'].to_s
            $sql_query_source_diff << "," if(i+1!=$include_cols.length)
          }
          $sql_query_source_diff << " FROM " +source_schema+"."+tables[index].keys[0]
          #$sql_query_source_diff << ' order by 1 '
          $sql_query_source_diff << " MINUS "
          $sql_query_source_diff << "SELECT  "
          $include_cols.each_with_index{|val,i|
            $sql_query_source_diff << $include_cols[i]['COLUMN_NAME'].to_s
            $sql_query_source_diff << "," if(i+1!=$include_cols.length)
          }
          $sql_query_source_diff << " FROM " +target_schema+"."+tables[index].keys[0]
          #$sql_query_source_diff << ' order by 1 '



          $sql_query_target_diff = "SELECT  "
          $include_cols.each_with_index{|val,i|
            $sql_query_target_diff << $include_cols[i]['COLUMN_NAME'].to_s
            $sql_query_target_diff << "," if(i+1!=$include_cols.length)
          }
          $sql_query_target_diff << " FROM " +target_schema+"."+tables[index].keys[0]
          #$sql_query_target_diff << ' order by 1 '
          $sql_query_target_diff << " MINUS "
          $sql_query_target_diff << "SELECT  "
          $include_cols.each_with_index{|val,i|
            $sql_query_target_diff << $include_cols[i]['COLUMN_NAME'].to_s
            $sql_query_target_diff << "," if(i+1!=$include_cols.length)
          }
          $sql_query_target_diff << " FROM " +source_schema+"."+tables[index].keys[0]
          #$sql_query_target_diff << ' order by 1 '

        end

        source_res = self.getDbQueryResultsWithoutFailure($sql_query_source_diff)
        target_res = self.getDbQueryResultsWithoutFailure($sql_query_target_diff)


        if(source_res.nil? || target_res.nil?)
          self.f(' Error ? - No Data Returned')
          return
        end
        if(source_res.length!=target_res.length)
          $link_path = ''
          if Dir.getwd.include?(@@CONFIG['JENKINS_JOB_NAME']) # specific for a jenkins url and job in order to display links in Report
            f ' Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + source_res.length.to_s  + ' Missing records in '+ target_schema  if(source_res.length>target_res.length)
            f ' Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + target_res.length.to_s  + ' New records in '+ target_schema if(target_res.length>source_res.length)
            source_file=Dir.getwd+'/'+results_dir+'/source_'+source_schema+'_'+tables[index].keys[0]+'.csv'
            target_file=Dir.getwd+'/'+results_dir+'/target_'+target_schema+'_'+tables[index].keys[0]+'.csv'
            $link_path_source = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +source_file
            $link_path_target = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +target_file
            $link_path_source.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
            $link_path_target.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
            f "Storing <a href='" + $link_path_source+"'>"+source_file.to_s+"</a> and <a href='"+$link_path_target+"'>" + target_file.to_s+"</a> in " +results_dir
          else
            f ' Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + source_res.length.to_s  + ' Missing records in '+ target_schema if(source_res.length>target_res.length)
            f ' Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + target_res.length.to_s  + ' New records in '+ target_schema if(target_res.length>source_res.length)
            source_file=Dir.getwd+results_dir+'/source_'+source_schema+'_'+tables[index].keys[0]+'.csv'
            target_file=Dir.getwd+results_dir+'/target_'+target_schema+'_'+tables[index].keys[0]+'.csv'
            f "Storing <a href='" + source_file+"'>"+source_file.to_s+"</a> and <a href='"+target_file+"'>" + target_file.to_s+"</a> in " +results_dir
          end

        else
          c tables[index].keys[0]+' matched in ' + source_schema + ' and ' + target_schema + ' schemas '
        end

        begin
          source_csv_filename = 'source_'+source_schema+'_'+tables[index].keys[0]+'.csv' #Source file
          target_csv_filename = 'target_'+target_schema+'_'+tables[index].keys[0]+'.csv'
          $file_csv=File.open(Dir.getwd+results_dir+'/'+source_csv_filename, 'w') do |file_line| #'/templates/db/'
            source_res.each{|rs_line|
              file_line.puts(rs_line)
            }
          end

          $file_csv=File.open(Dir.getwd+'/'+results_dir+'/'+target_csv_filename, 'w') do |file_line| #Target file '/templates/db/'
            target_res.each{|rs_line|
              file_line.puts(rs_line)
            }
          end

        rescue Exception=>e
          @@scenario_fails.push(e.message)
          f 'Exception in Save File - ' + e.message
          fail('Exception in Save File - ' + e.message)
        ensure
          #$file_csv.close if !$file_csv.nil?
        end



      }



    end



    def Actions.compareDbTableResultsForUpgrade(source_schema, target_schema)
      tables = @@CONFIG['ORACLE_TABLES_TO_COMPARE']
      Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/db & mkdir '+@@time_stamp, 10)
      Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/db/'+@@time_stamp + ' & mkdir latestVsUpgrade', 10)
      results_dir =  @@CONFIG['ORACLE_TABLES_COMPARE_RESULTS_DIR']+'/'+@@time_stamp+'/latestVsUpgrade'

      Actions.checkTablesChanges(source_schema, target_schema)
      Actions.compareSchemasStructure(source_schema, target_schema)

      tables.each_with_index { |table, index|
      Actions.compareTableStructure(source_schema, target_schema, tables[index].keys[0])
        $sql_query_source_diff=nil
        $sql_query_target_diff=nil
        $order_by=nil
        $order_by=tables[index].find { |key, value| key.to_s.match(/#{tables[index].keys[0]}/)}[1][0]['ORDER_BY']
        #puts 'order_by - ' +$order_by

        $source_cols_query = "SELECT column_name FROM  all_tab_columns WHERE  table_name = '" +tables[index].keys[0] +"'  AND owner = '"+source_schema+"'" #" order by 1"
        $target_cols_query = "SELECT column_name FROM  all_tab_columns WHERE  table_name = '" +tables[index].keys[0] +"'  AND owner = '"+target_schema+"'" #" order by 1"

        $source_cols = self.getDbQueryResultsWithoutFailure4(source_schema,source_schema.to_s.downcase,$source_cols_query)
        $target_cols = self.getDbQueryResultsWithoutFailure4(target_schema,target_schema.to_s.downcase,$target_cols_query)
        if($source_cols.nil? || $target_cols.nil?)
          #self.f(' Error ? - No Data Returned')
          @@scenario_fails.push('DB Error for '+tables[index].keys[0])
          fail(' DB Error '+tables[index].keys[0])
          return
        end

        if(!($source_cols-$target_cols).nil? && ($source_cols-$target_cols).length>0)
          $cols_list=''
          ($source_cols - $target_cols).each { |col_value|  $cols_list+=(col_value['COLUMN_NAME']+'<br>') }
          self.f(' Error ? - in table '+ tables[index].keys[0] + ' Removed fields: <br>'+  $cols_list) if(!$cols_list.to_s.empty?)
        end
        if( !($target_cols-$source_cols).nil? && ($target_cols-$source_cols).length>0)
          $cols_list=''
          ($target_cols-$source_cols).each { |col_value|  $cols_list+=(col_value['COLUMN_NAME']+'<br>') }
          self.f(' Error ? - in table '+ tables[index].keys[0] + ' Added fields: <br>'+  $cols_list) if(!$cols_list.to_s.empty?)
        end
        $include_cols = $target_cols-($target_cols-$source_cols)-($source_cols-$target_cols)#$source_cols - $exclude_cols


        $sql_query_source_diff = "SELECT  "
        $include_cols.each_with_index{|val,i|
          $sql_query_source_diff << $include_cols[i]['COLUMN_NAME'].to_s
          $sql_query_source_diff << "," if(i+1!=$include_cols.length)
        }
        $sql_query_source_diff << " FROM " +source_schema+"."+tables[index].keys[0]
        $sql_query_source_diff << ' order by 1 '
        $sql_query_source_diff << " MINUS "
        $sql_query_source_diff << "SELECT  "
        $include_cols.each_with_index{|val,i|
          $sql_query_source_diff << $include_cols[i]['COLUMN_NAME'].to_s
          $sql_query_source_diff << "," if(i+1!=$include_cols.length)
        }
        $sql_query_source_diff << " FROM " +target_schema+"."+tables[index].keys[0]
        $sql_query_source_diff << ' order by 1 '



        $sql_query_target_diff = "SELECT  "
        $include_cols.each_with_index{|val,i|
          $sql_query_target_diff << $include_cols[i]['COLUMN_NAME'].to_s
          $sql_query_target_diff << "," if(i+1!=$include_cols.length)
        }
        $sql_query_target_diff << " FROM " +target_schema+"."+tables[index].keys[0]
        $sql_query_target_diff << ' order by 1 '
        $sql_query_target_diff << " MINUS "
        $sql_query_target_diff << "SELECT  "
        $include_cols.each_with_index{|val,i|
          $sql_query_target_diff << $include_cols[i]['COLUMN_NAME'].to_s
          $sql_query_target_diff << "," if(i+1!=$include_cols.length)
        }
        $sql_query_target_diff << " FROM " +source_schema+"."+tables[index].keys[0]
        $sql_query_target_diff << ' order by 1 '



        source_res = self.getDbQueryResultsWithoutFailure4(source_schema,source_schema.to_s.downcase,$sql_query_source_diff)
        target_res = self.getDbQueryResultsWithoutFailure4(target_schema,target_schema.to_s.downcase,$sql_query_target_diff)


        if(source_res.nil? || target_res.nil?)
          if(source_res.nil?)
            self.f('  - No Data Returned for ' + source_res)
            fail(' Error ? - No Data Returned for ' + source_res)
          end
          if(target_res.nil?)
            self.f(' Error ? - No Data Returned for ' + target_res)
            fail(' Error ? - No Data Returned for ' + target_res)
          end
          return
        end

        if(source_res.length!=target_res.length)
          $link_path = ''
          if Dir.getwd.include?(@@CONFIG['JENKINS_JOB_NAME']) # specific for a jenkins url and job remove C:/Jenkins/jobs/CPT-Sanity/workspace/
            f ' Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + source_res.length.to_s  + ' Removed records in '+ target_schema if(source_res.length>target_res.length)
            f ' Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + target_res.length.to_s  + ' Added records in '+ target_schema if(target_res.length>source_res.length)
            source_file=Dir.getwd+'/'+results_dir+'/source_'+source_schema+'_'+tables[index].keys[0]+'.csv'
            target_file=Dir.getwd+'/'+results_dir+'/target_'+target_schema+'_'+tables[index].keys[0]+'.csv'
            $link_path_source = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +source_file
            $link_path_target = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +target_file
            $link_path_source.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
            $link_path_target.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
            f "Storing <a href='" + $link_path_source+"'>"+source_file.to_s+"</a> and <a href='"+$link_path_target+"'>" + target_file.to_s+"</a> in " +results_dir
          else
            f ' Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + source_res.length.to_s  + ' Removed records in '+ target_schema if(source_res.length>target_res.length)
            f ' Error ? - Diff Found - ' + tables[index].keys[0] + ' ' + target_res.length.to_s  + ' Added records in '+ target_schema if(target_res.length>source_res.length)
            source_file=Dir.getwd+results_dir+'/source_'+source_schema+'_'+tables[index].keys[0]+'.csv'
            target_file=Dir.getwd+results_dir+'/target_'+target_schema+'_'+tables[index].keys[0]+'.csv'
            f "Storing <a href='" + source_file+"'>"+source_file.to_s+"</a> and <a href='"+target_file+"'>" + target_file.to_s+"</a> in " +results_dir
          end

        else
          c tables[index].keys[0]+' matched in ' + source_schema + ' and ' + target_schema + ' schemas '
        end

        begin
          source_csv_filename = 'source_'+source_schema+'_'+tables[index].keys[0]+'.csv' #Source file
          target_csv_filename = 'target_'+target_schema+'_'+tables[index].keys[0]+'.csv'
=begin
        $file_csv=File.open(Dir.getwd+results_dir+'/'+source_csv_filename, 'w') do |file_line| #'/templates/db/'
          source_res.each{|rs_line|
            file_line.puts(rs_line)
          }
        end

        $file_csv=File.open(Dir.getwd+'/'+results_dir+'/'+target_csv_filename, 'w') do |file_line| #Target file '/templates/db/'
          target_res.each{|rs_line|
            file_line.puts(rs_line)
          }
        end
=end

          File.write(Dir.getwd+results_dir+'/'+source_csv_filename, convertHashMapToCsv(source_res))
          File.write(Dir.getwd+results_dir+'/'+target_csv_filename, convertHashMapToCsv(target_res))

        rescue Exception=>e
          @@scenario_fails.push('Exception in Save File or Empty table '+tables[index]+ ' - ' + e.message)
          f 'Exception in Save File or Empty table '+tables[index]+ ' - ' + e.message
          fail('Exception in Save File or Empty table '+tables[index]+ ' - '  + e.message)
        ensure
          #$file_csv.close if !$file_csv.nil?
        end



      }



    end



  def Actions.compareSdataDbTableResults(folder_timestamp)
      source_schema = @@CONFIG['ORACLE_SDATA_HOST_TEMPLATE_SCHEMA']#sdata1
      target_schema = @@CONFIG['ORACLE_SDATA_HOST_SCHEMA']#sdata
      results_dir = folder_timestamp.nil? ? @@CONFIG['ORACLE_TABLES_COMPARE_RESULTS_DIR'] : @@CONFIG['ORACLE_TABLES_COMPARE_RESULTS_DIR']+'/'+folder_timestamp
      self.WINCMD_NO_FAIL('cd ' +Dir.getwd+@@CONFIG['ORACLE_TABLES_COMPARE_RESULTS_DIR']+' & mkdir ' +  folder_timestamp, 10) #if(!folder_timestamp.nil?)
      @@db_timestamp_dir=true

      s_schema = self.getDbQueryResultsWithoutFailure4(source_schema,source_schema.to_s.downcase,"select * from "+source_schema+".SCHEMA_VERSION")
      s_schema_version=s_schema[0]['VERSION_NAME'].to_s
      s_schema_created=s_schema[0]['CREATION_TIME'].to_s
      t_schema = self.getDbQueryResultsWithoutFailure4(target_schema,target_schema.to_s.downcase,"select * from "+target_schema+".SCHEMA_VERSION")
      t_schema_version=t_schema[0]['VERSION_NAME'].to_s
      t_schema_created=t_schema[0]['CREATION_TIME'].to_s
      self.c '<b>Comparing Schema Versions - Old '+s_schema_version+' '+s_schema_created+ ' vs New '+t_schema_version+' '+t_schema_created +'</b>'
      self.setBuildProperty('APP_VERSION',t_schema_version.to_s)

      #
      $source_tables_count_query = "select table_name  from all_tables t where t.owner='"+source_schema+"'"
      $target_tables_count_query = "select table_name  from all_tables t where t.owner='"+target_schema+"'"

      $source_tables_count_query_res = self.getDbQueryResultsWithoutFailure4(source_schema,source_schema.to_s.downcase,$source_tables_count_query)
      v '$source_tables_count_query_res - ' + $source_tables_count_query_res.to_s
      $target_tables_count_query_res = self.getDbQueryResultsWithoutFailure4(target_schema,target_schema.to_s.downcase,$target_tables_count_query)
      v '$target_tables_count_query_res - ' + $target_tables_count_query_res.to_s
      if($source_tables_count_query_res.nil? || $source_tables_count_query_res.nil?)
        self.f(' Error  - No Data Returned for '+source_schema+' or '+target_schema+' schema')
        fail(' Error  - No Data Returned for '+source_schema+' or '+target_schema+' schema')
        return
      end

      if ($source_tables_count_query_res.length != $source_tables_count_query_res.length)
        self.f(' Error ? - ' + ($source_tables_count_query_res.length-$target_tables_count_query_res.length+1).to_s + ' Removed Tables - '+ ($source_tables_count_query_res-$target_tables_count_query_res).to_s)  if($source_tables_count_query_res.length > $target_tables_count_query_res.length)
        self.f(' Error ? - ' + ($target_tables_count_query_res.length-$source_tables_count_query_res.length+1).to_s + ' Added Tables - ' + ($target_cols-$source_tables_count_query_res).to_s) if( $target_tables_count_query_res.length>$source_tables_count_query_res.length)
      end
      #

      $excluded_types = @@CONFIG['ORACLE_SDATA_EXCLUDED_TYPES'].to_s.gsub!('[','')
      $excluded_types = $excluded_types.to_s.gsub!(']','')
      $excluded_types = $excluded_types.to_s.gsub!("\"",'\'')


      $excluded_tables = @@CONFIG['ORACLE_SDATA_EXCLUDED_TABLES'].to_s.gsub!('[','')
      $excluded_tables = $excluded_tables.to_s.gsub!(']','')
      $excluded_tables = $excluded_tables.to_s.gsub!("\"",'\'')


      $source_tables_query = "SELECT table_name FROM all_tables where owner = '"+source_schema+"'"
      $excluded_tables_query=''
      $excluded_tables.scan(/\w+/).each{ |t| $excluded_tables_query+=(" and table_name not like '" + t.to_s + "%' ") }   if(!$excluded_tables.nil?)
      $source_tables_query+=$excluded_tables_query  if(!$excluded_tables_query.empty?)

      $target_tables_query = "SELECT table_name FROM all_tables where owner = '"+target_schema+"'"
      $target_tables_query+=$excluded_tables_query  if(!$excluded_tables_query.empty?)
      target_tables = self.getSdataDbQueryResultsWithoutFailure($target_tables_query)
      tables = self.getSdataDbQueryResultsWithoutFailure($source_tables_query)
      v 'Source Tables - '+tables.to_s
      v 'Target Tables - '+target_tables.to_s

      if(tables.nil? || target_tables.nil?)
        @@scenario_fails.push('No compatible tables found')
        fail('No matching for tables found')
      end

      if(tables.length!=target_tables.length)
         if(tables.length>target_tables.length)
           self.f('<br> Error ? Missing tables : ')
               (tables-target_tables).each_with_index { |t, i|
                 self.f(t['TABLE_NAME'].to_s)
               }

         end

         if(target_tables.length>tables.length)
           self.f('<br> Error ? New/Added tables : ')
           (target_tables-tables).each_with_index{ |t,i |
             self.f(t['TABLE_NAME'].to_s)
           }

         end

      end

      $dif_tables=tables & target_tables
      #$dif_tables=tables  if($dif_tables.nil? || $dif_tables.length==0)
      $dif_tables.each_with_index { |table, index|
        $sql_query_source_diff=nil
        $sql_query_target_diff=nil

        $excluded_source_cols = nil
        $exclude_table_cols = nil
        $cols_excluded_source_query="SELECT * FROM  all_tab_columns WHERE  table_name = '" + $dif_tables[index]['TABLE_NAME'] +
            "'  AND owner = '"+source_schema+"' AND data_type NOT IN ("+$excluded_types+")" #" order by 1"

        $cols_excluded_target_query="SELECT * FROM  all_tab_columns WHERE  table_name = '" + $dif_tables[index]['TABLE_NAME'] +
            "'  AND owner = '"+target_schema+"' AND data_type NOT IN ("+$excluded_types+")"#" order by 1"
        target_res=self.getSdataDbQueryResultsWithoutFailure($cols_excluded_target_query)
        sres=self.getSdataDbQueryResultsWithoutFailure($cols_excluded_source_query)
        v 'Source after Excluding Columns for '+$dif_tables[index]['TABLE_NAME']+' - '+sres.to_s
        v 'Target after Excluding Columns for '+$dif_tables[index]['TABLE_NAME']+' - '+target_res.to_s

        next if(sres.nil? || target_res.nil?)

        if (target_res.length!=sres.length)
          if(sres.length>target_res.length)
            self.f('<br> Error ? Missing columns in ' + $dif_tables['TABLE_NAME'].to_s)
            (sres-target_res).each{ |c|  self.f(c['TABLE_NAME'].to_s) }
          end
          if(target_res.length>sres.length)
            self.f('<br> Error ? New/Added columns - in ' + $dif_tables['TABLE_NAME'].to_s)
            (target_res-sres).each{ |c| self.f(c['TABLE_NAME'].to_s)  }
          end
        end



        $source_fields=[]
        sres.each_with_index {|value,key|  $source_fields.push value['COLUMN_NAME']}
        $source_fields.sort!
        cols = !$source_fields.empty? ? $source_fields.join(","):"*"
        $cols_source_query = "SELECT "+cols+" FROM "+source_schema+"."+ $dif_tables[index]['TABLE_NAME']+
                             " minus "+
                             "SELECT "+cols+" FROM "+target_schema+"."+ $dif_tables[index]['TABLE_NAME']

        source_res=self.getSdataDbQueryResultsWithoutFailure($cols_source_query)

        $cols_target_query="SELECT COLUMN_NAME FROM  all_tab_columns WHERE  table_name = '" + $dif_tables[index]['TABLE_NAME'] +"'  AND owner = '"+target_schema+
                               "' AND data_type NOT IN ("+$excluded_types+") " #+" order by 1"

        tres=self.getSdataDbQueryResultsWithoutFailure($cols_target_query)
        $target_fields=[]
        tres.each_with_index {|value,key|  $target_fields.push value['COLUMN_NAME']}
        $target_fields.sort!
        cols = !$target_fields.empty? ? $target_fields.join(","):"*"
        $cols_target_query = "SELECT "+cols+" FROM "+target_schema+"."+ $dif_tables[index]['TABLE_NAME']+
                                 " minus "+
                                 "SELECT "+cols+" FROM "+source_schema+"."+ $dif_tables[index]['TABLE_NAME']
        target_res=self.getSdataDbQueryResultsWithoutFailure($cols_target_query)


        if((!source_res.nil? && !target_res.nil?) && (source_res.length!=target_res.length))
          $link_path = ''
          $time_stamp=Time.now.to_i.to_s
          if Dir.getwd.include?(@@CONFIG['JENKINS_JOB_NAME']) # specific for a jenkins url and job remove C:/Jenkins/jobs/CPT-Sanity/workspace/
            #f ' Error ? - Diff Found in ' + tables[index].keys[0].to_s + ' ' + source_res.length.to_s + ' records in '+ source_schema+ ' vs ' + target_res.length.to_s + ' records in ' +target_schema
            f ' Error ? - Diff Found - ' + $dif_tables[index].to_s + ' ' + source_res.length.to_s  + ' Missing records in '+ target_schema if(source_res.length>target_res.length)
            f ' Error ? - Diff Found - ' + $dif_tables[index].to_s + ' ' + target_res.length.to_s  + ' New records in '+ target_schema if(target_res.length>source_res.length)
            source_file=Dir.getwd+'/'+results_dir.to_s+'/source_'+source_schema+'_'+$dif_tables[index]['TABLE_NAME'].to_s+'.csv'
            target_file=Dir.getwd+'/'+results_dir.to_s+'/target_'+target_schema+'_'+$dif_tables[index]['TABLE_NAME'].to_s+'.csv'
            $link_path_source = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +source_file
            $link_path_target = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +target_file
            $link_path_source.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
            $link_path_target.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
            f "Storing <a href='" + $link_path_source+"'>"+source_file.to_s+"</a> and <a href='"+$link_path_target+"'>" + target_file.to_s+"</a> in " +results_dir
          else
            #f 'Error ? - Diff Found in ' + tables[index].keys[0].to_s + ' ' + source_res.length.to_s + ' records in '+ source_schema+ ' vs ' + target_res.length.to_s + ' records in ' +target_schema
            f ' Error ? - Diff Found - ' + tables[index].to_s + ' ' + source_res.length.to_s  + ' Missing records in '+target_schema  if(source_res.length>target_res.length)
            f ' Error ? - Diff Found - ' + tables[index].to_s + ' ' + target_res.length.to_s  + ' New records in '+ target_schema if(target_res.length>source_res.length)
            source_file=Dir.getwd+'/'+results_dir.to_s+'/source_'+source_schema+'_'+$dif_tables[index]['TABLE_NAME'].to_s+'.csv'
            target_file=Dir.getwd+'/'+results_dir.to_s+'/target_'+target_schema+'_'+$dif_tables[index]['TABLE_NAME'].to_s+'.csv'
            f "Storing <a href='" + source_file+"'>"+source_file.to_s+"</a> and <a href='"+target_file+"'>" + target_file.to_s+"</a> in " +results_dir
          end

            begin
              source_csv_filename = 'source_'+source_schema.to_s+'_'+$dif_tables[index]['TABLE_NAME']+'.csv' #Source file
              target_csv_filename = 'target_'+target_schema.to_s+'_'+$dif_tables[index]['TABLE_NAME']+'.csv'
              $file_csv=File.open(Dir.getwd+results_dir+'/'+source_csv_filename, 'w') do |file_line| #'/templates/db/'
                source_res.each{|rs_line|
                  file_line.puts(rs_line)
                }
              end

              $file_csv=File.open(Dir.getwd+results_dir+'/'+target_csv_filename, 'w') do |file_line| #Target file #'/templates/db/'
                target_res.each{|rs_line|
                  file_line.puts(rs_line)
                }
              end
            rescue Exception=>e
              @@scenario_fails.push(e.message)
              f 'Exception in Save File - ' + e.message
              fail('Exception in Save File - ' + e.message)
            ensure
              #$file_csv.close if !$file_csv.nil?
            end
        else
          c $dif_tables[index]['TABLE_NAME']+' matched in ' + source_schema + ' and ' + target_schema + ' schemas '
        end

      }

   end


  def Actions.convertHashMapToCsv(hashMap)
    hashes = hashMap
    column_names = hashes.first.keys
    csv_output=CSV.generate do |csv|
      csv << column_names
      hashes.each do |x|
        csv << x.values
      end
    end

    return csv_output.to_s if(!csv_output.nil? || !csv_output.to_s.empty?)
    return '' if(csv_output.nil? || csv_output.to_s.empty?)
  end




  def Actions.getDbQueryResultsWithoutFailure(query)
    host = @@CONFIG['ORACLE_HOST']
    port = @@CONFIG['ORACLE_HOST_PORT']
    service = @@CONFIG['ORACLE_HOST_SERVICE']
    usr = @@CONFIG['ORACLE_DB_USER']
    pwd = @@CONFIG['ORACLE_DB_PWD']

    v 'Connecting to ' + host.to_s+':'+port.to_s+'/'+service.to_s+' with ' +usr.to_s+'/'+pwd.to_s+'...'

    $query_results = nil
    begin
      dbh = DBI.connect('DBI:OCI8:'+host.to_s+':'+port.to_s+'/'+service.to_s,usr.to_s,pwd.to_s)
      sth = dbh.prepare(query)
      v 'Executing DB query: ' + query
      sth.execute()
      $row_count = 0
      $query_results =[]
          while row=sth.fetch_hash do
        $row_count+= 1
        # c row[0].to_s
        $query_results << row
      end

    rescue Exception => e
      f 'DB Exception ->'+e.message if (!e.nil?)
      @@scenario_fails.push('DB Exception ->'+e.message)
      #fail('DB Error  - ' + e.message) if (!e.nil?)
    ensure
      sth.finish if !dbh.nil?
      dbh.disconnect if dbh
    end

    return $query_results

  end




  def Actions.getDbQueryResultsWithoutFailure2(query)
    host = @@CONFIG['ORACLE_HOST_IP']
    port = @@CONFIG['ORACLE_HOST_PORT']
    service = @@CONFIG['ORACLE_HOST_SERVICE']
    usr = @@CONFIG['ORACLE_DB_USER']
    pwd = @@CONFIG['ORACLE_DB_PWD']

    v 'Connecting to ' + host.to_s+':'+port.to_s+'/'+service.to_s+' with ' +usr.to_s+'/'+pwd.to_s+'...'

    $query_results = nil
    begin
      dbh = DBI.connect('DBI:OCI8:'+host.to_s+':'+port.to_s+'/'+service.to_s,usr.to_s,pwd.to_s)
      sth = dbh.prepare(query)
      v 'Executing DB query: ' + query
      sth.execute()
      $row_count = 0
      $query_results =[]
      while row=sth.fetch_hash do
        $row_count+= 1
        # c row[0].to_s
        $query_results << row
      end

    rescue Exception => e
      f 'DB Exception ->'+e.message if (!e.nil?)
      @@scenario_fails.push('DB Exception ->'+e.message)
        #fail('DB Error  - ' + e.message) if (!e.nil?)
    ensure
      sth.finish if !dbh.nil?
      dbh.disconnect if dbh
    end

    return $query_results

  end


    def Actions.getDbQueryResultsWithoutFailure3(user, query)
      host = @@CONFIG['ORACLE_HOST']
      port = @@CONFIG['ORACLE_HOST_PORT']
      service = @@CONFIG['ORACLE_HOST_SERVICE']
      # usr = @@CONFIG['ORACLE_DB_USER']
      usr = user
      pwd = usr

      v 'Connecting to ' + host.to_s+':'+port.to_s+'/'+service.to_s+' with ' +usr.to_s+'/'+pwd.to_s+'...'

      $query_results = nil
      begin
        dbh = DBI.connect('DBI:OCI8:'+host.to_s+':'+port.to_s+'/'+service.to_s,usr.to_s,pwd.to_s)
        sth = dbh.prepare(query)
        v 'Executing DB query: ' + query
        sth.execute()
        $row_count = 0
        $query_results = []
        while row=sth.fetch_hash do
          $row_count+= 1
          # c row[0].to_s
          $query_results << row
        end

      rescue Exception => e
        f 'DB Exception ->'+e.message if (!e.nil?)
        @@scenario_fails.push('DB Exception ->'+e.message)
          #fail('DB Error  - ' + e.message) if (!e.nil?)
      ensure
        sth.finish if !dbh.nil?
        dbh.disconnect if dbh
      end

      return $query_results

    end



    def Actions.getDbQueryResultsWithoutFailure4(usr,pwd,query)
      host = @@CONFIG['ORACLE_HOST']
      port = @@CONFIG['ORACLE_HOST_PORT']
      service = @@CONFIG['ORACLE_HOST_SERVICE']

      v 'Connecting to ' + host.to_s+':'+port.to_s+'/'+service.to_s+' with ' +usr.to_s+'/'+pwd.to_s+'...'

      $query_results = nil
      begin
        dbh = DBI.connect('DBI:OCI8:'+host.to_s+':'+port.to_s+'/'+service.to_s,usr.to_s,pwd.to_s)
        sth = dbh.prepare(query)
        v 'Executing DB query: ' + query
        sth.execute()
        $row_count = 0
        $query_results =[]
        while row=sth.fetch_hash do
          $row_count+= 1
          # c row[0].to_s
          $query_results << row
        end

      rescue Exception => e
        f 'DB Exception ->'+e.message if (!e.nil?)
        @@scenario_fails.push('DB Exception ->'+e.message)
          #fail('DB Error  - ' + e.message) if (!e.nil?)
      ensure
        sth.finish if !dbh.nil?
        dbh.disconnect if dbh
      end

      return $query_results

    end





    def Actions.getSdataDbQueryResultsWithoutFailure(query)
      host = @@CONFIG['ORACLE_HOST']
      port = @@CONFIG['ORACLE_HOST_PORT']
      service = @@CONFIG['ORACLE_HOST_SERVICE']
      usr = @@CONFIG['ORACLE_SDATA_DB_USER']
      pwd = @@CONFIG['ORACLE_SDATA_DB_PWD']


      v 'Connecting to ' + host.to_s+':'+port.to_s+'/'+service.to_s+' with ' +usr.to_s+'/'+pwd.to_s+'...'

      $query_results = nil
      begin
        dbh = DBI.connect('DBI:OCI8:'+host.to_s+':'+port.to_s+'/'+service.to_s,usr.to_s,pwd.to_s)
        sth = dbh.prepare(query)
        v 'Executing DB query: ' + query
        sth.execute()
        $row_count = 0
        $query_results =[]
        while row=sth.fetch_hash do
          $row_count+= 1
          # c row[0].to_s
          $query_results << row
        end

      rescue Exception => e
        f 'DB Exception ->'+e.message if (!e.nil?)
        @@scenario_fails.push('DB Exception ->'+e.message)
          #fail('DB Error  - ' + e.message) if (!e.nil?)
      ensure
        sth.finish if !dbh.nil?
        dbh.disconnect if dbh
      end

      return $query_results

    end





  def Actions.getHashFromErFile(er_file_path)

    begin
      file =  File.read(er_file_path) #er_file_path 'libs/MSLErSender/data/Scenario0/er_test.txt'
      $condition1 = false
      $condition2 = false
      $condition3 = false
      $child_parent_key1 = ''
      $child_parent_key2 = ''
      $child_parent_key3 = ''
      $hash = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = {} } } #{}
      $index = 0
      file.gsub!(/{/, ":{")
      $arr = file.split(/\n/i)
      $arr.each { |row|
        if($arr[$index]=~/:[^{]/)
          parts = $arr[$index].split(/\:/)
          key = parts[0].sub!(/\s+/, "") || parts[0]
          value = parts[1].sub!(/\s+/, "") || parts[1]
          #value = value[1].gsub!(/\"+/, "") if value=~/\"/ #TODO in Step Validations



          $condition1 = true if (!$child_parent_key1.empty? && !value=~/{/ && !value=~/}/)
          $condition2 = true if (!$child_parent_key2.empty? && !value=~/{/ && !value=~/}/)
          $condition3 = true if (!$child_parent_key3.empty?  && !value=~/{/ && !value=~/}/)


          $hash[$child_parent_key1][$child_parent_key2][$child_parent_key3][key]  = value  if ($condition2 && $condition3)
          $hash[$child_parent_key1][$child_parent_key2][key] = value if ($condition2 && !$condition3)
          $hash[$child_parent_key1][key] = value  if ($condition1 && !$condition2)
          $hash[key] = value if (!$condition1 && !$condition2 && !$condition3)

        elsif ($arr[$index]=~/:{/)
          if (!$condition1)
            parts = $arr[$index].split(/:{/)
            $child_parent_key1 = parts[0].gsub!(/\s+/, "")
            $condition1 = true
          elsif ($condition1 && !$condition2)
            parts = $arr[$index].split(/:{/)
            $child_parent_key2 = parts[0].gsub!(/\s+/, "")
            $condition2 = true
          elsif ($condition1 && $condition2 && !$condition3)
            parts = $arr[$index].split(/:{/)
            $child_parent_key3 = parts[0].gsub!(/\s+/, "")
            $condition3 = true
          end

        elsif ($arr[$index]=~/}/)
          if ($condition1 && !$condition2 && !$condition3)
            $child_parent_key1 = ''
            $condition1 = false
          elsif ($condition1 && $condition2 && !$condition3)
            $child_parent_key2 = ''
            $condition2 = false
          elsif ($condition1 && $condition2 && $condition3)
            $child_parent_key3 = ''
            $condition3 = false
          end



        end
        $index+=1
      }

    rescue Exception => e
      @@scenario_fails.push(e.message)
      f e.message if (!e.nil?)
      fail('Unable to Parse/Serialize ER file ' + e.message)
    end

    return $hash

  end





  def Actions.uploadTemplates(host, user, pwd, local_dir, remote_dir)
        self.v 'Uploading Templates and Script folders and files from local ' + local_dir + ' into remote dir ' + remote_dir + ' on ' + host + ' for user '+user
        begin
          Net::SFTP.start(host, user,:password => pwd) do |sftp|
            #sleep 5
            sftp.upload!(local_dir, remote_dir)
            #sleep 5


          end
        rescue Exception=>e
          @@scenario_fails.push(e.message)
          f(e.message)
          fail(e.message)
        end
  end


    def Actions.uploadTemplates2(host, user, pwd, local_dir, remote_dir,timeout_sec)
     self.v 'Uploading Templates and Script folders and files from local ' + local_dir + ' into remote dir ' + remote_dir + ' on ' + host + ' for user '+user
     session_timeout = Integer(timeout_sec) rescue nil
     begin
        Net::SFTP.start(host, user,:password => pwd) do |sftp|
          if (session_timeout)
            timeout session_timeout do
              sftp.upload!(local_dir, remote_dir)
            end
          end
        end
      rescue Exception=>e
          @@scenario_fails.push(e.message)
          f(e.message)
          fail(e.message)
     end

     cmd = 'dos2unix '+remote_dir
     res = Actions.SSH(host, user, pwd, cmd, 15, true, '')
     end



  def Actions.rigthsForFile(host, user, pwd, path, file, rights_number)
    v 'Setting rights for '+host+':'+path+'/'+file
    cmd = 'dos2unix '+path+'/'+file+' && chmod '+rights_number+' '+path+'/'+file
    res = Actions.SSH(host, user, pwd, cmd, 15, true, '')

    cmd = 'ls -lA '+path+'/'+file
    res2 = Actions.SSH(host, user, pwd, cmd, 5, true, '')
    v 'Rights set: '+res2
  end


  def Actions.resetDownloadsLocalFolders()
          self.deleteFolderContents(Dir.getwd+@@CONFIG['MYT_CSV_LOCAL_TARGET_DIR_PATH'])
          self.deleteFolderContents(Dir.getwd+@@CONFIG['SAPPHIRE_JSON_LOCAL_TARGET_DIR_PATH'])
          self.deleteFolderContents(Dir.getwd+@@CONFIG['ORACLE_HOST_TABLES_FILES_DIR'])
  end



  def Actions.deleteFolderContents(folder_path)
        v 'Deleting Local Folder contents  -  ' + folder_path
        begin
          FileUtils.rm_rf(Dir.glob(folder_path+'/*'))
        rescue Exception => e
          @@scenario_fails.push(e.message)
          f e.message
          fail(e.message) if(!e.nil?)
        end
  end

  def Actions.downloadRemoteDir(host, user, pwd, remote_path, local_path, use_ssh = true)#TODO timeout
        v 'Downloading from remote '+host+':'+ remote_path  + ' into local ' + local_path
        begin
           Net::SFTP.start(host, user,:password => pwd) do |sftp|
           sftp.download!(remote_path,local_path,:recursive => true)
           end
        rescue Exception=>e
          @@scenario_fails.push(e.message)
          f(e.message)
          fail(e.message) if(!e.nil?)
        end
  end


  def Actions.downloadRemoteFile(host, user, pwd, remote_path, local_path, use_ssh = true)#TODO timeout
        v 'Downloading from remote '+host+':' + remote_path   + ' into local ' + local_path
        begin
          Net::SFTP.start(host, user,:password => pwd) do |sftp|
            sftp.download!(remote_path,local_path)
          end
        rescue Exception=>e
          @@scenario_fails.push(e.message)
          f(e.message)
          fail(e.message) if(!e.nil?)
        end
  end


  def Actions.transferFileRemotely(scpScript, host, user, pwd, host2, user2, pwd2, initial_path, target_path, file)
    c 'Transferring file '+host+':'+initial_path+'/'+file+' to '+host2+':'+target_path+' ...'

    if (host == host2 && user == user2)
      if pwd != pwd2
        @@scenario_fails.push('Error in transferring file(s): given hosts and users are the same, but the passwords are different: '+pwd+' and '+pwd2)
        fail('Error in transferring file(s): given hosts and users are the same, but the passwords are different: '+pwd+' and '+pwd2)
      end
      cmd = 'cp -f '+initial_path+'/'+file+' '+target_path
      res = Actions.SSH(host, user, pwd, cmd, 30, true, '')
    else
      cmd = 'chmod -R 776 '+target_path
      res = Actions.SSH(host2, user2, pwd2, cmd, 10, true, '')

      cmd =  'cd '+initial_path+' && ./'+scpScript+' '+'host2:'+host2+' '+'user2:'+user2+' '+'pwd2:'+pwd2+' '+'initial_path:'+initial_path+' '+'target_path:'+target_path+' '+'file:'+file
      res = Actions.SSH(host, user, pwd, cmd, 120, true, 'Copied successfully')
      Actions.v res.to_s
    end

  end


  def Actions.getFolderChecksum(local_dir)
        files = Dir["#{local_dir}/**/*"].reject{|f| File.directory?(f)}
        content = files.map{|f| File.read(f)}.join
        #require 'md5'
        r = Digest::MD5.md5(content).to_s
        v 'Folder Checksum - ' + r
   end


    def Actions.removeOldOutput
        self.removeOldFiles(Dir.getwd+'/tmp')
        self.removeOldFiles(Dir.getwd+'/logs')
        self.removeOldFiles(Dir.getwd+'/templates/myt')
        self.removeOldFiles(Dir.getwd+'/templates/common')
        self.removeOldFiles(Dir.getwd+'/templates/old_app_csv')
        self.removeOldFiles(Dir.getwd+'/templates/new_app_csv')
        self.removeOldFiles(Dir.getwd+'/templates/old_app_json')
        self.removeOldFiles(Dir.getwd+'/templates/new_app_json')
        self.removeOldFiles(Dir.getwd+'/templates/db')
    end


    def Actions.removeOldFiles(dir_path)
      arr_folders=Dir[dir_path+'/*'].reverse
      begin
        if(arr_folders.length>20)
          arr_folders.each_with_index { |f,i|
            FileUtils.rm_rf(f) if(i>4)
          }
        end

      rescue Exception => e

      end
    end


    def Actions.downloadCoreLogs(host, user, pwd)
      self.v "Downloading PTS logs for user " + user+"..."
      cmd = "cd /export/home/" + user +"/Automation/PTS/logs && rm -rf ../PTSlogs_"+user+" && mkdir -p ../PTSlogs_"+user+" && \\cp -f *.log ../PTSlogs_"+user+" 2>/dev/null"
      self.SSH(host, user, pwd, cmd, 120, false, '')
      sleep 10
      self.downloadRemoteDir(host, user, pwd,'/export/home/'+user+'/Automation/PTS/PTSlogs_'+user ,Dir.getwd+'/logs/logs_'+@@time_stamp+'/'+user)
    end


    def Actions.displayFilesForDownloadInFolder(folder_path)
      if(File.directory?(folder_path))
        Actions.c 'Displaying logs from folder '+folder_path
        Dir.foreach(folder_path) {|file_name|
          displayFileLinkInReport(folder_path+'/'+file_name) if(File.file?(folder_path+'/'+file_name) )
          Actions.displayFilesForDownloadInFolder(folder_path+'/'+file_name) if(!file_name.to_s.include?('.')  && File.directory?(folder_path+'/'+file_name) && Dir.entries(folder_path+'/'+file_name).size>2)
        }
      else
         displayFileLinkInReport(folder_path) if(File.file?(folder_path))
      end

    end



    def Actions.displayFileLinkInReport(file_path)
      begin
        $file = File.new(file_path)
      ensure
        $link_path = ''
        if file_path.include?(@@CONFIG['JENKINS_JOB_NAME'])
          $link_path = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +File.dirname(file_path)+ '/'+ File.basename(file_path)
          $link_path.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
        else
          $link_path = file_path
        end
        c "File  <a href='" + $link_path.to_s+"'>"+$link_path.to_s+ " Click to View or Download </a>" if !$file.nil?
        $file.close if !$file.nil?
      end

      return $file
    end



    def Actions.getHashMapFromCsvFile(file_path)
      begin
        file_csv = File.new(file_path)
        $csv_file_hash =[]
        csv = CSV.new(file_csv, :headers => true) #, :header_converters => :symbol, :converters => [:all, :blank_to_nil])
        csv.to_a.map {|row|
          csv_row_hash = row.to_hash
          $csv_file_hash.push(csv_row_hash)
        }
        #c 'csv_file_hash ' + $csv_file_hash.to_s
      rescue Exception => e
        @@scenario_fails.push(e.message)
        f e.message if (!e.nil?)
        fail('CSV file Error  - ' + e.message) if (!e.nil?)
      ensure
        $link_path = ''
        if file_path.include?(@@CONFIG['JENKINS_JOB_NAME'])
           $link_path = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +File.dirname(file_path)+ '/'+ File.basename(file_path)
           $link_path.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
        else
           $link_path = file_path
        end
        #c "File  <a href='" + $link_path.to_s+"'>"+file_path.to_s+"</a>"  + ' being parsed' if !file_csv.nil? #TODO to remove on fail
        file_csv.close if !file_csv.nil?
      end

      return $csv_file_hash
  end


  def Actions.compareHashMapsFromCsvFiles(source, target, source_file_path, target_file_path)
      $excluded_keys =  @@CONFIG['MYT_CSV_EXCLUDED_COLUMNS'] #['TICKET_ID','DEAL_DATE']
      $csv_compare_errors = []

#disabled -> checked by caller
=begin
      if(File.basename(source_file_path)!=File.basename(target_file_path))
        errMsg = File.basename(source_file_path) + ' file is missing in target '
        $csv_compare_errors.push({'ErrorMsg'=>errMsg})
        @@scenario_fails.push({'ErrorMsg'=>errMsg})
        f('Error: Mismatch Found ' + File.basename(source_file_path) + ' file is missing in target ' )

        return $csv_compare_errors
      end
=end

      if source_file_path.include?(@@CONFIG['JENKINS_JOB_NAME']) # specific  for jenkins and job remove /C:/Jenkins/jobs/CPT-Sanity/workspace
        $link_path_source = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +File.dirname(source_file_path)+'/'+ File.basename(source_file_path)
        $link_path_target = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +File.dirname(target_file_path)+'/'+ File.basename(target_file_path)
        $link_path_source.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
        $link_path_target.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
      else
        $link_path_source = source_file_path
        $link_path_target = target_file_path
      end


        if (source.length != target.length)
        errMsg = ' Error ? - Expected ' + source.length.to_s + ' rows but Actual is ' +  target.length.to_s + ' in '+ target_file_path
        $csv_compare_errors.push(errMsg)
        @@scenario_fails.push(errMsg)

        f(' Error ? - Mismatch Found ')
        $csv_compare_errors.each { |entry|  f(entry.to_s)} if(!$csv_compare_errors.nil? && !$csv_compare_errors.empty?)
        f "Source File  <a href='" + $link_path_source.to_s+"'>"+source_file_path.to_s+" Click to View or Download</a>" if(File.file?(source_file_path))
        f "Target File  <a href='" + $link_path_target.to_s+"'>"+target_file_path.to_s+" Click to View or Download</a>" if(File.file?(target_file_path))
        return $csv_compare_errors
      end



      source.length.times{ |row|
        if (source[row].size!=target[row].size)
          errMsg = ' Error ? - Expected amount columns in source ' + source[row].size.to_s + ' but Actual columns amount is ' +  target[row].size.to_s + ' in target'  if (source[row].size!=target[row].size)
        end

        if((source[row].keys-target[row].keys).length>0)
          errMsg<<'<br> Removed columns'
          cols=''
          (source[row].keys-target[row].keys).each{|k| cols<<('<br>     '+k)}
          errMsg<<cols+ ' in Source'

        end
        if((target[row].keys-source[row].keys).length>0)
            errMsg<<'<br> Added columns'
            cols=''
            (target[row].keys-source[row].keys).each{|k| cols<<('<br>     '+k)}
            errMsg<<cols+ ' in Target'

        end

        errMsg+='<br><br> View or Download files with Diff below' if(!errMsg.nil? && !errMsg.to_s.empty?)
        $csv_compare_errors.push(errMsg) if(!errMsg.nil? && !errMsg.to_s.empty?)
        if($csv_compare_errors.length>0)

          @@scenario_fails.push($csv_compare_errors.to_s)
          f(' Error ? - Mismatch Found')
          $csv_compare_errors.each { |entry|  f(entry.to_s)} if(!$csv_compare_errors.nil? && !$csv_compare_errors.empty?)
          f "Source File  <a href='" + $link_path_source.to_s+"'>"+source_file_path.to_s+" Click to View or Download</a>" if(File.file?(source_file_path))
          f "Target File  <a href='" + $link_path_target.to_s+"'>"+target_file_path.to_s+" Click to View or Download</a>" if(File.file?(target_file_path))
        end

        return $csv_compare_errors if($csv_compare_errors.length>0)

      }


      source.length.times{ |row|
        source[row].size.times { |column|
           if(source[row].values[column].to_s != target[row].values[column].to_s &&  !$excluded_keys.include?(target[row].keys[column].to_s.upcase))
             errMsg = 'Line Num: '+(row+2).to_s+' Expected value ' + source[row].values[column].to_s + ' for ' + source[row].keys[column].to_s+' but Actual is ' +  target[row].values[column].to_s + ' in '+ target_file_path
             $csv_compare_errors.push(errMsg)
             @@scenario_fails.push(errMsg)
           end
        }
      }


      if (!$csv_compare_errors.nil? && !$csv_compare_errors.empty?)
        f('Error: Mismatch Found ')
        #f('Template file: ' + source.to_s)
        #f('Actual file: ' + target.to_s)
        f "Source File  <a href='" + $link_path_source.to_s+"'>"+source_file_path.to_s+" Click to View or Download</a>" if(File.file?(source_file_path))
        f "Target File  <a href='" + $link_path_target.to_s+"'>"+target_file_path.to_s+" Click to View or Download</a>" if(File.file?(target_file_path))
        $csv_compare_errors.each { |entry|  f(entry.to_s)}
      end

      return $csv_compare_errors
  end




    def Actions.compareHashMapsFromCsvFiles2(source, target, source_file_path, target_file_path,excluded_fields_arr)
      $excluded_keys =  excluded_fields_arr
      $csv_compare_errors = []

      if source_file_path.include?(@@CONFIG['JENKINS_JOB_NAME'])
        $link_path_source = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +File.dirname(source_file_path)+'/'+ File.basename(source_file_path)
        $link_path_target = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +File.dirname(target_file_path)+'/'+ File.basename(target_file_path)
        $link_path_source.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
        $link_path_target.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
      else
        $link_path_source = source_file_path
        $link_path_target = target_file_path
      end


      if (source.length != target.length)
        errMsg = ' Error ? - Expected ' + source.length.to_s + ' rows but Actual is ' +  target.length.to_s + ' in '+ target_file_path
        $csv_compare_errors.push(errMsg)
        @@scenario_fails.push(errMsg)

        f(' Error ? - Mismatch Found ')
        $csv_compare_errors.each { |entry|  f(entry.to_s)} if(!$csv_compare_errors.nil? && !$csv_compare_errors.empty?)
        f "Source File  <a href='" + $link_path_source.to_s+"'>"+source_file_path.to_s+" Click to View or Download</a>" if(File.file?(source_file_path))
        f "Target File  <a href='" + $link_path_target.to_s+"'>"+target_file_path.to_s+" Click to View or Download</a>" if(File.file?(target_file_path))
        return $csv_compare_errors
      end



      source.length.times{ |row|
        if (source[row].size!=target[row].size)
          errMsg = ' Error ? - Expected amount columns in source ' + source[row].size.to_s + ' but Actual columns amount is ' +  target[row].size.to_s + ' in target'  if (source[row].size!=target[row].size)
        end

        if((source[row].keys-target[row].keys).length>0)
          errMsg<<'<br> Removed columns'
          cols=''
          (source[row].keys-target[row].keys).each{|k| cols<<('<br>     '+k)}
          errMsg<<cols+ ' in Source'

        end
        if((target[row].keys-source[row].keys).length>0)
          errMsg<<'<br> Added columns'
          cols=''
          (target[row].keys-source[row].keys).each{|k| cols<<('<br>     '+k)}
          errMsg<<cols+ ' in Target'

        end

        errMsg+='<br><br> View or Download files with Diff below' if(!errMsg.nil? && !errMsg.to_s.empty?)
        $csv_compare_errors.push(errMsg) if(!errMsg.nil? && !errMsg.to_s.empty?)
        if($csv_compare_errors.length>0)

          @@scenario_fails.push($csv_compare_errors.to_s)
          f(' Error ? - Mismatch Found')
          $csv_compare_errors.each { |entry|  f(entry.to_s)} if(!$csv_compare_errors.nil? && !$csv_compare_errors.empty?)
          f "Source File  <a href='" + $link_path_source.to_s+"'>"+source_file_path.to_s+" Click to View or Download</a>" if(File.file?(source_file_path))
          f "Target File  <a href='" + $link_path_target.to_s+"'>"+target_file_path.to_s+" Click to View or Download</a>" if(File.file?(target_file_path))
        end

        return $csv_compare_errors if($csv_compare_errors.length>0)

      }


      source.length.times{ |row|
        source[row].size.times { |column|
          if(source[row].values[column].to_s != target[row].values[column].to_s &&  !$excluded_keys.include?(target[row].keys[column].to_s.upcase))
            errMsg = 'Line Num: '+(row+2).to_s+' Expected value ' + source[row].values[column].to_s + ' for ' + source[row].keys[column].to_s+' but Actual is ' +  target[row].values[column].to_s + ' in '+ target_file_path
            $csv_compare_errors.push(errMsg)
            @@scenario_fails.push(errMsg)
          end
        }
      }


      if (!$csv_compare_errors.nil? && !$csv_compare_errors.empty?)
        f('Error: Mismatch Found ')
        #f('Template file: ' + source.to_s)
        #f('Actual file: ' + target.to_s)
        f "Source File  <a href='" + $link_path_source.to_s+"'>"+source_file_path.to_s+" Click to View or Download</a>" if(File.file?(source_file_path))
        f "Target File  <a href='" + $link_path_target.to_s+"'>"+target_file_path.to_s+" Click to View or Download</a>" if(File.file?(target_file_path))
        $csv_compare_errors.each { |entry|  f(entry.to_s)}
      end

      return $csv_compare_errors
    end





  def Actions.compareCsvDirs(source_dir, target_dir)
       $csv_folders_count=0
       $csv_compare_errors=[]
       errMsg = nil
       begin


         if(source_dir.nil?)
           errMsg<<(" Empty Source Folder")
           $csv_compare_errors.push(errMsg)
           @@scenario_fails.push(errMsg)
           f(errMsg)
           return $csv_compare_errors
         end


         if(target_dir.nil?)
           errMsg<<(" Empty Target Folder")
           $csv_compare_errors.push(errMsg)
           @@scenario_fails.push(errMsg)
           f(errMsg)
           return $csv_compare_errors
         end



       if Dir.entries(source_dir).length != Dir.entries(target_dir).length
         #f(' Error: Mismatch Found ')# +' Expected ' + Dir.entries(source_dir).length.to_s + ' csv files/folders , Actual is ' + Dir.entries(target_dir).length.to_s )
         errMsg = ' Error  - Mismatch Found Expected amount of  ' + (Dir.entries(source_dir).length-2).to_s + ' of CSV files in Source dir but Actual is ' + (Dir.entries(target_dir).length-2).to_s+' in Target dir '
         errMsg<<("<br>Missing Files or Folders in Source dir "+File.basename(source_dir).to_s+": "+(Dir.entries(source_dir)-Dir.entries(target_dir)).to_s) if Dir.entries(source_dir).length > Dir.entries(target_dir).length
         errMsg<<("<br>New Files or Folders in Target dir "+File.basename(target_dir).to_s+": "+(Dir.entries(target_dir)-Dir.entries(source_dir)).to_s) if Dir.entries(target_dir).length > Dir.entries(source_dir).length
         $csv_compare_errors.push(errMsg)
         @@scenario_fails.push(errMsg)
         f(errMsg)
         return $csv_compare_errors
       end


       excluded_keys =  @@CONFIG['MYT_CSV_EXCLUDED_COLUMNS']
       self.c('Comparing CSV files [Source vs Target] in Common and MyT folders excluding fields: ' + excluded_keys.to_s) if(!$printed)
       $printed=true

       local_files = Dir.entries(source_dir)
       target_files = Dir.entries(target_dir)
       local_files.length.times{ |filename|
         if  (!File.directory?(source_dir+'/'+local_files[filename]))
           s=local_files[filename].split('.')
           file_pattern=s[0]
           search_file = File.basename(Dir.glob("#{target_dir}/**/#{file_pattern}*.csv").to_s)
           search_file.gsub!("[]","")
           search_file.gsub!("\"]","")

           if(search_file.kind_of?(Array) && search_file.length>1)
             $csv_compare_errors.push(search_file + '*.csv duplicate files with '+file_pattern+' pattern are  Found in Target dir ' )
             @@scenario_fails.push(search_file + '*.csv duplicate files with '+file_pattern+' pattern are  Found in Target dir ' )
             f search_file + '*.csv duplicate files with '+file_pattern+' pattern are  Found in Target dir '
             return $csv_compare_errors
           end

           if(search_file.nil? || search_file.to_s.empty?)
              $csv_compare_errors.push(file_pattern + '*.csv is Not Found in Target dir ' )
              @@scenario_fails.push(file_pattern + '*.csv is Not Found in Target dir ' )
              f file_pattern + '*.csv is Not Found in Target dir '
              return $csv_compare_errors
           end

           source_hash = getHashMapFromCsvFile(source_dir + '/' + local_files[filename])
           target_hash = getHashMapFromCsvFile(target_dir + '/' + search_file) #target_files[filename]
           compareHashMapsFromCsvFiles(source_hash, target_hash, source_dir + '/' + local_files[filename], target_dir + '/' + search_file) #(source_hash, target_hash) #()target_hash, source_hash) odd rows for target are matched
           v local_files[filename] + ' vs ' + search_file + ' csv files being compared'
           $csv_files_count=0 if($csv_files_count.nil?)
           $csv_files_count+=1 if(!$csv_files_count.nil?)
         else
           compareCsvDirs(source_dir+'/'+local_files[filename], target_dir+'/'+local_files[filename]) if(local_files[filename]!='.' && local_files[filename]!='..')
           $csv_folders_count+=1
         end

         Actions.v $csv_files_count.to_s+' files have been compared so far, current dir is ' + source_dir  if(!$csv_files_count.nil?)
       }
       rescue Exception=>e
         #$csv_compare_errors.push(e.message)
         #@@scenario_fails.push(e.message)
         v 'Error in CSV compare - ' + e.message if(!e.message.nil?)
         f $csv_compare_errors.to_s if($csv_compare_errors.length>0)

       end


  end


    def Actions.compareCsvDirs2(source_dir,target_dir,excluded_fields_arr)
      $csv_folders_count=0
      $csv_compare_errors=[]
      errMsg = nil
      begin


        if(source_dir.nil?)
          errMsg<<(" Empty Source Folder")
          $csv_compare_errors.push(errMsg)
          @@scenario_fails.push(errMsg)
          f(errMsg)
          return $csv_compare_errors
        end


        if(target_dir.nil?)
          errMsg<<(" Empty Target Folder")
          $csv_compare_errors.push(errMsg)
          @@scenario_fails.push(errMsg)
          f(errMsg)
          return $csv_compare_errors
        end



        if Dir.entries(source_dir).length != Dir.entries(target_dir).length
          #f(' Error: Mismatch Found ')# +' Expected ' + Dir.entries(source_dir).length.to_s + ' csv files/folders , Actual is ' + Dir.entries(target_dir).length.to_s )
          errMsg = ' Error  - Mismatch Found Expected amount of  ' + (Dir.entries(source_dir).length-2).to_s + ' of CSV files in Source dir but Actual is ' + (Dir.entries(target_dir).length-2).to_s+' in Target dir '
          errMsg<<("<br>Missing Files or Folders in Source dir "+File.basename(source_dir).to_s+": "+(Dir.entries(source_dir)-Dir.entries(target_dir)).to_s) if Dir.entries(source_dir).length > Dir.entries(target_dir).length
          errMsg<<("<br>New Files or Folders in Target dir "+File.basename(target_dir).to_s+": "+(Dir.entries(target_dir)-Dir.entries(source_dir)).to_s) if Dir.entries(target_dir).length > Dir.entries(source_dir).length
          $csv_compare_errors.push(errMsg)
          @@scenario_fails.push(errMsg)
          f(errMsg)
          return $csv_compare_errors
        end


        excluded_keys =  excluded_fields_arr
        self.c('Comparing CSV files [Source vs Target] in '+source_dir+' folders excluding fields: ' + excluded_keys.to_s) if(!$printed)
        $printed=true

        local_files = Dir.entries(source_dir)
        target_files = Dir.entries(target_dir)
        local_files.length.times{ |filename|
          if  (!File.directory?(source_dir+'/'+local_files[filename]))
            s=local_files[filename].split('.')
            file_pattern=s[0]
            search_file = File.basename(Dir.glob("#{target_dir}/**/#{file_pattern}*.csv").to_s)
            search_file.gsub!("[]","")
            search_file.gsub!("\"]","")

            if(search_file.kind_of?(Array) && search_file.length>1)
              $csv_compare_errors.push(search_file + '*.csv duplicate files with '+file_pattern+' pattern are  Found in Target dir ' )
              @@scenario_fails.push(search_file + '*.csv duplicate files with '+file_pattern+' pattern are  Found in Target dir ' )
              f search_file + '*.csv duplicate files with '+file_pattern+' pattern are  Found in Target dir '
              return $csv_compare_errors
            end

            if(search_file.nil? || search_file.to_s.empty?)
              $csv_compare_errors.push(file_pattern + '*.csv is Not Found in Target dir ' )
              @@scenario_fails.push(file_pattern + '*.csv is Not Found in Target dir ' )
              f file_pattern + '*.csv is Not Found in Target dir '
              return $csv_compare_errors
            end

            source_hash = getHashMapFromCsvFile(source_dir + '/' + local_files[filename])
            target_hash = getHashMapFromCsvFile(target_dir + '/' + search_file)
            compareHashMapsFromCsvFiles2(source_hash, target_hash, source_dir + '/' + local_files[filename], target_dir + '/' + search_file,excluded_fields_arr)
            v local_files[filename] + ' vs ' + search_file + ' csv files being compared'
            $csv_files_count=0 if($csv_files_count.nil?)
            $csv_files_count+=1 if(!$csv_files_count.nil?)
          else
            compareCsvDirs2(source_dir+'/'+local_files[filename], target_dir+'/'+local_files[filename]) if(local_files[filename]!='.' && local_files[filename]!='..')
            $csv_folders_count+=1
          end

          Actions.v $csv_files_count.to_s+' files have been compared so far, current dir is ' + source_dir  if(!$csv_files_count.nil?)
        }
      rescue Exception=>e
        v 'Error in CSV compare - ' + e.message if(!e.message.nil?)
        f $csv_compare_errors.to_s if($csv_compare_errors.length>0)

      end


    end





    def Actions.compareSaphireOutputJsons(source_file, target_file)
       $json_compare_errors = []
       begin
        source_arr = getJsonArrayFromFile(source_file)
        target_arr = getJsonArrayFromFile(target_file)

        exclusion = @@CONFIG['SAPPHIRE_JSON_EXCLUDED_FIELDS'] #[] #"sequence"
        $link_path_source = ''
        $link_path_target = ''
        if source_file.include?(@@CONFIG['JENKINS_JOB_NAME']) # specific  for jenkins and job remove /C:/Jenkins/jobs/CPT-Sanity/workspace
          $link_path_source = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +File.dirname(source_file)+ '/'+ File.basename(source_file)
          $link_path_target = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +File.dirname(target_file)+ '/'+ File.basename(target_file)
          $link_path_source.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
          $link_path_target.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
        else
            $link_path_source = source_file
            $link_path_target = target_file
        end

        self.c("Comparing     <b>Source</b> file:<a href='" +$link_path_source.to_s+"'>"+source_file.to_s+"</a>     <b>Target</b> file: <a href='" + $link_path_target.to_s+"'>"+target_file.to_s+"</a>")
        self.c('Excluded fields in compare ' + exclusion.to_s)

        if (source_arr.length<=2  )
          $json_compare_errors.push('Source json doesnt contains valid data rows')
          @@scenario_fails.push('Source json doesnt contains valid data rows')
          #self.f('Source json doesnt contains valid data rows')
        end

        if (target_arr.length<=2 )
          $json_compare_errors.push('Target json doesnt contains valid data rows')
          @@scenario_fails.push('Target json doesnt contains valid data rows')
          #self.f('Target json doesnt contains valid data rows')
        end

        if (source_arr.length!=target_arr.length )
          $json_compare_errors.push('Source contains '+source_arr.length.to_s+' rows, Target contains ' +  target_arr.length .to_s + ' rows ')
          @@scenario_fails.push('Source contains '+source_arr.length.to_s+' rows, Target contains ' +  target_arr.length .to_s + ' rows ')
          #break
        end



        if ((source_arr[0]['data'].keys-target_arr[0]['data'].keys).length>0)
          cols=''
          (source_arr[0]['data'].keys-target_arr[0]['data'].keys).each{|k| cols<<'<br>     '+k}
          f ' Error ? - Removed Fields ' +cols if(!cols.to_s.empty?)
        end



        if ((target_arr[0]['data'].keys-source_arr[0]['data'].keys).length>0)
          cols=''
          (target_arr[0]['data'].keys-source_arr[0]['data'].keys).each{|k| cols<<'<br>     '+k}
          f ' Error ? - Added Fields ' +cols if(!cols.to_s.empty?)
        end




        if ($json_compare_errors.empty?)
          source_arr.each_index{ |row|
              source_h = getCountHashFields(source_arr[row])
              target_h = getCountHashFields(target_arr[row])
              $escape_diff = false
              if (source_h['count']!=target_h['count'])
                $json_compare_errors.push('Source Row '+row.to_s+' contains '+source_h['count'].to_s+' fields, Target contains  '+ target_h['count'].to_s + ' fields')
                $json_compare_errors.push('Source Row '+row.to_s+' Fields Removed -' + (source_h['fields']-target_h['fields']).to_s ) if !(source_h['fields']-target_h['fields']).empty?
                $json_compare_errors.push('Target Row '+row.to_s+' Fields Added -' + (target_h['fields']-source_h['fields']).to_s ) if !(target_h['fields']-source_h['fields']).empty?
                #v('Source Row '+row.to_s+' Fields Removed -' + (source_h['fields']-target_h['fields']).to_s ) if !(source_h['fields']-target_h['fields']).empty?
                #v('Target Row '+row.to_s+' Fields Added -' + (target_h['fields']-source_h['fields']).to_s ) if !(target_h['fields']-source_h['fields']).empty?


                $escape_diff = true
              end

              result = !$escape_diff ? JsonCompare.get_diff(source_arr[row], target_arr[row], exclusion) : ''
              if (!result.empty? )
                  # c result.to_s
                  $json_compare_errors.push('Source Row  '+(row+1).to_s+' - '+ result.to_s) if (!result.empty?)
                  @@scenario_fails.push('Source Row  '+(row+1).to_s+' - '+ result.to_s) if (!result.empty?)
              end

          }
        end


       if (!$json_compare_errors.nil? && !$json_compare_errors.empty?)
         f('Error: Mismatch Found ')
         f("Source file: <a href='" + $link_path_source.to_s+"'>"+source_file.to_s+"</a>")
         f("Target file:  <a href='" + $link_path_target.to_s+"'>"+target_file.to_s+"</a>")
         $json_compare_errors.each { |entry|  f(entry.to_s)}
       end

        rescue Exception=>e
          $json_compare_errors.push(e.message)
          @@scenario_fails.push(e.message)
          f $json_compare_errors.to_s
        end

       return $json_compare_errors

  end


    def Actions.compareSaphireOutputJsonsForUpgrade(source_file, target_file)
      $json_compare_errors = []
      begin
        getJsonArrayFromFile(source_file)
      rescue Exception=>e
        @@scenario_fails.push(e.message)
      end

      begin
        source_arr = JSON.parse(File.read(source_file)) #source_file #getJsonArrayFromFile(source_file)
        target_arr = JSON.parse(File.read(target_file))

        exclusion = @@CONFIG['SAPPHIRE_JSON_EXCLUDED_FIELDS'] #[] #"sequence"
        $link_path_source = ''
        $link_path_target = ''
        if source_file.include?(@@CONFIG['JENKINS_JOB_NAME']) # specific  for jenkins and job remove /C:/Jenkins/jobs/CPT-Sanity/workspace
          $link_path_source = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +File.dirname(source_file)+ '/'+ File.basename(source_file)
          $link_path_target = @@CONFIG['JENKINS_URL'].to_s+'/job/'+@@CONFIG['JENKINS_JOB_NAME']+'/ws/' +File.dirname(target_file)+ '/'+ File.basename(target_file)
          $link_path_source.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
          $link_path_target.gsub!('C:/Jenkins/jobs/'+@@CONFIG['JENKINS_JOB_NAME']+'/workspace/','')
        else
          $link_path_source = source_file
          $link_path_target = target_file
        end

        self.c("Comparing  Jsons   <b>Source</b> file:<a href='" +$link_path_source.to_s+"'>"+source_file.to_s+"</a>     <b>Target</b> file: <a href='" + $link_path_target.to_s+"'>"+target_file.to_s+"</a>")
        self.c('Excluded fields in compare ' + exclusion.to_s)

        if (source_arr.length<=2  )
          $json_compare_errors.push('Source json doesnt contains valid data rows')
          @@scenario_fails.push('Source json doesnt contains valid data rows')
          #self.f('Source json doesnt contains valid data rows')
        end

        if (target_arr.length<=2 )
          $json_compare_errors.push('Target json doesnt contains valid data rows')
          @@scenario_fails.push('Target json doesnt contains valid data rows')
          #self.f('Target json doesnt contains valid data rows')
        end

        if (source_arr.length!=target_arr.length )
          $json_compare_errors.push('Source contains '+source_arr.length.to_s+' rows, Target contains ' +  target_arr.length .to_s + ' rows ')
          @@scenario_fails.push('Source contains '+source_arr.length.to_s+' rows, Target contains ' +  target_arr.length .to_s + ' rows ')
          #break
        end

        if ((source_arr[0]['data'].keys-target_arr[0]['data'].keys).length>0)
        cols=''
        (source_arr[0]['data'].keys-target_arr[0]['data'].keys).each{|k| cols<<'<br>     '+k}
         f ' Error ? - Removed Fields ' +cols if(!cols.to_s.empty?)
        end



        if ((target_arr[0]['data'].keys-source_arr[0]['data'].keys).length>0)
          cols=''
          (target_arr[0]['data'].keys-source_arr[0]['data'].keys).each{|k| cols<<'<br>     '+k}
          f ' Error ? - Added Fields  ' +cols if(!cols.to_s.empty?)
        end



        if ($json_compare_errors.empty?)
          source_arr.each_index{ |row|
            source_h = getCountHashFields(source_arr[row])
            target_h = getCountHashFields(target_arr[row])
            $escape_diff = false
            if (source_h['count']!=target_h['count'])
              $json_compare_errors.push('Source Row '+row.to_s+' contains '+source_h['count'].to_s+' fields, Target contains  '+ target_h['count'].to_s + ' fields')
              $json_compare_errors.push('Target Row '+row.to_s+' Fields Diff -' + (source_h['fields']-target_h['fields']).to_s ) if !(source_h['fields']-target_h['fields']).empty?
              $json_compare_errors.push('Target Row '+row.to_s+' Fields Diff -' + (target_h['fields']-source_h['fields']).to_s ) if !(target_h['fields']-source_h['fields']).empty?
              #v('Source Row '+row.to_s+' Fields Removed -' + (source_h['fields']-target_h['fields']).to_s ) if !(source_h['fields']-target_h['fields']).empty?
              #v('Target Row '+row.to_s+' Fields Added -' + (target_h['fields']-source_h['fields']).to_s ) if !(target_h['fields']-source_h['fields']).empty?
              $escape_diff = true
            end
            result = !$escape_diff ? JsonCompare.get_diff(source_arr[row], target_arr[row], exclusion) : ''
            if (!result.empty? )
              # c result.to_s
              $json_compare_errors.push('Target Row  '+(row+1).to_s+' - '+ result.to_s) if (!result.empty?)
              @@scenario_fails.push('Target Row  '+(row+1).to_s+' - '+ result.to_s) if (!result.empty?)
            end

          }
        end


        if (!$json_compare_errors.nil? && !$json_compare_errors.empty?)
          f('Error: Mismatch Found ')
          f("Source file: <a href='" + $link_path_source.to_s+"'>"+source_file.to_s+"</a>")
          f("Target file:  <a href='" + $link_path_target.to_s+"'>"+target_file.to_s+"</a>")
          $json_compare_errors.each { |entry|  f(entry.to_s)}
        end

      rescue Exception=>e
        $json_compare_errors.push(e.message)
        @@scenario_fails.push(e.message)
        f $json_compare_errors.to_s
      end

      return $json_compare_errors

    end



  def Actions.getJsonArrayFromFile(file_path)
        json_arr = []
        json_file = file_path   #File.expand_path('../../redis_output.txt', __FILE__)
        text = File.read(json_file)

        text.gsub!('\\\\\\','')
        text.gsub!('\\','')
        text.gsub!('/','')
        #text.gsub!('=>',':')

        text.each_line { |line|
          # puts 'line - ' +line
        }
        json_list = text.scan(/{\"(.*?)}}/)
            #puts 'JsonList - ' + json_list.to_s
        json_list.each { |row|
        json_obj = JSON.parse('{"'+row[0].to_s+'}}')
            #puts 'JsonObj - ' +json_obj.to_s
        json_arr.push(json_obj)

        json_format=json_arr.to_s
        json_format.gsub!('=>',':')
        File.write(json_file, json_format)
        }

        return json_arr
  end



  def Actions.getCountHashFields(hash_obj)
      $fields_count = 0
      $fields_arr=[]
      $json_fields={}

      begin
        $json_fields = Actions.getHashKeysCount(hash_obj)
      rescue Exception=>e
        $json_compare_errors.push(e.message) if !e.message.include?("undefined method \`keys\'")
        @@scenario_fails.push(e.message) if !e.message.include?("undefined method \`keys\'")
        #f($json_compare_errors.to_s)
       end

      #puts 'Json Field Count - ' + $fields_count.to_s
      #puts 'Field Array - ' + $fields_arr.to_s

      return {'count'=>$json_fields[$fields_count], 'fields'=>$fields_arr.empty? ? '':$fields_arr}
  end



  def Actions.getHashKeysCount(hash_obj)

      begin
        $fields_count += hash_obj.keys().size
        hash_obj.keys.each { |key|
          $fields_arr.push(hash_obj[key])
          $fields_count += getHashKeysCount(hash_obj[key])['count']
        }
      rescue
        return 0
      end

      return {'count'=> $fields_count, 'fields'=>$fields_arr.empty? ? '':$fields_arr}
  end


  def Actions.v(msg)
      time = Time.new
      t_stamp = '['+time.day.to_s+'-'+time.month.to_s+'-'+time.year.to_s+'_'+time.hour.to_s+'-'+time.min.to_s+'-'+time.sec.to_s+'] '
      $world.puts t_stamp+msg if (!$world.nil? && CONFIG.get['VERBOSE']==true)
      puts t_stamp+msg
  end


  def Actions.c(msg)
    time = Time.new
    t_stamp = '['+time.day.to_s+'-'+time.month.to_s+'-'+time.year.to_s+'_'+time.hour.to_s+'-'+time.min.to_s+'-'+time.sec.to_s+'] '
    $world.puts t_stamp+msg if (!$world.nil?)
    puts t_stamp+msg
  end


  def Actions.f(msg)
    time = Time.new
    t_stamp = '['+time.day.to_s+'-'+time.month.to_s+'-'+time.year.to_s+'_'+time.hour.to_s+'-'+time.min.to_s+'-'+time.sec.to_s+'] '
    $world.puts "<font color='red'>" + t_stamp+msg + "</font>" if(!$world.nil?) #for HTML report ONLY
    puts t_stamp+msg
  end



  def Actions.printDbTableHash(rs)
      if rs.length>0
        header ='|'
        rs[0].keys.each { |column_name|
          header+= column_name.to_s+'                     |'
        }
        c header.to_s


        rs.each_with_index  {|row,i|
        values='|'
        key_len = 0
          row.each { |key,value|
            space_num = 0
            print_space =''
            key_len+=key.to_s.length
            space_num = key.to_s.length-value.to_s.length+30
            space_num.times{print_space+= ' '}
            values+=value.to_s + print_space+'|'

          }
          c values.to_s
        }
      end

  end


  def Actions.saveFailedQueryMinusToFile(rs, file_name)
        if rs.length>0
          header ='|'
          rs[0].keys.each { |column_name|
            header+= column_name.to_s+'                              |'
          }
          c header


          rs.each { |row|
            values='|'
            key_len = 0
            row.each { |key,value|
              space_num = 0
              print_space =''
              key_len+=key.to_s.length
              space_num = key.to_s.length-value.to_s.length+30
              space_num.times{print_space+= ' '}
              values+=value.to_s + print_space+'|'

            }
            c values
          }
        end

   end



  def Actions.setBuildProperty(property,value)
      properties = {}
      properties = self.getBuildProperty(property)
      #if(!properties.nil?)
        if(!properties[property].nil?)
          properties[property]=value
        else
          begin
            file = File.new(Dir.getwd+'/config/build.properties',"w+")
            #properties.each {|key,value| file.puts "#{key}=#{value}\n" }
            file.puts "#{property}=#{value}\n"
          rescue Exception=>e
            self.f('ERROR on write build properties '+ e.message)
          end
        end
      #end

  end



  def Actions.getBuildProperty(property)
      properties = {}
      begin
        File.open(Dir.getwd+'/config/build.properties', 'r') do |properties_file|
          properties_file.read.each_line do |line|
            line.strip!
            if (line[0] != ?# and line[0] != ?=)
              i = line.index('=')
              if (i)
                properties[line[0..i - 1].strip] = line[i + 1..-1].strip
              else
                properties[line] = ''
              end
            end
          end
        end
        #return properties if(!property.nil? || !property.to_s.empty? )

      rescue Exception=>e
        self.f('ERROR on retrieve build properties '+e.message)
      end
      properties
  end


  def Actions.createLocalDirs
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+' && mkdir tmp', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+' && mkdir logs', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/logs'+' && mkdir logs_'+@@time_stamp, 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/logs/logs_'+@@time_stamp+' && mkdir '+CONFIG.get['CORE_HOST_USER'].to_s.downcase, 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/logs/logs_'+@@time_stamp+' && mkdir '+CONFIG.get['CORE_HOST_USER1'].to_s.downcase, 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates'+' && mkdir db', 10)
    self.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir new_app_csv', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/new_app_csv && mkdir '+@@time_stamp, 10)
    self.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir old_app_csv', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_csv'+' && mkdir '+@@time_stamp, 10)
    self.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir new_app_json', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/new_app_json'+' && mkdir '+@@time_stamp, 10)
    self.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir old_app_json', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_json'+' && mkdir '+@@time_stamp, 10)
    self.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates/myt'+' && mkdir source', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/myt/source'+' && mkdir '+@@time_stamp, 10)
    self.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates/myt'+' && mkdir target', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/myt/target'+' && mkdir '+@@time_stamp, 10)
    self.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir new_app_rtns', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/new_app_rtns && mkdir '+@@time_stamp, 10)
    self.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir old_app_rtns', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_rtns'+' && mkdir '+@@time_stamp, 10)
    self.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir new_app_csv_traiana', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/new_app_csv && mkdir '+@@time_stamp, 10)
    self.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir old_app_csv_traiana', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_csv'+' && mkdir '+@@time_stamp, 10)
  end


  def Actions.createLocalDirsTemplatesLogs
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+' && mkdir tmp', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+' && mkdir logs', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/logs'+' && mkdir logs_'+@@time_stamp, 10)
  end

  def Actions.createLocalDirsTemplatesLogsDb
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+' && mkdir tmp', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+' && mkdir logs', 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/logs'+' && mkdir logs_'+@@time_stamp, 10)
    self.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates'+' && mkdir db', 10)
  end


#### Logs

  def Actions.downloadDirFromRemote2(host, user, pwd, local_target_dir, remote_dir)
      begin
        Actions.downloadRemoteDir(host, user, pwd, remote_dir, local_target_dir)
      rescue Exception=>e
        Actions.f('No logs found on remote server ' + host + ' for user ' + user + ' in folder' + remote_dir + ' Error -'+e.message)
        @@scenario_fails.push(e.message)
      end
  end


  def Actions.displaySanityLogs(with_sdata, with_sdata1, with_ptrade, with_ptrade1)
    Actions.v 'Getting logs...'
    self.downloadBuildLogsOldSdataDb if(with_sdata1)
    self.downloadBuildLogsNewSdataDb if(with_sdata)
    if(with_ptrade1)
      self.downloadBuildLogsOldPtradeDb
      self.downloadAppLogsOldApp
    end
    if (with_ptrade)
      self.downloadBuildLogsNewPtradeDb
      self.downloadAppLogsNewApp
    end
    Actions.displayFilesForDownloadInFolder(Dir.getwd+'/logs/logs_'+@@time_stamp)
  end


  def Actions.downloadCustomBuildLogs(with_sdata,with_ptrade)
    downloadBuildLogsNewSdataDb if(with_sdata)
    Actions.downloadCoreLogs(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD']) if(with_ptrade)
  end


  def Actions.downloadBuildLogsOldSdataDb
    Actions.v 'Downloading DB install logs for SDATA schema old version'
    self.downloadDirFromRemote2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/logs_SDATA1')
  end


  def Actions.downloadBuildLogsOldPtradeDb
      Actions.v 'Downloading DB install logs for PTRADE schema old version'
      self.downloadDirFromRemote2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/logs_PT_DB1')
  end


   def Actions.downloadBuildLogsNewSdataDb
      Actions.v 'Downloading DB install logs for SDATA schema last version'
      self.downloadDirFromRemote2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/logs_SDATA')
   end


   def Actions.downloadBuildLogsNewPtradeDb
      Actions.v 'Downloading DB install logs for PTRADE schema last version'
      self.downloadDirFromRemote2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/logs_PT_DB')
   end


  def Actions.downloadAppLogsOldApp
    Actions.v 'Downloading App install logs for old version'
    self.downloadDirFromRemote2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/logs_PT_APP1')
  end


  def Actions.downloadAppLogsNewApp
    Actions.v 'Downloading App install logs for last version'
    self.downloadDirFromRemote2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/logs_PT_APP')
  end


  def Actions.downloadPTSLogs(oldApp, newApp)
    version = 'old app' if(oldApp)
    version = 'new app' if(newApp)
    Actions.v 'Downloading PTS run logs for '+version
    self.downloadDirFromRemote2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp+'/'+CONFIG.get['CORE_HOST_USER1'].to_s.downcase, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/logs') if(oldApp)
    self.downloadDirFromRemote2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp+'/'+CONFIG.get['CORE_HOST_USER'].to_s.downcase, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/logs') if(newApp)
  end


  def Actions.displayTarVersion(user, isDb)
    res='NA'
    env_var = '$AUTOMATION_PACKAGE_NAME_'+user.to_s.strip.downcase if(isDb)
    env_var = '$AUTOMATION_PACKAGE_NAME_PT_APP' if(!isDb && user=='ptrade')
    env_var = '$AUTOMATION_PACKAGE_NAME_PT_APP1' if(!isDb && user=='ptrade1')
    cmd = 'echo '+env_var
    res = Actions.SSH_NO_FAIL(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 10) if(isDb)
    res = Actions.SSH_NO_FAIL(CONFIG.get['CORE_HOST'], user, CONFIG.get['CORE_HOST_PWD'], cmd, 10) if(!isDb)
    res = res.to_s.strip

    return res
  end

  def Actions.displayTarVersion2(user, isDb)
    res='NA'
    env_var = '$AUTOMATION_PACKAGE_NAME_'+user.to_s.strip.downcase if(isDb)
    env_var = '$AUTOMATION_PACKAGE_NAME_PT_APP' if(!isDb && user=='ptrade')
    env_var = '$AUTOMATION_PACKAGE_NAME_PT_APP1' if(!isDb && user=='ptrade1')
    cmd = 'echo '+env_var
    res = Actions.SSH_NO_FAIL(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 10) if(isDb)
    res = Actions.SSH_NO_FAIL(CONFIG.get['CORE_HOST_IP'], user, CONFIG.get['CORE_HOST_PWD'], cmd, 10) if(!isDb)
    res = res.to_s.strip

    return res
  end

  def Actions.displayDownloadedTarVersion(user,isDb,host,usr,pwd)
    res='NA'
    env_var = 'AUTOMATION_DOWNLOADED_PACKAGE_'+user.to_s.strip.downcase if(isDb)
    env_var = 'AUTOMATION_DOWNLOADED_PACKAGE_PT_APP' if(!isDb && user=='ptrade')
    env_var = 'AUTOMATION_DOWNLOADED_PACKAGE_PT_APP1' if(!isDb && user=='ptrade1')
    cmd = 'echo $'+env_var
    res = Actions.SSH_NO_FAIL(host, usr, pwd, cmd, 5)
    res = res.to_s.strip

    return res
  end


  def Actions.compareSchemasStructure(old_schema,new_schema)
    struct_sql="
    with col_data as (
      select
        owner,
        table_name,
        column_name,
        data_type||
        case
            when data_type in ('CLOB','BLOB','DATE','TIMESTAMP') then null
            when data_type ='NUMBER' then '('||nvl(data_precision,38)||','||nvl(data_scale,0)||')'
            else '('||data_length||')'
        end as data_type_definition,
        nullable
      from all_tab_columns
    )
    select new_tbl.table_name,
           new_tbl.column_name,
           new_tbl.data_type_definition   as new_data_type,
           old_tbl.data_type_definition   as old_data_type,
           new_tbl.nullable               as new_nullable,
           old_tbl.nullable               as old_nullable
    from col_data old_tbl,
         col_data new_tbl
    where new_tbl.owner=upper('"+old_schema+"')
      and old_tbl.owner= upper('"+new_schema+"')
      and new_tbl.table_name=old_tbl.table_name
      and new_tbl.column_name=old_tbl.column_name
      and (new_tbl.data_type_definition<>old_tbl.data_type_definition or new_tbl.nullable<>old_tbl.nullable)
    order by 1,2"

    struct_sql.gsub!(/[\n]+/, ' ' )
    struct_res=Actions.getDbQueryResultsWithoutFailure4(old_schema,old_schema.to_s.downcase,struct_sql)
    Actions.c '<b>Comparing DB Columns structure between Old - ' + old_schema + ' Schema and New - '+new_schema + ' Schema </b>'
    struct_str=''
    if(!struct_res.nil? && struct_res.length>0)
      struct_str<< '<table color="red" style="border: 100px;">'
      struct_str<< '<tr>'
      #struct_str<< struct_res[0].keys.to_s
      struct_res[0].keys.each { |v| struct_str<< '<td>'+v+'</td>' }
      struct_str<< '</tr>'
      struct_str<<'<br>'
      struct_str<<'<br>'
      struct_res.each{|v|
        struct_str<< '<tr>'
        #struct_str<<v.values.to_s
        v.values.each{|v| struct_str<< '<td>'+v+'</td>'}
        struct_str<< '</tr>'

      }
      struct_str<<'</table>'
      Actions.f 'Diff in DB Columns structure is found<br><font color="red">'+struct_str+'</font>'

    else
      Actions.c 'No Diff found for Columns in DB between ' + old_schema + ' Schema and '+new_schema + ' Schema '
    end
  end


  def Actions.compareTableStructure(old_schema,new_schema,table_name)

    struct_sql="
    with col_data as (
      select
        owner,
        table_name,
        column_name,
        data_type||
        case
            when data_type in ('CLOB','BLOB','DATE','TIMESTAMP') then null
            when data_type ='NUMBER' then '('||nvl(data_precision,38)||','||nvl(data_scale,0)||')'
            else '('||data_length||')'
        end as data_type_definition,
        nullable
      from all_tab_columns
    )
    select new_tbl.table_name,
           new_tbl.column_name,
           new_tbl.data_type_definition   as new_data_type,
           old_tbl.data_type_definition   as old_data_type,
           new_tbl.nullable               as new_nullable,
           old_tbl.nullable               as old_nullable
    from col_data old_tbl,
         col_data new_tbl
    where new_tbl.owner=upper('"+old_schema+"')
      and old_tbl.owner= upper('"+new_schema+"')
      and new_tbl.table_name= upper('"+table_name+"')
      and new_tbl.table_name=old_tbl.table_name
      and new_tbl.column_name=old_tbl.column_name
      and (new_tbl.data_type_definition<>old_tbl.data_type_definition or new_tbl.nullable<>old_tbl.nullable)
    order by 1,2"

    struct_sql.gsub!(/[\n]+/, ' ' )
    struct_res=Actions.getDbQueryResultsWithoutFailure4(old_schema,old_schema.to_s.downcase,struct_sql)
    Actions.c '<b>Comparing DB Columns structure between OLD ' + old_schema + ' Schema and New '+new_schema + ' Schema for table ' + table_name+'</b>'
    struct_str=''
    if(!struct_res.nil? && struct_res.length>0)
      struct_str<< '<table color="red" style="border: 100px;">'
      struct_str<< '<tr>'
      #struct_str<< struct_res[0].keys.to_s
      struct_res[0].keys.each { |v| struct_str<< '<td>'+v+'</td>' }
      struct_str<< '</tr>'
      struct_str<<'<br>'
      struct_str<<'<br>'
      struct_res.each{|v|
        struct_str<< '<tr>'
        #struct_str<<v.values.to_s
        v.values.each{|v| struct_str<< '<td>'+v+'</td>'}
        struct_str<< '</tr>'

      }
      struct_str<<'</table>'
      Actions.f 'Diff in DB Columns structure is found<br><font color="red">'+struct_str+'</font>'

    else
      Actions.c 'No Diff found in DB Columns structure for for table ' + table_name
    end


  end


  def Actions.checkAddedTablesInDb(old_schema, new_schema)
  struct_sql="select table_name from all_tables where owner='"+new_schema+"'
       minus
       select table_name from all_tables where owner='"+old_schema+"'"

  struct_sql.gsub!(/[\n]+/, ' ' )
  struct_res=Actions.getDbQueryResultsWithoutFailure4(old_schema,old_schema.to_s.downcase,struct_sql)
  Actions.c '<b>Checking new tables for ' + old_schema + ' Schema and New '+new_schema +'</b>'
  struct_str=''
    if(!struct_res.nil? && struct_res.length>0)
      struct_str<< '<table color="red" style="border: 100px;">'
      struct_res.each { |v| struct_str<<'<tr><td>'+v['TABLE_NAME'].to_s+'</td></tr>' }
      struct_str<<'</table>'
      struct_str<<'<br>'
      struct_str<<'<br>'
      Actions.f 'New tables are found on '+new_schema+'<br><font color="red">'+struct_str+'</font>'
    else
      Actions.c 'No new tables found for ' + new_schema
    end

  end


  def Actions.checkRemovedTablesInDb(old_schema, new_schema)
    struct_sql="select table_name from all_tables where owner='"+old_schema+"'
       minus
       select table_name from all_tables where owner='"+new_schema+"'"

    struct_sql.gsub!(/[\n]+/, ' ' )
    struct_res=Actions.getDbQueryResultsWithoutFailure4(old_schema,old_schema.to_s.downcase,struct_sql)
    Actions.c '<b>Checking removed tables on ' + old_schema + ' Schema and New '+new_schema +'</b>'
    struct_str=''
    if(!struct_res.nil? && struct_res.length>0)
      struct_str<< '<table color="red" style="border: 100px;">'
      struct_str<< '<tr>'
      struct_res.each { |v| struct_str<<'<td>'+v['TABLE_NAME'].to_s+'</td>' }
      struct_str<< '</tr>'
      struct_str<<'</table>'
      struct_str<<'<br>'
      struct_str<<'<br>'

      Actions.f 'Removed tables are found for '+old_schema+'<br><font color="red">'+struct_str+'</font>'
    else
      Actions.c 'No removed tables found for ' + old_schema
    end

  end



  def Actions.checkTablesChanges(old_schema, new_schema)
    Actions.checkAddedTablesInDb(old_schema, new_schema)
    Actions.checkRemovedTablesInDb(old_schema, new_schema)
  end


  def Actions.insertZerosForRecovery(user)
    if (user != 'ptrade' && user != 'ptrade1')
      @@scenario_fails.push('Error: only users ptrade and ptrade1 are allowed for insertZerosForRecovery, given user is '+user)
      fail('Error: only users ptrade and ptrade1 are allowed for insertZerosForRecovery, given user is '+user)
    end

    struct_sql='
    INSERT into AUDIT_IN
      (SOURCE_ID, ID, MSG_SESSION, MSG_ID, MSG_TYPE,
      MSG_TIME, HDR_VERSION, UP_VERSION, MSG_ORIGIN, CONTENT_SIZE,
      CAPTURE_TIME, STATUS_CODE)
    VALUES
      (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)'

    struct_sql.gsub!(/[\n]+/, ' ' )
    struct_res=Actions.getDbQueryResultsWithoutFailure3(user, struct_sql)
    Actions.c 'Inserting zeros into AUDIT_IN for '+user

    struct_sql='SELECT * FROM AUDIT_IN'
    struct_res=Actions.getDbQueryResultsWithoutFailure3(user, struct_sql)
    struct_str=''
    if(!struct_res.nil? && struct_res.length>0)
      struct_res.each { |row| struct_str<<row.to_s+"<br>" }
      Actions.v "result of SELECT * FROM AUDIT_IN: \n"+struct_str
    else
      Actions.c 'SELECT * FROM AUDIT_IN: no result found'
    end
  end


#RTNS
#Fix Fields description is taken from http://www.onixs.biz/fix-dictionary/5.0.SP1/tagNum_35.html
#35 field
  MSG_TYPE={
      '0' => 'Heartbeat', '1' => 'Test Request', '2' => 'Resend Request', '3' => 'Reject', '4' => 'Sequence Reset', '5' => 'Logout',
      '6' => 'Indication of Interest', '7' => 'Advertisement', '8' => 'Execution Report', '9' => 'Order Cancel Reject', 'a' => 'Quote Status Request', 'A' => 'Logon',
      'AA' => 'Derivative Security List', 'AB' => 'New Order - Multileg', 'AC' => 'Multileg Order Cancel/Replace (a.k.a. Multileg Order Modification Request)',
      "AD" => "Trade Capture Report Request", "AE" => "Trade Capture Report", "AF" => "Order Mass Status Request", "AG" => "Quote Request Reject", "AH" => "RFQ Request",
      "AI" => "Quote Status Report", "AJ" => " Quote Response", "AK" => "Confirmation", "AL" => "Position Maintenance Request", "AM" => " Position Maintenance Report",
      "AN" => "Request For Positions", "AO" => "Request For Positions Ack", "AP" => "Position Report", "AQ" => "Trade Capture Report Request Ack",
      "AR" => "Trade Capture Report Ack", "AS" => "Allocation Report (a.k.a. Allocation Claim)", "AT" => "Allocation Report Ack (a.k.a. Allocation Claim Ack)",
      "AU" => "Confirmation Ack (a.k.a. Affirmation)", "AV" => "Settlement Instruction Request", "AW" => "Assignment Report", "AX" => "Collateral Request",
      "AY" => "Collateral Assignment", "AZ" => "Collateral Response", "B" => "News", "b" => "Mass Quote Acknowledgement", "BA" => "Collateral Report",
      "BB" => "Collateral Inquiry", "BC" => "Network Counterparty System Status Request", "BD" => "Network Counterparty System Status Response",
      "BE" => "User Request", "BF" => "User Response", "BG" => "Collateral Inquiry Ack", "BH" => "Confirmation Request", "C" => "Email", "c" => "Security Definition Request",
      "d" => "Security Definition", "D" => "New Order - Single", "e" => "Security Status Request", "E" => "New Order - List", "F" => "Order Cancel Request",
      "f" => "Security Status", "G" => "Order Cancel/Replace Request (a.k.a. Order Modification Request)", "g" => "Trading Session Status Request",
      "H" => "Order Status Request", "h" => "Trading Session Status", "i" => " Mass Quote", "j" => "Business Message Reject", "J" => "Allocation Instruction",
      "k" => "Bid Request", "K" => "List Cancel Request", "l" => "Bid Response (lowercase L)", "L" => "List Execute", "m" => "List Strike Price",
      "M" => "List Status Request", "n" => "XML message (e.g. non FIX Msg Type)", "N" => " List Status", "o" => "Registration Instructions",
      "p" => "Registration Instructions Response", "P" => "Allocation Instruction Ack", "q" => "Order Mass Cancel Request", "Q" => "Don't Know Trade (DK)",
      "R" => "Quote Request", "r" => "Order Mass Cancel Report", "S" => "Quote", "s" => "New Order - Cross", "T" => "Settlement Instructions",
      "t" => "Cross Order Cancel/Replace Request (a.k.a. Cross Order Modification Request)", "u" => "Cross Order Cancel Request",
      "V" => "Market Data Request", "v" => "Security Type Request", "w" => "Security Types", "W" => "Market Data - Snapshot/Full Refresh",
      "x" => "Security List Request", "X" => "Market Data - Incremental Refresh", "Y" => "Market Data Request Reject", "y" => "Security List",
      "Z" => "Quote Cancel", "z" => "Derivative Security List Request", "BO" => "Contrary Intention Report", "BP" => "Security Definition Update Report",
      "BK" => "Security List Update Report", "BL" => "Adjusted Position Report", "BM" => "Allocation Instruction Alert", "BN" => "Execution Acknowledgement",
      "BJ" => "Trading Session List", "BI" => "Trading Session List Request", "BQ" => "SettlementObligationReport", "BR" => "DerivativeSecurityListUpdateReport",
      "BS" => "TradingSessionListUpdateReport", "BT" => "MarketDefinitionRequest", "BU" => "MarketDefinition", "BV" => "MarketDefinitionUpdateReport",
      "CB" => "UserNotification", "BZ" => "OrderMassActionReport", "CA" => "OrderMassActionRequest", "BW" => "ApplicationMessageRequest",
      "BX" => "ApplicationMessageRequestAck", "BY" => "ApplicationMessageReport"
  }


#0 - Successful
#field 751
  TRADE_REPORT_REJECT_REASON={
      "0" => "Successful (default)", "1" => "Invalid party onformation", "2" => "Unknown instrument",
      "3" => "Unauthorized to report trades", "4" => "Invalid trade type", "99" => "Other"
  }
  def Actions.checkRtnsDelievery(file_path,user)
    Actions.c '<b> Testing Delievery to RTNS for user: '+user+'</b>'
    Actions.c '<b> Please note that Reuters conformance test passed for ptrade v.510, so version tested must be >= 510 </b>'
    ordersStatus=[]
    ordersId=[]
    file = File.readlines(file_path)

    query = 'PTS-C7306' #FIX outgoing Event outgoing
    matches = file.select { |line|
      found=line[/#{query}/i]
      if (!found.nil? && found.length>0)
        res = line.to_s.scan(/.*\[8=FIXT.1.1(.*)\]/)
        orderIdFound=res.to_s.scan(/.*37=(\w+-\w+-\w+-\w+-\w+)/)
        if !orderIdFound.nil? && !orderIdFound.to_a.empty?
          seqNo = res.to_s.scan(/.*34=(\d)/)
          !seqNo.nil? && !seqNo.to_a.empty? ? seqNo=seqNo[0][0] : seqNo=''
          orderStatus={'orderId' => orderIdFound[0][0], 'seqNoOutgoing' => seqNo, 'seqNoIncoming' => '', 'delieveryStatus' => '', 'failReason' => ''}
          ordersStatus.push orderStatus
          ordersId.push(orderIdFound)

        end
      end


    }


    failed = false
    ordersStatus.each { |orderid|
      query = 'PTS-C7305' #FIX incoming Event outgoing
      matches = file.select { |line|
        found=line[/#{query}/i]
        if (!found.nil? && found.length>0)
          res = line.to_s.scan(/.*\[8=FIXT.1.1(.*)\]/)

          orderId_rejected = res.to_s.scan(/.*45=(#{orderid['seqNoOutgoing']})/)
          if !orderId_rejected.nil? && !orderId_rejected.to_a.empty?
            msg_res = res.to_s.scan(/.*35=(\w+)/)
            msg=''
            msg_res.nil? || msg_res.to_a.empty? || MSG_TYPE[msg_res[0][0]].nil? ? msg='NO_DICTIONARY_KEY' : msg= MSG_TYPE[msg_res[0][0]].to_s
            reject_reason = !res.to_s.scan(/.*58=(.*?)\\/)[0][0].nil? ? res.to_s.scan(/.*58=(.*?)\\/)[0][0] : ''
            orderid['delieveryStatus'] = 'failed' #msg
            orderid['seqNoIncoming'] = orderid['seqNoIncoming'] #App reject
            orderid['failReason'] = reject_reason
            failed = true
          end
          #break if failed


          passed = false
          orderId_passed = res.to_s.scan(/.*571=(#{orderid['orderId']})/)
          if !orderId_passed.nil? && !orderId_passed.to_a.empty?
            msg_res = res.to_s.scan(/.*35=(\w+)/)
            msg=''
            msg_res.nil? || msg_res.to_a.empty? || MSG_TYPE[msg_res[0][0]].nil? ? msg='NO_DICTIONARY_KEY' : msg= MSG_TYPE[msg_res[0][0]].to_s
            if (msg_res.nil? || msg_res[0][0]!='AR' || msg_res.to_s.empty?)
              orderid['delieveryStatus'] = 'failed'
              orderid['failReason'] = "Expecting value of 'AR' in field 35,but actual is '"+msg_res[0][0].to_s+"' ("+msg+")"
              passed = false

            else
              if msg=='AR'
                orderid['delieveryStatus'] = 'passed'
                passed = true
              else
                #Actions.f orderid['orderId']+'  is not found in incoming RTNS message '
              end
            end
          end
          #break if passed


        end
      }
    }
    Actions.c "<b> " + ordersStatus.length.to_s+" TCRs sent to RTNS by user: " + user


    arrFailed=ordersStatus.select { |elem| elem["delieveryStatus"]=="failed" }
    Actions.f "<b> " + arrFailed.length.to_s+ " orders are NOT delivered to RTNS for user: "+user+" ,pls. see list below </b>" if (!arrFailed.nil? && !arrFailed.to_a.empty?)
    arrFailed.each { |failed_order|
      Actions.f " orderID: " + failed_order['orderId'] + "   sequence: " + failed_order['seqNoOutgoing'] + "   reason: " + failed_order['failReason']
    }


    arrPassed=ordersStatus.select { |elem| elem["delieveryStatus"]=="passed" }
    Actions.c "<b> " + arrPassed.length.to_s+ " orders are NOT delivered to RTNS for user: "+user+" ,pls. see list below </b>" if (!arrPassed.nil? && !arrPassed.to_a.empty?)

    Actions.f "<b> No sent orders to RTNS being found for user: "+user+" , pls. check Your prod.conf and pts_tidy_3.log </b>" if ((arrPassed.nil? &&arrFailed.nil?) || (arrPassed.length+arrFailed.length<=0))
  end



  def Actions.compareOutgoingRtns(log_file_path1,log_file_path2)
    Actions.c '<b> Comparing Outgoing Data to RTNS </b>'
    Actions.c '<b> Please note that Reuters conformance test passed for ptrade v.510, so version tested must be >= 510 </b>'
    file1 = File.readlines(log_file_path1)
    query = 'PTS-C7306' #FIX outgoing Event outgoing
    found_orders1=[]

    #ptrade1
    matches1 = file1.select { |line|
      found=line[/#{query}/i]
      if (!found.nil? && found.length>0)
        res = line.to_s.scan(/.*\[8=FIXT.1.1(.*)\]/)
        orderIdFound=res.to_s.scan(/.*37=(\w+-\w+-\w+-\w+-\w+)/)

        if !orderIdFound.nil? && !orderIdFound.to_a.empty?
          foundOrder1={}
          res_arr = res[0][0].to_s.split('^'.chr)
          res_arr.each_with_index { |elem,index |
            res_arr.delete_at(index) if res_arr[index].nil? || res_arr[index].to_s.empty? || (res_arr[index]=~/\w=\w/).nil?
          }

          arrKeysValues=res_arr.to_s.scan /\d+=\w+/
          arrKeysValues.each { |e,i|
            key_value=e.to_s.split('=')
            key = key_value[0].gsub('0001','')
            value = key_value[1]
            foundOrder1[key]=value
          }
          #puts foundOrder1.to_s
          found_orders1.push foundOrder1
        end
      end
    }
    Actions.c "<b> " + found_orders1.length.to_s+" TCRs sent to RTNS by user: " + CONFIG.get['CORE_HOST_USER1']+"</b>"

    #ptrade
    file2 = File.readlines(log_file_path2)
    query = 'PTS-C7306' #FIX outgoing Event outgoing
    found_orders2=[]
    matches2 = file2.select { |line|
      found=line[/#{query}/i]
      if (!found.nil? && found.length>0)
        res = line.to_s.scan(/.*\[8=FIXT.1.1(.*)\]/)
        orderIdFound=res.to_s.scan(/.*37=(\w+-\w+-\w+-\w+-\w+)/)

        if !orderIdFound.nil? && !orderIdFound.to_a.empty?
          foundOrder2={}
          res_arr = res[0][0].to_s.split('^'.chr)
          res_arr.each_with_index { |elem,index |
            res_arr.delete_at(index) if res_arr[index].nil? || res_arr[index].to_s.empty? || (res_arr[index]=~/\w=\w/).nil?
          }


          arrKeysValues=res_arr.to_s.scan /\d+=\w+/
          arrKeysValues.each { |e,i|
            key_value=e.to_s.split('=')
            key = key_value[0].gsub('0001','')
            value = key_value[1]
            foundOrder2[key]=value

          }
          #puts foundOrder2.to_s
          found_orders2.push foundOrder2
        end
      end
    }
    Actions.c "<b> " + found_orders1.length.to_s+" TCRs sent to RTNS by user: " + CONFIG.get['CORE_HOST_USER']+"</b>"

    Actions.c "<b> NO DIFF FOUND in outgoing data to RTNS - " + (found_orders1.length+found_orders2.length).to_s + " ers have been sent </b></br>" if (found_orders1-found_orders2).to_a.empty? && (found_orders2-found_orders1).to_a.empty? && (found_orders1.length+found_orders2.length)>0
    Actions.f "<b> NO ers have been sent for both users: ptrade1 and ptrade </b></br>" if (found_orders1-found_orders2).to_a.empty? && (found_orders2-found_orders1).to_a.empty? && (found_orders1.length+found_orders2.length)==0
    if !((found_orders1-found_orders2).to_a.empty?)
      Actions.f "<b> Diff FOUND in outgoing data to RTNS.Below is Missing for user: " + CONFIG.get['CORE_HOST_USER'] +' '+ (found_orders1-found_orders2).length.to_s + ' missing tcrs vs ' + CONFIG.get['CORE_HOST_USER1']+"</b>"
      Actions.f "Diff:<br>"

      (found_orders1-found_orders2).each { |hash|
        diff=''
        hash.keys.each{ |key|
          hash.values.each { |value|
            diff+=key+'='+value+' '
          }
        }
        Actions.f diff
      }

    end
    if !((found_orders2-found_orders1).to_a.empty?)
      Actions.f "<b> Diff FOUND in outgoing data to RTNS.Below is missing Missing for user: " + CONFIG.get['CORE_HOST_USER1'] +' '+(found_orders2-found_orders1).length.to_s + ' missing tcrs vs ' + CONFIG.get['CORE_HOST_USER']+"</b>"

      (found_orders1-found_orders2).each { |hash|
        diff=''
        hash.keys.each{ |key|
          hash.values.each { |value|
            diff+=key+'='+value+' '
          }
        }
        Actions.f diff
      }

    end

  end
  ### RTNS end



###Utils
  def Actions.cleanupMsl(user,mslIP)
    Actions.c '<b> Running Cleanup and Restart of Msl Server </b>'+mslIP

    cmd ='cd '+CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation && dos2unix MSLdbCleaner_automatic.sh && chmod 755 MSLdbCleaner_automatic.sh'
    res=self.SSH(CONFIG.get['CORE_HOST'], user, CONFIG.get['CORE_HOST_PWD'], cmd, 10, true, '')
    cmd ='cd '+CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation && ./MSLdbCleaner_automatic.sh -msl:'+mslIP
    r=self.SSH(CONFIG.get['CORE_HOST'], user, CONFIG.get['CORE_HOST_PWD'], cmd, 300, true, 'Finished successfully')
    v 'Msl '+mslIP+' Cleanup command output - '+r.to_s
  end

  def Actions.cleanupMslCustom(mslIP, target_dir_path)
    mslCleanerScript = 'MSLdbCleaner_automatic.sh'
    c '<b> Running Cleanup and Restart of Msl Server </b>'+mslIP

    Actions.uploadTemplates(mslIP,CONFIG.get['MSL_HOST_USER'],CONFIG.get['MSL_HOST_PWD'],Dir.getwd+'/templates/bash/'+mslCleanerScript,CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['MSL_HOST_USER']+'/'+target_dir_path+'/'+mslCleanerScript)
    Actions.rigthsForFile(mslIP,CONFIG.get['MSL_HOST_USER'],CONFIG.get['MSL_HOST_PWD'],CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['MSL_HOST_USER']+'/'+target_dir_path,mslCleanerScript,'755')

    cmd ='cd '+CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['MSL_HOST_USER']+'/'+target_dir_path+' && ./MSLdbCleaner_automatic.sh -msl:'+mslIP
    res=self.SSH(mslIP, CONFIG.get['MSL_HOST_USER'], CONFIG.get['MSL_HOST_PWD'], cmd, 300, true, 'Finished successfully')

    v 'Msl Cleanup command output - '+res.to_s
    c 'Cleaning of MSL '+mslIP+' finished'
  end


def Actions.truncatePtradeTables(schema)
query="truncate table "+schema+".AUDIT_IN DROP STORAGE;
truncate table "+schema+".FX_DEAL DROP STORAGE;
truncate table "+schema+".FX_DEAL_LEG DROP STORAGE;
truncate table "+schema+".FX_TICKET_LEG DROP STORAGE;
update "+schema+".SD_TARGET set LAST_ID = NULL, LAST_SESSION = NULL, LAST_SRC_SESSION = NULL,  LAST_SRC_ID = NULL;
commit;
"

    getDbQueryResultsWithoutFailure4(schema,schema.to_s.downcase,query)

end


  def Actions.SCP(host,usr,pwd,local_path,remote_path)
    Net::SCP.start(host, usr, :password => pwd) do |scp|
      # asynchronous upload; call returns immediately and requires SSH
      # event loop to run
      channel = scp.upload(local_path, remote_path)
      channel.wait
    end
  end



  def Actions.isIpValidInParams
    ip_found=false
    ENV.each do |a|
      #Actions.v "Env Param: #{a[0].to_s}"
      if(a[0].to_s.include?('_IP'))
        ip_found=self.valid_IP_v4?(a[1].to_s)
        if(!ip_found)
          Actions.f "Please define valid IP for param #{a[0].to_s}"
          fail("Please define valid IP for param #{a[0].to_s}")
        end
      end
    end
    # return ip_found
    if(!ip_found)
      Actions.f('No valid IPs found in given params')
      fail('No valid IPs found in given params')
    end
  end



  def Actions.valid_IP_v4?(addr)
    found=false
    if /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\Z/ =~ addr
      #return $~.captures.all? {|i| i.to_i < 256}
      $~.captures.each {|i| i.to_i < 256 ? found=true : found=false}
    end
    return found
  end


  def Actions.changeInFileBetweenMatches(host, user, pwd, filePath, startPieceToMatch, endPieceToMatch, textToBeChanged, textToPaste)
    c 'Changing text "'+textToBeChanged+'" to "'+textToPaste+'" in '+host+':'+filePath
    cmd ='sed -i -e "/^'+startPieceToMatch+'/,/^'+endPieceToMatch+'/s/'+textToBeChanged+'/'+textToPaste+'/g" '+filePath
    res=self.SSH(host, user, pwd, cmd, 30, true, '')
  end

  def Actions.isUp?(host)
    # require 'net/ping'
    # check = Net::Ping::External.new(host)
    # if check.ping?
    #   v host+':Ping finished successfully'
    # end

    v 'Pinging '+host+'...'
    res = Actions.WINCMD_NO_FAIL('ping '+host, 20)
    res = res.to_s.downcase
    if res.include?('reply')
      if res.include?('0% loss')
        v host+':Pinging '+host+' finished successfully'
      else
        f 'Pinging '+host+' finished with losses'
      end
    else
      f 'ERROR: ping to '+host+' failed'
      fail('ERROR: ping to '+host+' failed')
    end

  end

end