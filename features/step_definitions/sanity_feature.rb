require 'cucumber'
require 'net/ssh'
require 'net/scp'
require 'time'

begin
  require '../../features/helpers/Actions'
  require '../../features/helpers/Config.rb'
  include Config
rescue LoadError
end


#@@time_stamp=Time.now.to_i.to_s


When /^tVisiting some Url$/  do

end




Then /^tUrl's page appears$/  do
    puts 'Redis adapter step failed  - OUTPUT...'
end



Given /^SDATA SCHEMAS Test Setup is Done$/ do
  Actions.createLocalDirs
  steps %Q{
    Given Automation dir exist on oracle server
    Given DB Sdata Old Schema is built
    Given DB Sdata New Schema is built
    Given Local target folders and files contents deleted


  }
  #displaySdataSchemaOldVersion #TODO refactoring to Actions from Sanity2
end


Given /^PTRADE SCHEMAS Test Setup is Done$/ do
   Actions.createLocalDirs
   steps %Q{
    Given Automation dir exist on oracle server
    Given DB Ptrade Schema scripts copied to Oracle server
    Given DB Ptrade Schema scripts started on Oracle server
    Given Ptrade App is built
    Given Ptrade Version Info is Displayed
    Given Automation files uploaded to remote server

  }

end

Given /^Msl Recovery setup is Done$/ do

  steps %Q{
    Given Ptrade service stopped
    Given Ptrade App is built
    Given Version Info is Displayed
    Given Automation dir exist on ptrade server
    Given Automation dir exist on redis server
    Given Automation files uploaded to remote server
    Given Redis new config is copied
    Given Redis is started with new config
    Given MyT csv files are deleted from Remote server
    Given New prod-conf is copied to ptrade PTS config
    Given Ptrade service restarted witn new config
    Given Wait for Msl processing


  }
end


Given /^DB Sdata Old Schema is built$/ do
  Actions.v 'Copying script and building Old schema to Oracle server... '
  #Old Schema
  Actions.uploadTemplates(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/buildSchema_sdata1.sh', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/buildSchema_sdata1.sh')
  Actions.uploadTemplates(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/db_config_sdata1_example.sql', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/db_config_sdata1_example.sql')
  Actions.uploadTemplates(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/sdata_schema1_install_automatic.sh', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema1_install_automatic.sh')

  #Old Schema
  Actions.c 'Building SDATA DB Schema Version - '+CONFIG.get['SDATA_OLD_SCHEMA_VERSION']+' from scratch... '
  cmd =  "dos2unix -q "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/buildSchema_sdata1.sh"\
         +" && chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/buildSchema_sdata1.sh'
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd =  "dos2unix -q "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema1_install_automatic.sh"\
         +" && chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema1_install_automatic.sh'
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema1_install_automatic.sh'
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema1_install_automatic.sh -n " +CONFIG.get['SDATA_OLD_SCHEMA_VERSION']
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 600, true, '')

end


Given /^DB Sdata New Schema is built$/ do
  Actions.c 'Copying script and building New schema to Oracle server... '
  #Last Schema
  Actions.uploadTemplates(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/db_config_sdata_example.sql', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/db_config_sdata_example.sql')
  Actions.uploadTemplates(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/sdata_schema_install_automatic.sh', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema_install_automatic.sh')


  #Last Schema
  Actions.c 'Building Last SDATA DB Schema from scratch... '
  cmd =  "dos2unix -q "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema_install_automatic.sh"\
         +" && chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema_install_automatic.sh'
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema_install_automatic.sh'
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')


  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 600, true, '')

end




Given /^Version Info is Displayed$/ do
  cmd =  'ls -l '+@@CONFIG['REMOTE_PTRADE_DIR_PATH']
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 20, true, '')
  Actions.c '<b>App Version - '+res.to_s+'</b>'
  r=res.split(' ')
  $app_version=r[10].gsub!('/export/home/ptrade/','').to_s
  Actions.setBuildProperty('APP_VERSION', $app_version.to_s)
  res = Actions.getDbQueryResultsWithoutFailure4("select * from ptrade.SCHEMA_VERSION")
  $schema_version=res[0]['VERSION_NAME'].to_s
  $schema_created=res[0]['CREATION_TIME'].to_s
  Actions.setBuildProperty('SCHEMA_VERSION', $schema_version.to_s)
  Actions.setBuildProperty('SCHEMA_CREATED', $schema_created.to_s)
  Actions.c '<b>Schema Version - '+res.to_s+'</b>'
end



Given /^Ptrade Version Info is Displayed$/ do
  source_schema = @@CONFIG['ORACLE_HOST_TEMPLATE_SCHEMA']
  target_schema = @@CONFIG['ORACLE_HOST_SCHEMA']
  results_dir = @@CONFIG['ORACLE_TABLES_COMPARE_RESULTS_DIR']

  s_schema = Actions.getDbQueryResultsWithoutFailure4(source_schema,source_schema.to_s.downcase,"select * from "+source_schema+".SCHEMA_VERSION")
  s_schema_version = s_schema[0]['VERSION_NAME'].to_s
  s_schema_created = s_schema[0]['CREATION_TIME'].to_s
  t_schema = Actions.getDbQueryResultsWithoutFailure4(target_schema,target_schema.to_s.downcase,"select * from "+target_schema+".SCHEMA_VERSION")
  t_schema_version = t_schema[0]['VERSION_NAME'].to_s
  t_schema_created = t_schema[0]['CREATION_TIME'].to_s
  Actions.c '<b>Comparing Schema Versions - Old '+s_schema_version+' '+s_schema_created+ ' vs New '+t_schema_version+' '+t_schema_created +'</b>'
  Actions.setBuildProperty('APP_VERSION',t_schema_version.to_s)
end



Given /^Automation dir exist on oracle server$/ do
  Actions.v 'Creating Automation dir on oracle server '+CONFIG.get['ORACLE_HOST']+'... '
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 10, true, '')
end

Given /^Automation dir exists on oracle server2$/ do
  Actions.v 'Creating Automation dir on oracle server '+CONFIG.get['ORACLE_HOST_IP']+'... '
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']
  res = Actions.SSH(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 10, true, '')
end


Given /^DB Ptrade Schema scripts copied to Oracle server$/ do
  Actions.c 'Copying scripts to build previous and new schemas on Oracle server... '
  Actions.uploadTemplates(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/ptradeDB_schema_install_automatic.sh', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/ptradeDB_schema_install_automatic.sh')
  Actions.uploadTemplates(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/ptradeDB_schema1_install_automatic.sh', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/ptradeDB_schema1_install_automatic.sh')
  Actions.uploadTemplates(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/db_config_qa_ptrade_example.sql', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/db_config_qa_ptrade_example.sql')
  Actions.uploadTemplates(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/buildSchema_ptrade1.sh', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/buildSchema_ptrade1.sh')

end



Given /^DB Ptrade Schema scripts started on Oracle server$/ do
  Actions.c 'Building PTRADE DB New Schema from scratch... '
  cmd =  "dos2unix -q "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd ="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/ptradeDB_schema_install_automatic.sh'
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')


  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 180, false, '')

  Actions.c 'Building PTRADE DB Old Schema from scratch... '
  cmd =  "dos2unix -q "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/buildSchema_ptrade1.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd ="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/buildSchema_ptrade1.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd =  "dos2unix -q "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema1_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd =  "dos2unix -q "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema1_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd ="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema1_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema1_install_automatic.sh -n "+CONFIG.get['PTRADE_OLD_SCHEMA_VERSION']
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 300, false, '')


end

Given /^Ptrade service stopped$/ do
  Actions.c 'Stopping PTS services... '
  cmd = @@CONFIG['REMOTE_PTRADE_DIR_PATH']+'/bin/service.sh stop'
  expected_output_rows=['pts_tidy stopped successfully','pts_core stopped successfully','pts_http stopped successfully']
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 60, true, expected_output_rows)
  Actions.c res.to_s
end


Given /^Ptrade App is built$/ do
  Actions.v 'Copying build scripts to build App on Ptrade server... '
  Actions.uploadTemplates(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/bash/ptradeAPP_build_install_automatic.sh', CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/ptradeAPP_build_install_automatic.sh')

  Actions.c 'Building App on Ptrade server... '
  cmd =  "dos2unix -q "+CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+"/ptradeAPP_build_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 20, false, '')

  cmd ="chmod 755 "+CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/ptradeAPP_build_install_automatic.sh'
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 20, false, '')

  cmd = CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+"/ptradeAPP_build_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 180, false, '')
end


Given /^Automation dir exist on ptrade server$/ do
  Actions.v 'Creating Automation dir on ptrade server... '
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 10, true, '')
end

Given /^Automation dir exists on ptrade server2$/ do
  Actions.v 'Creating Automation dir on ptrade server...'
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']
  res = Actions.SSH(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 10, true, '')
end



Given /^Automation dir exist on redis server$/ do
  if CONFIG.get['CORE_HOST']!=CONFIG.get['SAPHIRE_REDIS_HOST1']
    Actions.v 'Creating Automation dir on redis server... '
    cmd = 'mkdir -p $HOME/Automation'
    res = Actions.SSH(CONFIG.get['SAPHIRE_REDIS_HOST1'], CONFIG.get['SAPHIRE_REMOTE_HOST1_USER'], CONFIG.get['SAPHIRE_REMOTE_HOST1_PWD'], cmd, 10, true, '')
  end
end


Given /^Local target folders and files contents deleted$/ do
  Actions.v 'Deleting Local target folders and files contents '
  #Actions.resetDownloadsLocalFolders()
end


Given /^Automation files uploaded to remote server$/ do
  Actions.v 'Uploading Templates files and scripts to remote server... '
  Actions.uploadTemplates(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH'])
  Actions.uploadTemplates(CONFIG.get['SAPHIRE_REDIS_HOST1'], CONFIG.get['SAPHIRE_REMOTE_HOST1_USER'], CONFIG.get['SAPHIRE_REMOTE_HOST1_PWD'], Dir.getwd+'/templates/config', @@CONFIG['REMOTE_REDIS_TEMPLATE_DIR_PATH'])
end


Given /^Redis new config is copied$/ do
  Actions.v 'Copying redis-cli script to redis src... '
  cmd = "cp -f "+@@CONFIG['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/startRedisCli.sh'+' '+'$HOME/redis/src' \
         +" && sleep 3"\
         +" && dos2unix -q $HOME/redis/src/startRedisCli.sh"\
         +" && chmod 755 "+ '$HOME/redis/src/startRedisCli.sh' \
         +" && sleep 3"
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 20, false, '')
end


Given /^Redis is started with new config$/ do
  Actions.c 'Restarting Redis with new config... Redis output redirected to /home/Automation/RedisMonitor.txt'
  cmd =  '$HOME/redis/src/startRedisCli.sh'      \
         +" & sleep 5"
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 20, false, '')
end


Given /^MyT csv files are deleted from Remote server$/ do
  Actions.v 'Deleting contents of MyT csv tickets - ' + @@CONFIG['MYT_CSV_REMOTE_DIR_PATH'] + ' on ' + CONFIG.get['CORE_HOST']
  cmd = 'rm -rf ' + @@CONFIG['MYT_CSV_REMOTE_DIR_PATH'] + '* &&  wait'
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 20, false, '')
  #Actions.c res
end


Given /^New prod-conf is copied to ptrade PTS config$/ do
  Actions.v 'Copying prod.conf to PTS config... '
  cmd = "cp -f "+@@CONFIG['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/prod.conf'+' '+@@CONFIG['REMOTE_PTRADE_DIR_PATH']+'/config'
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 10, false, '')
end

Given /^Ptrade service restarted witn new config$/ do
  Actions.c 'Restarting PTS service with new config... '
  cmd = @@CONFIG['REMOTE_PTRADE_DIR_PATH']+'/bin/service.sh restart'
  expected_output_rows=['The PTS (module: tidy) is alive','The PTS (module: core) is alive','The PTS (module: http) is alive']
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 60, true, expected_output_rows) #The PTS (module: tidy) is alive
  Actions.c res.to_s
end




Given /^Local target MyT folder contents deleted$/ do
  Actions.v 'Deleting contents from Local target MyT folder  - ' + Dir.getwd + @@CONFIG['MYT_CSV_LOCAL_TARGET_DIR_PATH']
  Actions.deleteFolderContents(Dir.getwd+@@CONFIG['MYT_CSV_LOCAL_TARGET_DIR_PATH'])
end


Given /^Wait for Msl processing$/ do
  Actions.v('Waiting for MSL processing for ' + @@CONFIG['WAIT_FOR_MSL_PROCESSING_SECS'].to_s + ' seconds')
  sleep(@@CONFIG['WAIT_FOR_MSL_PROCESSING_SECS'].to_i)
end





#########
Then /^SDATA schema compared$/ do
  Actions.checkTablesChanges('SDATA1','SDATA')
  Actions.compareSchemasStructure('SDATA1','SDATA')
  Actions.compareSdataDbTableResults(@@time_stamp)
end


=begin
Then /^SDATA schema compared with previous run for the latest version$/ do
  Actions.compareSdataDbTableResults(@@time_stamp)
end
=end



Then /^DB tables DEAL TICKETS LEGS compared$/ do
  #Actions.compareDbTableResults()
end

Then /^DB tables DEAL TICKETS LEGS are matched vs template$/ do
   Actions.compareDbTableResultsVsBkp(@@time_stamp)
end


Given /^MyT Remote Folder contents downloaded to local target folder$/ do
  target_dir = Dir.getwd + CONFIG.get['MYT_CSV_LOCAL_TARGET_DIR_PATH']
  Actions.WINCMD('cd ' +target_dir+' & mkdir ' +  @@time_stamp, 10, '')
  Actions.c 'Downloading MyT Remote Folder contents to local target folder - from ' + @@CONFIG['MYT_CSV_REMOTE_DIR_PATH'] + ' into local folder ' + Dir.getwd+@@CONFIG['MYT_CSV_LOCAL_TARGET_DIR_PATH']+'/'+@@time_stamp
  Actions.downloadRemoteDir(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], @@CONFIG['MYT_CSV_REMOTE_DIR_PATH'], Dir.getwd+@@CONFIG['MYT_CSV_LOCAL_TARGET_DIR_PATH']+'/'+@@time_stamp)
end




Then /^Template and Downloaded MyT csv Folders are Matched excluding timestamps$/ do
  steps %Q{
    Given MyT Remote Folder contents downloaded to local target folder
  }
  source_dir = Dir.getwd + @@CONFIG['MYT_CSV_LOCAL_TARGET_DIR_PATH'] #'/templates/myt/source'
  target_dir = Dir.getwd + @@CONFIG['MYT_CSV_LOCAL_SOURCE_DIR_PATH']+'/'+@@time_stamp #'/templates/myt/target'
  Actions.compareCsvDirs(source_dir, target_dir)
end




Given /^Remote Saphire Jsons are downloaded to local target$/ do
  target_dir = Dir.getwd + @@CONFIG['SAPPHIRE_JSON_LOCAL_TARGET_DIR_PATH']
  Actions.WINCMD('cd ' +target_dir+' & mkdir ' +  @@time_stamp, 10, '')
  if (CONFIG.get['CORE_HOST'] == CONFIG.get['SAPHIRE_REDIS_HOST1'])
     Actions.downloadRemoteFile(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], @@CONFIG['SAPPHIRE_JSON_REMOTE_FILE_PATH']+'/'+@@CONFIG['SAPPHIRE_JSON_FILE_NAME'], Dir.getwd +  @@CONFIG['SAPPHIRE_JSON_LOCAL_TARGET_FILE_PATH']+'/'+@@time_stamp+'/'+@@CONFIG['SAPPHIRE_JSON_FILE_NAME'])
  else
    redis_home_dir = '$HOME/Automation'
    Actions.downloadRemoteFile(CONFIG.get['SAPHIRE_REDIS_HOST1'], CONFIG.get['SAPHIRE_REMOTE_HOST1_USER'], CONFIG.get['SAPHIRE_REMOTE_HOST1_PWD'], redis_home_dir, @@CONFIG['SAPPHIRE_JSON_REMOTE_FILE_PATH']+'/'+@@CONFIG['SAPPHIRE_JSON_FILE_NAME'], Dir.getwd +  @@CONFIG['SAPPHIRE_JSON_LOCAL_TARGET_FILE_PATH']+'/'+@@time_stamp+'/'+@@CONFIG['SAPPHIRE_JSON_FILE_NAME'])
  end
end





Then /^Template and Downloaded Saphire Jsons are Matched excluding sequence$/ do
  steps %Q{
    Given Remote Saphire Jsons are downloaded to local target
  }
  template_json =  Dir.getwd + @@CONFIG['SAPPHIRE_JSON_LOCAL_SOURCE_FILE_PATH']+'/'+@@CONFIG['SAPPHIRE_JSON_FILE_NAME']
  build_json =  Dir.getwd +  @@CONFIG['SAPPHIRE_JSON_LOCAL_TARGET_FILE_PATH']+'/'+@@time_stamp+'/'+@@CONFIG['SAPPHIRE_JSON_FILE_NAME']
  Actions.compareSaphireOutputJsons(template_json, build_json)
end
