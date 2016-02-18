require 'cucumber'
require 'net/ssh'
require 'net/scp'
require 'time'
require 'thread'
require 'thwait'

begin
  require '../../features/helpers/Actions'
  require '../../features/helpers/Config.rb'
  include Config
rescue LoadError
end



Given /^SDATA SCHEMAS Setup is Done - Parcipany and Last Lab versions$/ do
  steps %Q{
      Given beforeScenarioStepsSdata
    }

  if(!CONFIG.get['DEPLOY_SDATA'].nil? && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
    begin
      buildSdataSchema('sdata1', CONFIG.get['SDATA_OLD_SCHEMA_VERSION'])
    rescue Exception=>e
      @@scenario_fails.push('sdata1 build Failed for version ' + CONFIG.get['SDATA_OLD_SCHEMA_VERSION'])
      Actions.displaySanityLogs(false, true, false, false)
      fail('sdata1 build Failed for version ' + CONFIG.get['SDATA_OLD_SCHEMA_VERSION'])
    end

    begin
      buildSdataSchema('sdata', '')
    rescue Exception=>e
      @@scenario_fails.push('sdata build Failed for the Latest version ')
      Actions.displaySanityLogs(true, false, false, false)
      fail('sdata build Failed for the Latest version ')
    end

    displaySdataSchemaOldVersion
    displaySdataSchemaNewVersion
  else
    Actions.c '<b>NOT deploying SDATA</b>'
  end
end


### Concurrent


#sdata
Given /^SDATA SCHEMAS Concurrent Setup is Done - Parcipany and Last Lab versions$/ do
  steps %Q{
      Given beforeScenarioSteps
    }

  if(!CONFIG.get['DEPLOY_SDATA'].nil? && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
    threads = []
    t1=Thread.new{buildOldSdataSchemaThread(CONFIG.get['SDATA_OLD_SCHEMA_VERSION'])}
    t1.abort_on_exception = true
    threads << t1
    t2=Thread.new{buildNewSdataSchemaThread('')}
    t2.abort_on_exception = true
    t1.join
    threads << t2
    t2.join
    ThreadsWait.all_waits(*threads )
    fail('buildOldSdataSchemaTrhead failed for ptrade1') if(t1.status.nil?)
    fail('buildNewSdataSchemaThread failed for ptrade') if(t2.status.nil?)

    displaySdataSchemaOldVersion
    displaySdataSchemaNewVersion
    steps %Q{
      Then SDATA schema compared
    }
  else
    Actions.c '<b>NOT deploying SDATA</b>'
  end
end


Given /^SDATA SCHEMAS Concurrent Setup is Done - Production version for both users$/ do
  steps %Q{
      Given beforeScenarioSteps
    }

  if(!CONFIG.get['DEPLOY_SDATA'].nil? && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
    threads = []
    t1=Thread.new{buildOldSdataSchemaThread(CONFIG.get['SDATA_OLD_SCHEMA_VERSION'])}
    t1.abort_on_exception = true
    threads << t1
    t2=Thread.new{buildNewSdataSchemaThread(CONFIG.get['SDATA_OLD_SCHEMA_VERSION'])}
    t2.abort_on_exception = true
    t1.join
    threads << t2
    t2.join
    ThreadsWait.all_waits(*threads )
    fail('buildOldSdataSchemaThread failed for ptrade1') if(t1.status.nil?)
    fail('buildNewSdataSchemaThread failed for ptrade') if(t2.status.nil?)

    displaySdataSchemaOldVersion
    displaySdataSchemaNewVersion
    # steps %Q{
    #  Then SDATA schema compared
    # }
  else
    Actions.c '<b>NOT deploying SDATA</b>'
  end
end




def buildOldSdataSchemaThread(schema_version)
  sleep CONFIG.get['WAIT_FOR_ONE_THREAD_SDATA'].to_i
  begin
    buildSdataSchema('sdata1', schema_version)
  rescue Exception => e
    @@scenario_fails.push('sdata1 build Failed for version ' + CONFIG.get['SDATA_OLD_SCHEMA_VERSION'])
    Actions.displaySanityLogs(false, true, false, false)
    fail('sdata1 build Failed for version ' + CONFIG.get['SDATA_OLD_SCHEMA_VERSION'])
  end
end



def buildNewSdataSchemaThread(schema_version)
  begin
    buildSdataSchema('sdata', schema_version)
  rescue Exception => e
    @@scenario_fails.push('sdata build Failed for the Latest version ')
    Actions.displaySanityLogs(true, false, false, false)
    fail('sdata build Failed for the Latest version ')
  end
end


### sdata end


###scratch
Given /^Ptrade Apps And Schemas are built for Production version and  New Lab version$/ do
  threads = []
  old_app_version=CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'].nil? || CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'].to_s.strip.empty? ? '' : CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'].to_s.strip
  t1=Thread.new{buildPtradeAppForProductionVersionThread(old_app_version)}
  t1.abort_on_exception = true
  threads << t1
  new_app_version=CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].nil? || CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].to_s.strip.empty? ? '' : CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].to_s.strip
  t2=Thread.new{buildPtradeAppForLatestLabVersionThread(new_app_version)}
  t2.abort_on_exception = true
  t1.join
  threads << t2
  t2.join
  ThreadsWait.all_waits(*threads )
  fail('Ptrade App and Schema build failed for user ptrade1') if(t1.status.nil?)
  fail('Ptrade App and Schema build failed for user ptrade') if(t2.status.nil?)

end

def buildPtradeAppForProductionVersionThread(app_version)
  sleep CONFIG.get['WAIT_FOR_ONE_THREAD_PTRADE'].to_i
  Actions.createLocalDirs
  Actions.removeOldOutput
  deleteFolderContentsOnRemoteServerIfFolderExist(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], 'Automation/ers')
  deleteFolderContentsOnRemoteServerIfFolderExist(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], 'Automation/ers2')
  createAutomationDirForUser(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  buildPtradeOldSchema2(app_version)
  uploadDir2RemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation')
  uploadDir2RemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/ers', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/ers')
  uploadDir2RemoteAutomationFolder(CONFIG.get['SAPHIRE_REDIS_HOST1'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['SAPHIRE_REMOTE_HOST1_PWD'], Dir.getwd+'/templates/config', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation')
  Actions.cleanupMsl(CONFIG.get['CORE_HOST_USER1'], CONFIG.get['MSL_HOST_IP'])
  buildPtradeApp2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], app_version) #CONFIG.get['PTRADE_OLD_SCHEMA_VERSION']
  displayPtradeAppVersion(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/old_app_config2/prod.conf', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/PTS/config/prod.conf')
  #uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/old_app_config2/fix/rtns/qfj.cfg', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/PTS/config/fix/rtns/qfj.cfg')
  deleteCsvFilesOnRemoteServerForOldVersion
  createCsvDirsForUserOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  restartRedisWithNewConfigForOldVersion2
  restartPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  runRemoteMslSender4upgrade2(CONFIG.get['CORE_HOST_USER1'], true, 'ers', CONFIG.get['MSL_HOST_IP'])
  Actions.downloadPTSLogs(true, false)
  runPtsLogParser(CONFIG.get['CORE_HOST_USER1'],CONFIG.get['REMOTE_PTRADE1_TEMPLATE_DIR_PATH']+'/'+'ers')
  downloadCsvFolderForOldVersion
  downloadJsonForOldVersion
  #downloadTidyLogForOldVersion
  #Actions.checkRtnsDelievery(Dir.getwd + '/templates/old_app_rtns/'+@@time_stamp+'/pts_tidy_3.log', CONFIG.get['CORE_HOST_USER1'])
  stopPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])

end




def buildPtradeAppForLatestLabVersionThread(app_version)
  Actions.createLocalDirs
  Actions.removeOldOutput
  deleteFolderContentsOnRemoteServerIfFolderExist(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], 'Automation/ers')
  deleteFolderContentsOnRemoteServerIfFolderExist(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], 'Automation/ers2')
  createAutomationDirForUser(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  uploadDir2RemoteAutomationFolder(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation')
  buildPtradeNewSchema2(app_version) #CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU']
  uploadDir2RemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation')
  uploadDir2RemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/ers', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/ers')
  uploadDir2RemoteAutomationFolder(CONFIG.get['SAPHIRE_REDIS_HOST1'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['SAPHIRE_REMOTE_HOST1_PWD'], Dir.getwd+'/templates/config',CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation')
  Actions.cleanupMsl(CONFIG.get['CORE_HOST_USER'], CONFIG.get['MSL_HOST2_IP'])
  buildPtradeApp2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], app_version)  #CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU']
  displayPtradeAppVersion(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/upgrade_app_config2/prod.conf', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/config/prod.conf')
  #uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/upgrade_app_config2/fix/rtns/qfj.cfg', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/config/fix/rtns/qfj.cfg')
  createCsvDirsForUserOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  deleteCsvFilesOnRemoteServerForNewVersion
  createCsvDirsForUserOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  restartRedisWithNewConfigForNewVersion2
  restartPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  runRemoteMslSender4upgrade2(CONFIG.get['CORE_HOST_USER'], true, 'ers', CONFIG.get['MSL_HOST2_IP'])
  Actions.downloadPTSLogs(false, true)
  runPtsLogParser(CONFIG.get['CORE_HOST_USER'],CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/'+'ers')
  downloadCsvFolderForNewVersion
  downloadJsonForNewVersion
  #downloadTidyLogForNewVersion
  #Actions.checkRtnsDelievery(Dir.getwd + '/templates/new_app_rtns/'+@@time_stamp+'/pts_tidy_3.log', CONFIG.get['CORE_HOST_USER'])
  stopPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])


end

### scratch end

### Start Upgrade
Given /^Ptrade Apps And Schemas are built for Production for both users$/ do
  threads = []
  old_app_version=CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'].nil? || CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'].to_s.strip.empty? ? '' : CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'].to_s.strip
  t1=Thread.new{buildPtradeAppForProductionVersionAsSourceThread(old_app_version)}
  t1.abort_on_exception = true
  threads << t1
  new_app_version=CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'].nil? || CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'].to_s.strip.empty? ? '' : CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'].to_s.strip
  t2=Thread.new{buildPtradeAppAndUpgradeProductionWithLatestLabVersionThread(new_app_version)}
  t2.abort_on_exception = true
  t1.join
  threads << t2
  t2.join
  ThreadsWait.all_waits(*threads )
  fail('Ptrade App and Schema build failed for user ptrade1') if(t1.status.nil?)
  fail('Ptrade App and Schema build failed for user ptrade') if(t2.status.nil?)

end


def buildPtradeAppForProductionVersionAsSourceThread(app_version)
  sleep CONFIG.get['WAIT_FOR_ONE_THREAD_PTRADE'].to_i
  createAutomationDirForUser(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  # uploadDir2RemoteAutomationFolder(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation')
  buildPtradeOldSchema2(CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'])
  uploadDir2RemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation')
  uploadDir2RemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/ers', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/ers')
  uploadDir2RemoteAutomationFolder(CONFIG.get['SAPHIRE_REDIS_HOST1'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['SAPHIRE_REMOTE_HOST1_PWD'], Dir.getwd+'/templates/config', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation')
  Actions.cleanupMsl(CONFIG.get['CORE_HOST_USER1'], CONFIG.get['MSL_HOST_IP'])
  buildPtradeApp2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], app_version)
  displayPtradeAppVersion(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/old_app_config2/prod.conf', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/PTS/config/prod.conf')
  #uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/old_app_config2/fix/rtns/qfj.cfg', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/PTS/config/fix/rtns/qfj.cfg')
  createCsvDirsForUserOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  restartRedisWithNewConfigForOldVersion2
  restartPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  runRemoteMslSender4upgrade2(CONFIG.get['CORE_HOST_USER1'], true, 'ers', CONFIG.get['MSL_HOST_IP'])
  #Actions.downloadPTSLogs(true, false)
  runPtsLogParser(CONFIG.get['CORE_HOST_USER1'],CONFIG.get['REMOTE_PTRADE1_TEMPLATE_DIR_PATH']+'/'+'ers')
  stopPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])

end




def buildPtradeAppAndUpgradeProductionWithLatestLabVersionThread(app_version)
  createAutomationDirForUser(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  uploadDir2RemoteAutomationFolder(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation')
  buildPtradeNewSchema2(app_version)
  uploadDir2RemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation')
  uploadDir2RemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/ers', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/ers')
  uploadDir2RemoteAutomationFolder(CONFIG.get['SAPHIRE_REDIS_HOST1'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['SAPHIRE_REMOTE_HOST1_PWD'], Dir.getwd+'/templates/config',CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation')
  Actions.cleanupMsl(CONFIG.get['CORE_HOST_USER'], CONFIG.get['MSL_HOST2_IP'])
  buildPtradeApp2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], app_version)
  displayPtradeAppVersion(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/upgrade_app_config2/prod.conf', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/config/prod.conf')
  #uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/upgrade_app_config2/fix/rtns/qfj.cfg', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/config/fix/rtns/qfj.cfg')
  createCsvDirsForUserOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  createCsvDirsForUserOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  restartRedisWithNewConfigForNewVersion2
  restartPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  runRemoteMslSender4upgrade2(CONFIG.get['CORE_HOST_USER'], true, 'ers', CONFIG.get['MSL_HOST2_IP'])
  Actions.downloadPTSLogs(false, true)
  runPtsLogParser(CONFIG.get['CORE_HOST_USER'],CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/'+'ers')
  #downloadTidyLogForNewVersion
  #Actions.checkRtnsDelievery(Dir.getwd + '/templates/new_app_rtns/'+@@time_stamp+'/pts_tidy_3.log', CONFIG.get['CORE_HOST_USER'])
  stopPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])

end




Given /^MslErSender sent another tickets dir for both users$/ do
  er_folder='ers2'
  threads = []
  t1=Thread.new{runRemoteMslSender4upgrade2(CONFIG.get['CORE_HOST_USER1'], true, er_folder, CONFIG.get['MSL_HOST_IP'])}
  t1.abort_on_exception = true
  threads << t1
  t2=Thread.new{runRemoteMslSender4upgrade2(CONFIG.get['CORE_HOST_USER'], true, er_folder, CONFIG.get['MSL_HOST2_IP'])}
  t2.abort_on_exception = true
  t1.join
  threads << t2
  t2.join
  ThreadsWait.all_waits(*threads )
  fail('MslErSender failed for user ptrade1 with folder ' + er_folder) if(t1.status.nil?)
  fail('MslErSender failed for user ptrade with folder ' + er_folder) if(t2.status.nil?)
end



Given /^Ptrade App and Schemas are Upgraded to the Last Sdata and Ptrade Lab version$/ do
  ### Upgrade 2nd App to the latest lab version (or to Custom version if needed)
  if(!CONFIG.get['DEPLOY_SDATA'].nil? && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
    buildSdataSchema('sdata', (CONFIG.get['SDATA_NEW_SCHEMA_VERSION_OU'].nil? || CONFIG.get['SDATA_NEW_SCHEMA_VERSION_OU'].to_s.empty?) ? '' : CONFIG.get['SDATA_NEW_SCHEMA_VERSION_OU'] ) #temp disable
    displaySdataSchemaNewVersion
  else
    Actions.v 'NOT deploying SDATA for Upgrade version'
  end
  upgradePtradeToNewLabVersion
  buildPtradeApp2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'])
  displayPtradeAppAndDbVersionForUpgrade(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/upgrade_app_config2/prod.conf', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/config/prod.conf')
  #uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/upgrade_app_config2/fix/rtns/qfj.cfg', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/config/fix/rtns/qfj.cfg')

end



Then /^Ptrade App is restarted and data downloaded for both users$/ do
  threads = []
  t1=Thread.new{sendErsRestartAndDownloadDataForOldVersion}
  t1.abort_on_exception = true
  threads << t1
  t2=Thread.new{sendErsRestartAndDownloadDataForNewVersion}
  t2.abort_on_exception = true
  t1.join
  threads << t2
  t2.join
  ThreadsWait.all_waits(*threads )
  fail('restartAndDownloadDataForOldVersion failed for user ptrade1') if(t1.status.nil?)
  fail('restartAndDownloadDataForNewVersion failed for user ptrade') if(t2.status.nil?)
end


def sendErsRestartAndDownloadDataForOldVersion
  sleep CONFIG.get['WAIT_FOR_ONE_THREAD_PTRADE'].to_i
  deleteCsvFilesOnRemoteServerForOldVersion
  uploadDir2RemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/ers2', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/ers2')
  restartRedisWithNewConfigForOldVersion2
  runRemoteMslSender4upgrade2(CONFIG.get['CORE_HOST_USER1'], true, 'ers2', CONFIG.get['MSL_HOST_IP'])
  restartPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  Actions.downloadPTSLogs(true, false)
  runPtsLogParser(CONFIG.get['CORE_HOST_USER1'],CONFIG.get['REMOTE_PTRADE1_TEMPLATE_DIR_PATH']+'/'+'ers2')
  downloadCsvFolderForOldVersion
  downloadJsonForOldVersion
  #downloadTidyLogForOldVersion
  #Actions.checkRtnsDelievery(Dir.getwd + '/templates/old_app_rtns/'+@@time_stamp+'/pts_tidy_3.log', CONFIG.get['CORE_HOST_USER1'])
  stopPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])

end




def sendErsRestartAndDownloadDataForNewVersion
  deleteCsvFilesOnRemoteServerForNewVersion
  uploadDir2RemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/ers2', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/ers2')
  #uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/upgrade_app_config2/fix/rtns/qfj.cfg', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/config/fix/rtns/qfj.cfg')
  restartRedisWithNewConfigForNewVersion2
  runRemoteMslSender4upgrade2(CONFIG.get['CORE_HOST_USER'], true, 'ers2', CONFIG.get['MSL_HOST2_IP'])
  restartPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  Actions.downloadPTSLogs(false, true)
  runPtsLogParser(CONFIG.get['CORE_HOST_USER'],CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/'+'ers2')
  downloadCsvFolderForNewVersion
  downloadJsonForNewVersion
  #downloadTidyLogForNewVersion
  #Actions.checkRtnsDelievery(Dir.getwd + '/templates/new_app_rtns/'+@@time_stamp+'/pts_tidy_3.log', CONFIG.get['CORE_HOST_USER'])
  stopPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])

end



### Upgrade scenario end










#########



Then /^DB tables DEAL TICKETS LEGS compared for both versions$/ do
  Actions.compareDbTableResults(CONFIG.get['ORACLE_HOST_TEMPLATE_SCHEMA'],CONFIG.get['ORACLE_HOST_SCHEMA'],@@time_stamp) #PTRADE1,PTRADE
end






Then /^Old and New versions csv Folders are Matched excluding timestamps$/ do
  compareCsvFolders(@@time_stamp)
end


Then /^Old and New versions csv Folders are Matched excluding timestamps atfer scratch$/ do
  compareCsvFolders(@@before_upgrade_timestamp)
end


Then /^Old and New versions csv Folders are Matched excluding timestamps after upgrade$/ do
  compareCsvFolders(@@time_stamp)
end


def compareCsvFolders(time_stamp)
  source_dir = Dir.getwd + '/templates/old_app_csv/'+time_stamp
  target_dir = Dir.getwd + '/templates/new_app_csv/'+time_stamp
  dir_count=Actions.compareCsvDirs(source_dir+'/common', target_dir+'/common')
  Actions.c (dir_count-2).to_s+' folders have been tested in folder common' if(!$csv_folders_count.nil? && !dir_count.nil? && !dir_count[0].to_s.downcase.include?('error'))
  dir_count=Actions.compareCsvDirs(source_dir+'/myt', target_dir+'/myt')
  Actions.c (dir_count-2).to_s+' folders have been tested in folder myt' if(!$csv_folders_count.nil? && !dir_count.nil? && !dir_count[0].to_s.downcase.include?('error'))
  Actions.c $csv_files_count.to_s+' files have been compared' if(!$csv_files_count.nil?)

  if($csv_folders_count.nil? || $csv_folders_count==0)
    @@scenario_fails.push('0 Folders compared')
    Actions.f('0 Folders compared')
    return
  end
  if($csv_files_count.nil? || $csv_files_count==0)
    @@scenario_fails.push('0 Files compared')
    Actions.f('0 Files compared')
  end
end




def compareCsvFolders2(source_dir,target_dir,excluded_fields_arr)
  Actions.v 'Comparing CSV folders source: ' + source_dir + ' and ' + target_dir
  dir_count=Actions.compareCsvDirs2(source_dir,target_dir,excluded_fields_arr)
  Actions.c (dir_count-2).to_s+' folders have been tested in '+source_dir if(!$csv_folders_count.nil? && !dir_count.nil? && !dir_count[0].to_s.downcase.include?('error'))
  Actions.c $csv_files_count.to_s+' files have been compared' if(!$csv_files_count.nil?)

  if($csv_folders_count.nil? || $csv_folders_count==0)
    @@scenario_fails.push('0 Folders compared')
    Actions.f('0 Folders compared')
    return
  end
  if($csv_files_count.nil? || $csv_files_count==0)
    @@scenario_fails.push('0 Files compared')
    Actions.f('0 Files compared')
  end
end


Then /^Old and New Saphire Jsons are Matched excluding sequence$/ do
  template_json =  Dir.getwd + '/templates/old_app_json/'+@@time_stamp+'/RedisMonitor1.txt'
  build_json =  Dir.getwd + '/templates/new_app_json/'+@@time_stamp+'/RedisMonitor.txt'
  @@json_fails=[]

  Actions.c '<b>Comparing Sapphire Jsons...</b>'
  Actions.compareSaphireOutputJsons(template_json, build_json) if(@@json_fails.empty?)
end


Then /^Old and New Saphire Jsons are Matched excluding sequence after scratch$/ do
  template_json =  Dir.getwd + '/templates/old_app_json/'+@@before_upgrade_timestamp+'/RedisMonitor1.txt'
  build_json =  Dir.getwd + '/templates/new_app_json/'+@@before_upgrade_timestamp+'/RedisMonitor.txt'
  @@json_fails=[]

  Actions.c '<b>Comparing Sapphire Jsons...</b>'
  Actions.compareSaphireOutputJsons(template_json, build_json) if(@@json_fails.empty?)
end


Then /^Old and New Saphire Jsons are Matched excluding sequence after upgrade$/ do
  template_json =  Dir.getwd + '/templates/old_app_json/'+@@time_stamp+'/RedisMonitor1.txt'
  build_json =  Dir.getwd + '/templates/new_app_json/'+@@time_stamp+'/RedisMonitor.txt'
  @@json_fails=[]

  Actions.c '<b>Comparing Sapphire Jsons...</b>'
  Actions.compareSaphireOutputJsons(template_json, build_json) if(@@json_fails.empty?)
end


Then /^Old and New versions RTNS outgoing data compared$/ do
  downloadTidyLogForOldVersion
  downloadTidyLogForNewVersion
  log_file_path1=Dir.getwd + '/templates/old_app_rtns/'+@@time_stamp+'/pts_tidy_3.log'
  log_file_path2=Dir.getwd + '/templates/new_app_rtns/'+@@time_stamp+'/pts_tidy_3.log'
  Actions.compareOutgoingRtns(log_file_path1,log_file_path2)
end


Then /^Old and New versions Traiana outgoing data compared as CSV$/ do
  ers_folder = 'ers'
  csv_folder = 'ers_csv'
  Actions.v 'Creating csv from ers for user: ' + CONFIG.get['CORE_HOST_USER1']
  cmd = 'cd '+CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/'+'Automation/PTS/bin && ./er2tickets.sh ../../'+ers_folder+' ../../'+csv_folder
  #cmd = 'cd /export/home/ptrade1/Automation/PTS/bin && ./er2tickets.sh /export/home/ptrade1/Automation/ers /export/home/ptrade1/Automation/ers_csv'
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], cmd, 120, true, '')

  Actions.v res.to_s
  downloadTraianaCsvFolderForOldVersion('old_app_csv_traiana','/export/home/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/'+csv_folder)

  Actions.v 'Creating csv from ers for user: ' + CONFIG.get['CORE_HOST_USER']
  cmd = 'cd '+CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/'+'Automation/PTS/bin && ./er2tickets.sh ../../'+ers_folder+' ../../'+csv_folder
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 120, true, '')
  Actions.v res.to_s
  downloadTraianaCsvFolderForNewVersion('new_app_csv_traiana','/export/home/'+CONFIG.get['CORE_HOST_USER']+'/Automation/'+csv_folder)


  Actions.c('<b> Old and New versions Traiana outgoing data compared as CSV </b>')
  compareCsvFolders2(Dir.getwd + '/templates/old_app_csv_traiana/'+@@time_stamp,Dir.getwd + '/templates/new_app_csv_traiana/'+@@time_stamp,CONFIG.get['TRAIANA_CSV_EXCLUDED_COLUMNS'])
end




Then /^Build and App logs are displayed in Report$/ do
  Actions.SSH_NO_FAIL(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], "/export/home/"+CONFIG.get['CORE_HOST_USER']+'/Automation/PTSlogsParser_ptrade.sh', 120)
  Actions.SSH_NO_FAIL(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], "/export/home/"+CONFIG.get['CORE_HOST_USER1']+'/Automation/PTSlogsParser_ptrade1.sh', 120)
  sleep 20
  Actions.displayFilesForDownloadInFolder(Dir.getwd+'/logs/logs_'+@@time_stamp)
end



########


def createLocalDirs
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates'+' && mkdir db', 10)
  Actions.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir new_app_csv', 10)
  Actions.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir old_app_csv', 10)
  Actions.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir new_app_json', 10)
  Actions.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates'+' && mkdir old_app_json', 10)
  Actions.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates/myt'+' && mkdir source', 10)
  Actions.WINCMD_NO_FAIL('cd '+ Dir.getwd+'/templates/myt'+' && mkdir target', 10)
end






def createAutomationDirForUser(host, user, pwd)
  Actions.v 'Creating Automation dir on host '+host+' for user '+user+'... '
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/ers'
  res = Actions.SSH(host, user, pwd, cmd, 10, true, '')

  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/ers2'
  res = Actions.SSH(host, user, pwd, cmd, 10, true, '')


  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/data'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 10)

  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/data/tickets'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 10)
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/data/tickets/common'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 10)
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/data/tickets/myt'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 10)

end


def createDirForUser(host, user, pwd, dir_path)
  Actions.c 'Creating directory '+dir_path+' on host '+host+' for user '+user+'...'
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+dir_path
  res = Actions.SSH(host, user, pwd, cmd, 10, true, '')
end


def createCsvDirsForUserOnRemoteServer(host, user, pwd)
  Actions.v 'Creating CSV and MyT folders on host '+host+' for user '+user+'... '
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation/data/tickets/myt'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 10)

  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation/data/tickets/common'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 10)

end


def buildPtradeApp(host, user, pwd, script_file, script_path_from, script_path_to,script_param)

  begin
    Actions.v 'Copying build scripts to build App on Ptrade server for user '+user+'... '
    Actions.uploadTemplates2(host, user, pwd, script_path_from+script_file, script_path_to+'/'+script_file,40)

    Actions.c 'Building App on Ptrade server for user '+user+'... '
    cmd = "dos2unix "+script_path_to+'/'+script_file
    res = Actions.SSH(host, user, pwd, cmd, 20, true, '')

    cmd ="chmod 755 "+script_path_to+'/'+script_file
    res = Actions.SSH(host, user, pwd, cmd, 20, false, '')

    cmd << ' && '+script_path_to+'/'+script_file
    cmd << " -n " + script_param if(!script_param.nil? && !script_param.to_s.empty?)
    res = Actions.SSH(host, user, pwd, cmd, 180, false, '')
  rescue Exception=>e
    @@scenario_fails.push('PtradeApp build Failed for user ' + user)
    Actions.displaySanityLogs(false, false, true, false) if(user==CONFIG.get['CORE_HOST_USER'])
    Actions.displaySanityLogs(false, false, false, true) if(user==CONFIG.get['CORE_HOST_USER1'])
    fail('PtradeApp build Failed for user ' + user)
  end

end



def buildPtradeApp2(host, user, pwd, script_param)

  begin
    Actions.c 'Building Ptrade App for user '+user+' on '+host
    Actions.v 'Copying files to build Ptrade App...'

    appInstallScript = ''

    if (user==CONFIG.get['CORE_HOST_USER1'])
      appInstallScript = 'ptradeAPP_build1_install_automatic.sh'
      Actions.uploadTemplates2(CONFIG.get['CORE_HOST'],CONFIG.get['CORE_HOST_USER1'],CONFIG.get['CORE_HOST_PWD'],Dir.getwd+'/templates/bash/'+appInstallScript,CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/'+appInstallScript,40)
      Actions.rigthsForFile(CONFIG.get['CORE_HOST'],CONFIG.get['CORE_HOST_USER1'],CONFIG.get['CORE_HOST_PWD'],CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation',appInstallScript,'755')
    elsif (user==CONFIG.get['CORE_HOST_USER'])
      appInstallScript = 'ptradeAPP_build_install_automatic.sh'
      Actions.uploadTemplates2(CONFIG.get['CORE_HOST'],CONFIG.get['CORE_HOST_USER'],CONFIG.get['CORE_HOST_PWD'],Dir.getwd+'/templates/bash/'+appInstallScript,CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/'+appInstallScript,40)
      Actions.rigthsForFile(CONFIG.get['CORE_HOST'],CONFIG.get['CORE_HOST_USER'],CONFIG.get['CORE_HOST_PWD'],CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation',appInstallScript,'755')
    else
      fail('Not supported user to launch Ptrade App installation: '+user+'. Only users '+CONFIG.get['CORE_HOST_USER']+', '+CONFIG.get['CORE_HOST_USER1']+' allowed')
    end
    Actions.v 'Files for installing the application are copied'

    if (script_param.nil? || script_param.to_s.strip.empty?)
      cmd = 'cd '+CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation && ./'+appInstallScript
    else
      cmd = 'cd '+CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation && ./'+appInstallScript+' -n '+script_param.to_s.strip
    end
    Actions.v 'For user ' +user+ ' script_param is '+script_param.to_s+ ' cmd for execution is ' + cmd
    res = Actions.SSH(host, user, pwd, cmd, 180, false, '')

  rescue Exception=>e
    @@scenario_fails.push('PtradeApp build failed for user ' + user)
    Actions.displaySanityLogs(false, false, true, false) if(user==CONFIG.get['CORE_HOST_USER'])
    Actions.displaySanityLogs(false, false, false, true) if(user==CONFIG.get['CORE_HOST_USER1'])
    fail('PtradeApp build failed for user ' + user)
  end
end


def uploadDirToRemoteAutomationFolder(host, user, pwd, dir_from_path, dir_to_path)
  Actions.v 'Uploading Templates files and scripts from ' +dir_from_path +' to Automation folder on remote server for user '+user+' started... '
  Actions.uploadTemplates2(host, user, pwd, dir_from_path, dir_to_path, 60)
  Actions.v 'Upload of Templates files and scripts from ' +dir_from_path +' to Automation folder on remote server for user '+user+' finished '
  Actions.SSH_NO_FAIL(host, user, pwd, "dos2unix "+dir_to_path+"/*",40)
  Actions.SSH_NO_FAIL(host, user, pwd, "chmod 755 "+dir_to_path+"/*.sh",40)
end

def uploadDir2RemoteAutomationFolder(host, user, pwd, dir_from_path, dir_to_path)
  Actions.v 'Uploading files from ' +dir_from_path +' to Automation folder on remote server for user '+user+'... '
  Actions.uploadTemplates2(host, user, pwd, dir_from_path, dir_to_path,60)
  Actions.SSH_NO_FAIL(host, user, pwd, "dos2unix "+dir_to_path+"/*",20)
  Actions.SSH_NO_FAIL(host, user, pwd, "chmod 755 "+dir_to_path+"/*.sh",20)
end

def uploadDirToRemoteFolder(host, user, pwd, dir_from_path, dir_to_path)
  Actions.v 'Uploading Local folder contents from ' + dir_from_path+' to ' +dir_to_path+' on remote server for user '+user+'... '
  Actions.uploadTemplates2(host, user, pwd, dir_from_path, dir_to_path,60)
  Actions.SSH_NO_FAIL(host, user, pwd, "dos2unix "+dir_to_path+"/*",40)
  Actions.SSH_NO_FAIL(host, user, pwd, "chmod 755 "+dir_to_path+"/*.sh",40)
end


def uploadFileToRemoteFolder(host, user, pwd, file_name, path_from, path_to)
  Actions.c 'Uploading file '+path_from+'/'+file_name+' to ' + path_to+'/'+file_name +' for user '+user+' on host '+host+'... '
  Actions.uploadTemplates2(host, user, pwd, path_from+'/'+file_name, path_to+'/'+file_name,60)
  Actions.SSH_NO_FAIL(host, user, pwd, 'dos2unix '+path_to+'/'+file_name,20)
  Actions.SSH_NO_FAIL(host, user, pwd, "chmod 755 "+path_to+'/'+file_name,60)
end

def uploadFile2RemoteFolder(host, user, pwd, file_name, path_from, path_to)
  Actions.c 'Uploading file '+path_from+'/'+file_name+' to ' + path_to+'/'+file_name +' for user '+user+' on host '+host+'... '
  Actions.uploadTemplates2(host, user, pwd, path_from+'/'+file_name, path_to,60)
end

def stopPtradeService(host, user, pwd)#TODO
  Actions.c 'Stopping PTS services for '+user
  cmd = CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation/PTS/bin/service.sh stop'
  expected_output_rows=['pts_tidy stopped successfully','pts_core stopped successfully','pts_http stopped successfully']
  res = Actions.SSH(host, user, pwd, cmd, 60, true, expected_output_rows)
  Actions.c res.to_s
end


def stopPtradeServiceNoFail(host, user, pwd)
  Actions.c 'Stopping PTS services for '+user
  cmd = CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation/PTS/bin/service.sh stop'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 60)
  # Actions.c res.to_s
  Actions.v res.to_s
end

def stopPtradeOldServiceNoFail(host, user, pwd)
  Actions.c 'Stopping PTS services in Automation_old for '+user
  cmd = CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation_old/PTS/bin/service.sh stop'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 60)
  Actions.c res.to_s
end


def restartPtradeService(host, user, pwd)
  Actions.c 'Restarting PTS service for '+user
  cmd = CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation/PTS/bin/service.sh restart'
  expected_output_rows=['The PTS (module: tidy) is alive','The PTS (module: core) is alive','The PTS (module: http) is alive']
  res = Actions.SSH(host, user, pwd, cmd, 60, true, expected_output_rows) #The PTS (module: tidy) is alive
  Actions.c res.to_s
  sleep 120 #Waitng for Ptrade Started

  cmd ="cat " + CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation/PTS/logs/pts_core_*.log'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 60) #Display Log
  Actions.v '<br>Core Logs -'+res.to_s if(!res.nil?) #if(!res.to_s.downcase.include?('exception')) #!res.to_s.downcase.include?('error') - error printed by default
=begin
  if(!res.nil? && (res.to_s.downcase.include?('error') || res.to_s.downcase.include?('exception')))
    Actions.f '<br>Exceptions or Errors are found in Core Logs -'+res.to_s
    @@scenario_fails.push('<br>Exceptions or Errors are found in Core Logs -'+res.to_s)
    #fail('<br>Exceptions found in Core Logs -'+res.to_s)
  end
=end

  cmd ="cat " + CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation/PTS/logs/pts_tidy_*.log'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 60) #Display Log
  Actions.v '<br>Tidy Logs -'+res.to_s if(!res.nil?) #if(!res.to_s.downcase.include?('exception')) #!res.to_s.downcase.include?('error') - error printed by default
=begin
  if(!res.nil? && (res.to_s.downcase.include?('error') || res.to_s.downcase.include?('exception')))
    Actions.f '<br>Exceptions found in Tidy Logs -'+res.to_s
    @@scenario_fails.push('<br>Exceptions or Errors are found in Tidy Logs -'+res.to_s)
    #fail('<br>Exceptions or Errors are found in Tidy Logs -'+res.to_s)
  end
=end


end


def killRedis(host, user, pwd)
  Actions.v 'Killing Redis and RedisCli... '

  cmd = 'kill -9 $(/sbin/pidof redis-server) >/dev/null 2>&1'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 20)
  #Actions.c 'SSH command output:' +res.to_s

  cmd = 'sleep 3 && /sbin/pidof redis-server'
  res = Actions.SSH(host, user, pwd, cmd, 20, false, '')
  Actions.v 'SSH command output:' +res.to_s if(!res.nil? && !res.to_s.empty?)

  cmd = 'kill -9 $(/sbin/pidof startRedisCli) >/dev/null 2>&1' if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER'])#ptrade
  cmd = 'kill -9 $(/sbin/pidof startRedisCli1) >/dev/null 2>&1' if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER1'])#ptrade1
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 20)
  #Actions.c 'SSH command output:' +res.to_s


end



def killRedisRoot(host)
  #sleep 60
  Actions.v 'Killing Redis and RedisCli... '

  cmd = 'kill -9 $(/sbin/pidof redis-server) >/dev/null 2>&1'
  res = Actions.SSH_NO_FAIL(host, 'root', '123456', cmd, 20)
  #Actions.v 'SSH command output:' +res.to_s

  cmd = 'sleep 5 && /sbin/pidof redis-server'
  res = Actions.SSH(host, 'root', '123456', cmd, 20, false, '')
  Actions.v 'SSH command output:' +res.to_s if(!res.nil? && !res.to_s.empty?)

  cmd = 'kill -9 $(/sbin/pidof startRedisCli) >/dev/null 2>&1'
  res = Actions.SSH_NO_FAIL(host, 'root', '123456', cmd, 10)
  #Actions.v 'SSH command output:' +res.to_s
end

def killRedisRoot2(host, port)
  #sleep 60
  Actions.v 'Killing Redis and RedisCli from root on '+host+':'+port

  rs_existed = false
  rc_existed = false
  # cmd = "/sbin/pidof 'redis-server *:"+port+"'"
  cmd = "/bin/ps -aef|egrep './redis-server'|grep "+port+"|awk '{print $2}'|egrep -v egrep"
  res_pid = Actions.SSH(host, 'root', '123456', cmd, 20, true, '')
  res_pid = res_pid.to_s.strip
  if (!res_pid.nil? && !res_pid.to_s.empty?)
    rs_existed = true
    Actions.v 'Found redis-server process pid ('+res_pid+'), killing it'
    cmd = "kill -9 "+res_pid
    res = Actions.SSH(host, 'root', '123456', cmd, 20, true, '')
    Actions.v 'killRedisRoot2 output: '+res.to_s
  else
    Actions.v 'redis-server process pid not found'
  end


  cmd = "/bin/ps -aef|egrep 'redis-cli -p'|grep "+port+"|awk '{print $2}'|egrep -v egrep"
  res_pid = Actions.SSH(host, 'root', '123456', cmd, 20, true, '')
  res_pid = res_pid.to_s.strip
  if (!res_pid.nil? && !res_pid.to_s.empty?)
    rc_existed = true
    Actions.v 'Found redis-cli process pid ('+res_pid+'), killing it'
    cmd = "kill -9 "+res_pid
    res = Actions.SSH(host, 'root', '123456', cmd, 20, true, '')
    Actions.v 'killRedisRoot2 output: '+res.to_s
  else
    Actions.v 'redis-cli process pid not found'
  end

  # cmd = "sleep 3 && /bin/ps -aef|egrep 'redis-server'|grep "+port+"|awk '{print $2}'"
  if rs_existed
    cmd = "/bin/ps -aef|egrep './redis-server'|grep "+port+"|awk '{print $2}'|egrep -v egrep"
    res = Actions.SSH(host, 'root', '123456', cmd, 20, true, '')
    if (!res.nil? && !res.to_s.empty?)
      Actions.f 'Found redis-server process pid after killing it: '+res.to_s
    else
      Actions.v 'redis-server process pid was not found after killing it'
    end
  end

  # cmd = "sleep 3 && /bin/ps -aef|egrep 'redis-cli'|grep "+port+"|awk '{print $2}'"
  if rc_existed
    cmd = "/bin/ps -aef|egrep 'redis-cli -p'|grep "+port+"|awk '{print $2}'|egrep -v egrep"
    res = Actions.SSH(host, 'root', '123456', cmd, 20, true, '')
    if (!res.nil? && !res.to_s.empty?)
      Actions.f 'Found redis-cli process pid after killing it: '+res.to_s
    else
      Actions.v 'redis-cli process pid was not found after killing it'
    end
  end
end

def killRedisForUser(host, user, port)
  if (user != CONFIG.get['CORE_HOST_USER'] && user != CONFIG.get['CORE_HOST_USER1'])
    fail('Only users "'+CONFIG.get['CORE_HOST_USER']+'" and "'+CONFIG.get['CORE_HOST_USER1']+'" are allowed for killRedisForUser')
  end
  Actions.v 'Killing Redis and RedisCli on '+host+':'+port+' for user '+user

  cmd = "kill -9 $(/bin/ps -u "+user+" -f|egrep 'redis-server'|grep "+port+"|awk '{print $2}')"
  res = Actions.SSH(host, user, CONFIG.get['CORE_HOST_PWD'], cmd, 20, true, '')
  Actions.v 'killRedisOfUser output:' +res.to_s if(!res.nil? || !res.to_s.empty?)

  cmd = "kill -9 $(/bin/ps -u "+user+" -f|egrep 'redis-cli'|grep "+port+"|awk '{print $2}')"
  res = Actions.SSH(host, user, CONFIG.get['CORE_HOST_PWD'], cmd, 20, true, '')
  Actions.v 'killRedisOfUser output:' +res.to_s if(!res.nil? || !res.to_s.empty?)
end


def displayPtradeAppVersion(host, user, pwd)
  cmd =  'ls -l '+@@CONFIG['REMOTE_HOME']+'/'+user+'/Automation/PTS'
  res = Actions.SSH(host, user, pwd, cmd, 20, true, '')
  Actions.c '<b>App Version - '+res.to_s+'</b>'
  r=res.split(' ')
  fail('An App is not installed') if(r[10].nil?)
  #$app_version=r[10].gsub!('/export/home/'+user+'/Automation/packages/','').to_s
  $app_version =  Actions.displayTarVersion(CONFIG.get['CORE_HOST_USER'], false) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER'])#ptrade
  $app_version =  Actions.displayTarVersion(CONFIG.get['CORE_HOST_USER1'], false) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER1'])#ptrade1
  Actions.c '<b>Ptrade App and Schema version - '+$app_version.to_s+' for user ' + user+ '</b>'
  Actions.setBuildProperty('APP_VERSION', $app_version.to_s) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER'].to_s.downcase)
end

def displayPtradeAppOnlyVersion(host, user, pwd)
  if (user.to_s.downcase==CONFIG.get['CORE_HOST_USER'])#ptrade
    cmd =  'ls -l '+CONFIG['REMOTE_HOME']+'/'+user+'/Automation/PTS' if(CONFIG['PTRADE_APP_EXTRACT_FOLDER'].nil? || CONFIG['PTRADE_APP_EXTRACT_FOLDER'].to_s.empty?)
    cmd =  'ls -l '+CONFIG['PTRADE_APP_EXTRACT_FOLDER']+'PTS' if(!CONFIG['PTRADE_APP_EXTRACT_FOLDER'].nil? || !CONFIG['PTRADE_APP_EXTRACT_FOLDER'].to_s.empty?)
  elsif (user.to_s.downcase==CONFIG.get['CORE_HOST_USER1'])#ptrade1
    cmd =  'ls -l '+CONFIG['REMOTE_HOME']+'/'+user+'/Automation/PTS' if(CONFIG['PTRADE_APP1_EXTRACT_FOLDER'].nil? || CONFIG['PTRADE_APP1_EXTRACT_FOLDER'].to_s.empty?)
    cmd =  'ls -l '+CONFIG['PTRADE_APP1_EXTRACT_FOLDER']+'PTS' if(!CONFIG['PTRADE_APP1_EXTRACT_FOLDER'].nil? || !CONFIG['PTRADE_APP1_EXTRACT_FOLDER'].to_s.empty?)
  else
    fail('Only users '+CONFIG.get['CORE_HOST_USER']+' or '+CONFIG.get['CORE_HOST_USER1']+' are allowed to perform an action')
  end
  res = Actions.SSH(host, user, pwd, cmd, 20, true, '')
  r=res.split(' ')
  fail('The App is not installed') if(r[10].nil?)
  Actions.v 'App version from PTS link: '+r

  #$app_version=r[10].gsub!('/export/home/'+user+'/Automation/packages/','').to_s
  $app_version =  Actions.displayTarVersion(CONFIG.get['CORE_HOST_USER'], false) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER'])#ptrade
  $app_version =  Actions.displayTarVersion(CONFIG.get['CORE_HOST_USER1'], false) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER1'])#ptrade1
  Actions.c '<b>Ptrade App version - '+$app_version.to_s+'</b>'
  Actions.setBuildProperty('APP_VERSION', $app_version.to_s)
end

def displayPtradeAppOnlyVersion2(host, user, pwd)
  if (user.to_s.downcase==CONFIG.get['CORE_HOST_USER'])#ptrade
    cmd =  'ls -l '+CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation/PTS' if(CONFIG.get['PTRADE_APP_INSTALL_FOLDER'].nil? || CONFIG.get['PTRADE_APP_INSTALL_FOLDER'].to_s.empty?)
    cmd =  'ls -l '+CONFIG.get['PTRADE_APP_INSTALL_FOLDER']+'/PTS' if(!CONFIG.get['PTRADE_APP_INSTALL_FOLDER'].nil? || !CONFIG.get['PTRADE_APP_INSTALL_FOLDER'].to_s.empty?)
  elsif (user.to_s.downcase==CONFIG.get['CORE_HOST_USER1'])#ptrade1
    cmd =  'ls -l '+CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation/PTS' if(CONFIG.get['PTRADE_APP1_INSTALL_FOLDER'].nil? || CONFIG.get['PTRADE_APP1_INSTALL_FOLDER'].to_s.empty?)
    cmd =  'ls -l '+CONFIG.get['PTRADE_APP1_INSTALL_FOLDER']+'/PTS' if(!CONFIG.get['PTRADE_APP1_INSTALL_FOLDER'].nil? || !CONFIG.get['PTRADE_APP1_INSTALL_FOLDER'].to_s.empty?)
  else
    fail('Only users '+CONFIG.get['CORE_HOST_USER']+' or '+CONFIG.get['CORE_HOST_USER1']+' are allowed to perform an action')
  end
  res = Actions.SSH(host, user, pwd, cmd, 20, true, '')
  r=res.split(' ')
  fail('The App is not installed') if(r[10].nil?)
  Actions.v 'App version from PTS link: '+r.to_s if(!r.nil?)

  $app_version =  Actions.displayTarVersion2(CONFIG.get['CORE_HOST_USER'], false) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER'])
  $app_version =  Actions.displayTarVersion2(CONFIG.get['CORE_HOST_USER1'], false) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER1'])
  Actions.c '<b>Ptrade App version - '+$app_version.to_s+'</b>'
  Actions.setBuildProperty('APP_VERSION', $app_version.to_s)
end

def displayPtradeDbVersion(host, user, pwd)
  $app_version =  Actions.displayTarVersion2(CONFIG.get['CORE_HOST_USER'], true) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER'])#ptrade
  $app_version =  Actions.displayTarVersion2(CONFIG.get['CORE_HOST_USER1'], true) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER1'])#ptrade1
  Actions.c '<b>Ptrade DB Schema version - '+$app_version.to_s+'</b>'
  Actions.setBuildProperty('DB_VERSION', $app_version.to_s)
end


def displayPtradeAppAndDbVersionForUpgrade(host, user, pwd)

  cmd =  'ls -l '+@@CONFIG['REMOTE_HOME']+'/'+user+'/Automation/PTS'
  res = Actions.SSH(host, user, pwd, cmd, 20, true, '')
  Actions.c '<b>App Version - '+res.to_s+'</b>'
  r=res.split(' ')
  fail('An App is not installed') if(r[10].nil?)
  #$app_version=r[10].gsub!('/export/home/'+user+'/Automation/packages/','').to_s

  $app_version =  Actions.displayTarVersion(CONFIG.get['CORE_HOST_USER'], true) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER'])#ptrade
  $app_version =  Actions.displayTarVersion(CONFIG.get['CORE_HOST_USER1'], true) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER1'])#ptrade1
  Actions.c '<b>Ptrade App and Schema version - '+$app_version.to_s+'</b>'
  Actions.setBuildProperty('APP_VERSION', $app_version.to_s)

end


def displayPtradeDbVersionForUpgrade(user)
  $app_version =  Actions.displayTarVersion(CONFIG.get['CORE_HOST_USER'], true) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER'])
  $app_version =  Actions.displayTarVersion(CONFIG.get['CORE_HOST_USER1'], true) if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER1'])
  Actions.c '<b>Ptrade App and Schema version - '+$app_version.to_s+'</b>'
  Actions.setBuildProperty('APP_VERSION', $app_version.to_s)

end


def displaySdataSchemaOldVersion
  $app_version = Actions.displayTarVersion(CONFIG.get['ORACLE_SDATA_HOST_TEMPLATE_SCHEMA'], true)#sdata1
  Actions.c '<b>Sdata Old Schema Version - '+$app_version.to_s+'</b>'
  Actions.setBuildProperty('SCHEMA_VERSION', $app_version.to_s)
end


def displaySdataSchemaNewVersion
  $app_version =  Actions.displayTarVersion(CONFIG.get['ORACLE_SDATA_HOST_SCHEMA'], true)#sdata
  Actions.c '<b>Sdata Last Schema Version - '+$app_version.to_s+'</b>'
  Actions.setBuildProperty('SCHEMA_VERSION', $app_version.to_s)

end


def deleteSaphireRedisOutputOnRemoteServerForOldVersion
  deleteSaphireRedisOutputOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
end


def deleteSaphireRedisOutputOnRemoteServerForNewVersion
  deleteSaphireRedisOutputOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
end


def deleteSaphireRedisOutputOnRemoteServer(host, user, pwd)
  fail('Expecting users - ' +CONFIG.get['CORE_HOST_USER']+ ' or ' +CONFIG.get['CORE_HOST_USER']) if(user!=CONFIG.get['CORE_HOST_USER'] || user!=CONFIG.get['CORE_HOST_USER1'])
  cmd = 'rm -f /export/home/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/RedisMonitor1.txt' if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER1'])
  cmd = 'rm -f /export/home/'+CONFIG.get['CORE_HOST_USER']+'/Automation/RedisMonitor.txt' if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER'])
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 10)
end


def deleteFolderContentsOnRemoteServer(host, user, pwd, dir_path)
  cmd = 'mkdir -p '+dir_path+' && cd '+dir_path+' && rm -rf *'
  res = Actions.SSH(host, user, pwd, cmd, 20, false, '')
end


def deleteFolderContentsOnRemoteServerIfFolderExist(host, user, pwd, dir_path)
  cmd = 'cd /export/home/'+user+'/'+dir_path+' && rm -rf *'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 20)
end



def deleteCsvFilesOnRemoteServerForOldVersion
  Actions.v 'Deleting contents of MyT csv tickets - ' + @@CONFIG['MYT_CSV_REMOTE_DIR_PATH1'] + ' on ' + CONFIG.get['CORE_HOST']
  deleteFolderContentsOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/data/tickets')
  deleteFolderContentsOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/data/tickets/common')
  deleteFolderContentsOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/data/tickets/myt')
end


def deleteCsvFilesOnRemoteServerForNewVersion
  Actions.v 'Deleting contents of MyT csv tickets - ' + @@CONFIG['MYT_CSV_REMOTE_DIR_PATH'] + ' on ' + CONFIG.get['CORE_HOST']
  deleteFolderContentsOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/data/tickets')
  deleteFolderContentsOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/data/tickets/common')
  deleteFolderContentsOnRemoteServer(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/data/tickets/myt')
end


def restartRedisWithNewConfig(host, user, pwd, remote_dir, script_name)
  Actions.v 'Copying redis-cli script to redis src for user '+user+' ... '
  cmd = "cp -f "+remote_dir+'/'+script_name+' '+'$HOME/redis/src' \
         +" && sleep 3"\
         +" && dos2unix $HOME/redis/src/"+script_name\
         +" && chmod 755 "+ '$HOME/redis/src/'+script_name \
         +" && sleep 1"

  res = Actions.SSH(host, user, pwd, cmd, 20, true, '') #TODO fetch output
  Actions.c 'Restarting Redis with new config... Redis output redirected to $HOME/Automation/RedisMonitor*.txt'

  cmd = "cd $HOME/redis/src && ./startRedisCli.sh" if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER'])#ptrade
  cmd = "cd $HOME/redis/src && ./startRedisCli1.sh" if(user.to_s.downcase==CONFIG.get['CORE_HOST_USER1'])#ptrade1
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 20)


end

def restartRedisWithNewConfig2(host, user, pwd, remote_dir, script_name, port)
  if (user != CONFIG.get['CORE_HOST_USER'] && user != CONFIG.get['CORE_HOST_USER1'])
    fail('Only users '+CONFIG.get['CORE_HOST_USER']+' and '+CONFIG.get['CORE_HOST_USER1']+' are allowed for restartRedisWithNewConfig2')
  end

  Actions.v 'Copying startRedisCli script to redis src for user '+user+' on '+host
  cmd = "cp -f "+remote_dir+"/"+script_name+" /export/home/"+user+"/redis/src"\
         +" && dos2unix /export/home/"+user+"/redis/src/"+script_name\
         +" && chmod 755 /export/home/"+user+"/redis/src/"+script_name
  res = Actions.SSH(host, user, pwd, cmd, 30, true, '')
  Actions.c 'Restarting Redis with new config on '+host+':'+port+' for user '+user+'... Redis output redirected to /export/home/'+user+'/Automation/RedisMonitor*.txt'


  cmd = "cd /export/home/"+user+"/redis/src && ./"+script_name+" redisPort: "+port
  res = Actions.SSH(host, user, pwd, cmd, 20, false, '')
  # Actions.f 'Output found while starting redis: '+res.to_s if(!res.nil? && !res.to_s.empty?)

  cmd = "sleep 3 && /bin/ps -aef|egrep './redis-server'|grep "+port+"|awk '{print $2}'|egrep -v egrep"
  res = Actions.SSH(host, user, pwd, cmd, 20, true, '')
  res = res.to_s.strip
  if (res.nil? && res.to_s.empty?)
    Actions.f 'redis-server process pid NOT FOUND after starting redis'
  else
    Actions.v 'Found redis-server process pid after starting redis: '+res
  end
end


def restartRedisWithNewConfigForOldVersion
  restartRedisWithNewConfig(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation', 'startRedisCli1.sh')
end

def restartRedisWithNewConfigForOldVersion2
  restartRedisWithNewConfig2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation', 'startRedisCli1_custom.sh', '6389')
end

def restartRedisWithNewConfigForNewVersion
  restartRedisWithNewConfig(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation', 'startRedisCli.sh')
end

def restartRedisWithNewConfigForNewVersion2
  restartRedisWithNewConfig2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation', 'startRedisCli_custom.sh', '6399')
end


def submitErs
  $cmd_res=nil
  $exec_id=nil
  $er=nil

  Actions.c 'Running MSLErSender with ers folder'
  $cmd_res = Actions::WINCMD('cd ' +Dir.getwd+'/libs/MSLErSender/bin & mslErSender.bat ers ', 120, 'txt with execId') #Run ER Simulator
  $exec_ids = $cmd_res.to_s.scan(/txt with execId(.*?)\[(.*?)\]/i)
  #$exec_id = $exec_ids[0][1]
  Actions.c '<br>'+'Following ExecIDs are Found - ' + $exec_ids.to_s + '<br>'

end


def runRemoteMslSenderForOldVersion
  runRemoteMslSender(CONFIG.get['CORE_HOST_USER1'], "Old")#ptrade1
end


def runRemoteMslSenderForNewVersion
  runRemoteMslSender(CONFIG.get['CORE_HOST_USER'], "New")#ptrade
end


def runRemoteMslSender(user, version)#TODO Actions
  cmd =  "cd $HOME/Automation && dos2unix *.sh"
  res = Actions.SSH_NO_FAIL(CONFIG.get['CORE_HOST'], user, CONFIG.get['CORE_HOST_PWD'], cmd, 120)

  Actions.c('<b>Running MslErSender on '+CONFIG.get['CORE_HOST'].to_s+' with export/home/'+user+'/Automation/ers folder</b>')
  cmd =  "cd $HOME/MSLErSender_1.2/bin && ./mslErSender.sh -i 100 -s $HOME/Automation/ers/ -pid"
  res = Actions.SSH(CONFIG.get['CORE_HOST'], user, CONFIG.get['CORE_HOST_PWD'], cmd, 120, true, 'txt with execId')
  Actions.v 'MslSender output - '+res.to_s

  e1='exception'
  e2='error'
  if (res.to_s.downcase.include?(e1) || res.to_s.downcase.include?(e2))
    @@scenario_fails.push('MslSender responded with Errors for '+version+' version')
    fail('MslSender responded with Errors for '+version+ ' version')
  end


  Actions.v 'Waiting for Core for ' + CONFIG.get['WAIT_FOR_MSL_PROCESSING_SECS'].to_s + ' secs'
  sleep CONFIG.get['WAIT_FOR_MSL_PROCESSING_SECS']

  runPtsLogParser(user, CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation/ers') #for upgrade scenario1, not used in Upgrade2

end


def runRemoteMslSender4upgrade2(user, randomExecId, er_folder, mslIP)#TODO Actions
  Actions.c('<b>Running MslErSender on '+CONFIG.get['CORE_HOST'].to_s+' with export/home/'+user+'/Automation/'+er_folder+' folder</b>')
  cmd =  "cd $HOME/MSLErSender_1.2_"+mslIP+"/bin && ./mslErSender.sh -i 100 -s $HOME/Automation/"+er_folder+"/ -pid" if(randomExecId)
  cmd =  "cd $HOME/MSLErSender_1.2_"+mslIP+"/bin && ./mslErSender.sh -i 100 -s $HOME/Automation/"+er_folder+"/" if(!randomExecId)
  res = Actions.SSH(CONFIG.get['CORE_HOST'], user, CONFIG.get['CORE_HOST_PWD'], cmd, 120, true, 'txt with execId')

  if(!res.nil? && (res.to_s.downcase.include?('error') || res.to_s.downcase.include?('exception')))
    Actions.f 'Exceptions or errors are found in MslSender logs for '+user+': '+res.to_s
    @@scenario_fails.push('Exceptions or errors are found in MslSender logs for '+user+': '+res.to_s)
    fail('Exceptions or errors are found in MslSender logs for '+user+': '+res.to_s)
  end

  sleep 20
  Actions.v 'MslSender output - '+res.to_s

  Actions.v 'Waiting for Core for ' + CONFIG.get['WAIT_FOR_MSL_PROCESSING_SECS'].to_s + ' secs'
  sleep CONFIG.get['WAIT_FOR_MSL_PROCESSING_SECS']

end



def runPtsLogParser(user,ers_path)
  Actions.v 'Running PtsLogParser for Log Errors'

  if (user == CONFIG.get['CORE_HOST_USER1'] || user == CONFIG.get['CORE_HOST_USER'])
    Actions.rigthsForFile(CONFIG.get['CORE_HOST'], user, CONFIG.get['CORE_HOST_PWD'], '$HOME/Automation','PTSlogsParser_'+user+'.sh','755')
    res = Actions.SSH_NO_FAIL(CONFIG.get['CORE_HOST'], user, CONFIG.get['CORE_HOST_PWD'], '$HOME/Automation/PTSlogsParser_'+user+'.sh ers_path: '+ers_path, 120)
  else
    Actions.f('Invalid user '+user+' exiting PtsLogParser')
    return
  end

  if (!res.to_s.include?('No difference found'))
    @@scenario_fails.push('PtsLogParser responded with Errors for '+user+res.to_s)
    Actions.f('PtsLogParser Error output - ' + res.to_s)
    fail('PtsLogParser responded with Errors for '+user)
  else
    Actions.c('PtsLogParser output - ' + res.to_s)
  end
end



def downloadFileFromRemote(host, user, pwd, local_target_dir, remote_dir, file_name)#TODO Actions
  Actions.WINCMD_NO_FAIL('cd ' +local_target_dir+' & mkdir ' +  @@time_stamp, 10)
  sleep 3
  Actions.downloadRemoteFile(host, user, pwd, remote_dir+'/'+file_name, local_target_dir+'/'+@@time_stamp+'/'+file_name)
  #sleep 5
end



def downloadJsonForOldVersion
  Actions.v('Downloading Sapphire Json for Old Version')
  downloadFileFromRemote(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'],Dir.getwd+'/templates/old_app_json',  '/export/home/'+CONFIG.get['CORE_HOST_USER1']+'/Automation', 'RedisMonitor1.txt')
end


def downloadJsonForNewVersion
  Actions.v('Downloading Sapphire Json for New Version')
  downloadFileFromRemote(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/new_app_json', '/export/home/'+CONFIG.get['CORE_HOST_USER']+'/Automation',  'RedisMonitor.txt')
end



def downloadTidyLogForOldVersion
  Actions.v('Downloading Sapphire Json for Old Version')
  downloadFileFromRemote(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'],Dir.getwd+'/templates/old_app_rtns',  '/export/home/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/PTS/logs', 'pts_tidy_3.log')
end


def downloadTidyLogForNewVersion
  Actions.v('Downloading Sapphire Json for New Version')
  downloadFileFromRemote(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/new_app_rtns', '/export/home/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/logs', 'pts_tidy_3.log')
end


def downloadDirFromRemote(host, user, pwd, local_target_dir, remote_dir)
  Actions.WINCMD_NO_FAIL('cd ' +local_target_dir+' & mkdir ' +  @@time_stamp, 10)
  Actions.v ' Download to '+local_target_dir+'/'+@@time_stamp+ ' started...'
  Actions.downloadRemoteDir(host, user, pwd, remote_dir, local_target_dir+'/'+@@time_stamp)
  Actions.v ' Download to '+local_target_dir+'/'+@@time_stamp+ ' finished'
end

def downloadDirFromRemoteWithCreateDir(host, user, pwd, local_target_dir, create_dir, remote_dir)
  Actions.WINCMD_NO_FAIL('cd ' +local_target_dir+' & mkdir ' +  create_dir, 10)
  Actions.downloadRemoteDir(host, user, pwd, remote_dir, local_target_dir+'/'+create_dir)
end



def downloadDirFromRemote2(host, user, pwd, local_target_dir, remote_dir)
  begin
    Actions.downloadRemoteDir(host, user, pwd, remote_dir, local_target_dir)
  rescue Exception=>e
    Actions.f('No logs found on remote server ' + host + ' for user ' + user + ' in folder' + remote_dir + ' Error - '+e.message)
    @@scenario_fails.push(e.message)
  end
end


def downloadCsvFolderForOldVersion
  Actions.c 'Downloading MyT And Common csv files from Remote Folder for Old Version'
  downloadDirFromRemote(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/old_app_csv', CONFIG.get['MYT_CSV_REMOTE_DIR_PATH1'])
end


def downloadTraianaCsvFolderForOldVersion(local_folder_path,remote_folder_path)
  Actions.c 'Downloading Traiana csv files from Remote Folder for Old Version'
  downloadDirFromRemote(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/'+local_folder_path, remote_folder_path)
end



###logs
def downloadDblogsForPtradeOldVersion
  Actions.v 'Downloading DB install logs for PTRADE schema old version '
  downloadDirFromRemote2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/logs_PT_DB1')
  #Actions.displayFilesForDownloadInFolder(folder_path)
end

def downloadDblogsForPtradeNewVersion
  Actions.v 'Downloading DB install logs for PTRADE schema last version '
  downloadDirFromRemote2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/logs_PT_DB')
end

def downloadDblogsForSdataOldVersion
  Actions.v 'Downloading DB install logs for SDATA schema old version '
  downloadDirFromRemote2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/logs_SDATA1')
end

def downloadDblogsForSdataNewVersion
  Actions.v 'Downloading DB install logs for SDATA schema last version '
  downloadDirFromRemote2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/logs_SDATA')
end


def downloadAppLogsForOldVersion
  Actions.v 'Downloading App install logs for old version '
  downloadDirFromRemote2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER1']+'/Automation/logs_PT_APP1')
end

def downloadAppLogsForNewVersion
  Actions.v 'Downloading App install logs for last version '
  downloadDirFromRemote2(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/logs/logs_'+@@time_stamp, CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/logs_PT_APP')
end


#### end logs


def downloadCsvFolderForNewVersion
  Actions.c 'Downloading MyT And Common csv files from Remote Folder for New Version'
  downloadDirFromRemote(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/new_app_csv', CONFIG.get['MYT_CSV_REMOTE_DIR_PATH'])
end



def downloadTraianaCsvFolderForNewVersion(local_folder_path,remote_folder_path)
  Actions.c 'Downloading Traiana csv files from Remote Folder for New Version'
  downloadDirFromRemote(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/'+local_folder_path, remote_folder_path)
end


def buildPtradeOldSchema(version)
  begin
    customPtradeOldSchemaDeploy(version)
  rescue Exception=>e
    @@scenario_fails.push('PtradeOldSchemaDeploy Failed for version ' + version)
    Actions.displaySanityLogs(false, false, false, true)
    fail('PtradeOldSchemaDeploy Failed for version ' + version)
  end
end

def buildPtradeOldSchema2(version)
  begin
    customPtradeOldSchemaDeploy2(version)
  rescue Exception=>e
    @@scenario_fails.push('PtradeOldSchemaDeploy Failed for version ' + version + (e.message.nil? ? '' : e.message))
    Actions.displaySanityLogs(false, false, false, true)
    fail('PtradeOldSchemaDeploy Failed for version ' + version)
  end
end

def buildPtradeNewSchema(version)
  begin
    customPtradeNewSchemaDeploy(version)
  rescue Exception=>e
    @@scenario_fails.push('PtradeNewSchemaDeploy Failed for version ' + version)
    Actions.displaySanityLogs(false, false, true, false)
    fail('PtradeNewSchemaDeploy Failed for version ' + version) if(!version.to_s.strip.empty?)
    fail('PtradeNewSchemaDeploy Failed for the Last version ') if(version.to_s.strip.empty?)
  end
end


def buildPtradeNewSchema2(version)
  begin
    customPtradeNewSchemaDeploy2(version)
  rescue Exception=>e
    @@scenario_fails.push('PtradeNewSchemaDeploy failed for version ' + version)
    Actions.displaySanityLogs(false, false, true, false)
    fail('PtradeNewSchemaDeploy failed for version ' + version) if(!version.to_s.strip.empty? || !version.nil?)
    fail('PtradeNewSchemaDeploy failed for the Last version ') if(version.to_s.strip.empty? || version.nil?)
  end
end


def buildSdataSchema(user, version)
  if(!user.nil? && !user.to_s.empty? && user.to_s.downcase=='sdata1')
    Actions.v 'Building schema on Oracle server '+CONFIG.get['ORACLE_HOST']+' for user '+user
    #Old Schema
    Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/buildSchema_sdata1.sh', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/buildSchema_sdata1.sh',40)
    Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/db_config_sdata1_example.sql', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/db_config_sdata1_example.sql',40)
    Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/sdata_schema1_install_automatic.sh', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema1_install_automatic.sh',40)

    #Old Schema
    Actions.c 'Building SDATA DB Schema version "'+CONFIG.get['SDATA_OLD_SCHEMA_VERSION']+'" for '+CONFIG.get['ORACLE_HOST']+':sdata1 from scratch...'

    cmd =  "dos2unix "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/*.sh && chmod 755 '+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/*.sh && dos2unix '+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/*.sql'
    Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema1_install_automatic.sh -n " +version if(!version.nil? && !version.to_s.strip.empty?)
    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema1_install_automatic.sh" +version if(version.nil? || version.to_s.strip.empty?)
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 600, true, '')

    Actions.v '<b>SDATA DB Schema Version "'+CONFIG.get['SDATA_OLD_SCHEMA_VERSION']+'" is built for user '+user+' on '+CONFIG.get['ORACLE_HOST']+'</b>'

  end

  if(!user.nil? && !user.to_s.empty? && user.to_s.downcase=='sdata')    # sdata new version

    Actions.v 'Building schema on Oracle server '+CONFIG.get['ORACLE_HOST']+' for user '+user
    #Last Schema
    Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/db_config_sdata_example.sql', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/db_config_sdata_example.sql',40)
    Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/sdata_schema_install_automatic.sh', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema_install_automatic.sh',40)

    #Last Schema
    Actions.c 'Building LAST SDATA DB Schema for '+CONFIG.get['ORACLE_HOST']+':sdata from scratch... '
    cmd =  "dos2unix "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema_install_automatic.sh"\
         +" && chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema_install_automatic.sh'
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

    cmd="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema_install_automatic.sh'
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')


    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema_install_automatic.sh -n " +version if(!version.nil? && !version.to_s.strip.empty?)
    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema_install_automatic.sh"  if(version.nil? || version.to_s.strip.empty?)
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 600, true, '')

    Actions.v '<b>SDATA DB Schema Last version is built for user '+user+' on '+CONFIG.get['ORACLE_HOST']+'</b>'
  end


end


def moveAutomationDir(host, user, pwd)
  Actions.v 'Renaming Automation into Automation_old and creating empty Automation dir on host '+host+' for user '+user+'... '
  cmd = 'rm -rf Automation_old && mv Automation Automation_old && mkdir -p Automation' #'mkdir -p Automation && mv Automation Automation_old && mkdir -p Automation'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 20)
end


#########Custom Build##########
Given /^Sdata Schema is Built$/ do
  Actions.createLocalDirs
  steps %Q{
    Given Automation dir exist on oracle server
    Given DB Sdata Custom Schema is built
  }
  displaySdataSchemaNewVersion

end

Given /^Sdata Schema is built for LAB$/ do
  Actions.isIpValidInParams
  CONFIG.get['ORACLE_HOST'] = CONFIG.get['ORACLE_HOST_IP']
  CONFIG.get['CORE_HOST'] = CONFIG.get['CORE_HOST_IP']

  if (CONFIG.get['PTRADE_SCHEMA'] != 'ptrade' && CONFIG.get['PTRADE_SCHEMA'] != 'ptrade1')
    Actions.f 'ERROR: "PTRADE_SCHEMA" can be either "ptrade" or "ptrade1"'
    fail('ERROR: "PTRADE_SCHEMA" can be either "ptrade" or "ptrade1"')
  end

  Actions.createLocalDirsTemplatesLogsDb
  steps %Q{
    Given Automation dir exist on oracle server
    Given DB Sdata Custom Schema is built for LAB
  }

  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade'
    displayDbSchemaVersion2('SDATA')
  elsif CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    displayDbSchemaVersion2('SDATA1')
  end

end



Given /^Ptrade App and Schema are Built$/ do
  Actions.createLocalDirs
  steps %Q{
    Given Automation dir exist on oracle server
  }

  if(ENV['PTRADE_OLD_SCHEMA_VERSION'].nil?)
    customPtradeSchemaDeploy(nil)
    customPtradeAppDeploy(nil)
    #downloadDblogsForPtradeNewVersion
    #downloadAppLogsForNewVersion

  else
    customPtradeSchemaDeploy(ENV['PTRADE_OLD_SCHEMA_VERSION'])
    customPtradeAppDeploy(ENV['PTRADE_OLD_SCHEMA_VERSION'])
    #downloadDblogsForPtradeOldVersion
    #downloadAppLogsForOldVersion
  end

end

def failIfNotArray(examinee)
  if examinee.kind_of?(Array)
    # Actions.v ''
  else
    fail('Please give a correct array of parameters to check')
  end
end


def checkMandatoryParams(params_array)
  failIfNotArray(params_array)
  params_array.each { |param| fail('Please define missing mandatory parameter "'+param+'"') if(CONFIG.get[param].nil? || CONFIG.get[param.to_s].to_s.empty?) }
  Actions.v 'Mandatory parameters "'+params_array.join(",")+'" are not empty'
end

Given /^Ptrade App and Schema are built for LAB$/ do
  Actions.isIpValidInParams
  CONFIG.get['ORACLE_HOST'] = CONFIG.get['ORACLE_HOST_IP']
  CONFIG.get['CORE_HOST'] = CONFIG.get['CORE_HOST_IP']

  if (CONFIG.get['PTRADE_SCHEMA'] != 'ptrade' && CONFIG.get['PTRADE_SCHEMA'] != 'ptrade1')
    Actions.f 'ERROR: "PTRADE_SCHEMA" can be either "ptrade" or "ptrade1"'
    fail('ERROR: "PTRADE_SCHEMA" can be either "ptrade" or "ptrade1"')
  end

  ENV['PTRADE_NEW_APP_VERSION_OU'] = ENV['PTRADE_NEW_SCHEMA_VERSION_OU'] if(ENV['PTRADE_NEW_APP_VERSION_OU'].nil? && ENV['PTRADE_NEW_APP_VERSION_OU'].to_s.empty?)

  Actions.createLocalDirsTemplatesLogsDb
  steps %Q{
    Given Automation dir exists on oracle server2
    Given Automation dir exists on ptrade server2
  }

  stopRegularPtradeServiceNoFails(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])

  if(ENV['PTRADE_NEW_SCHEMA_VERSION_OU'].nil? && ENV['PTRADE_NEW_SCHEMA_VERSION_OU'].to_s.empty?)
    customPtradeSchemaDeployLab(nil)
    #downloadDblogsForPtradeNewVersion
  else
    customPtradeSchemaDeployLab(ENV['PTRADE_NEW_SCHEMA_VERSION_OU'])
    #downloadDblogsForPtradeNewVersion
  end

  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade'
    displayDbSchemaVersion2('PTRADE')
  elsif CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    displayDbSchemaVersion2('PTRADE1')
  end

  if(ENV['PTRADE_NEW_APP_VERSION_OU'].nil? && ENV['PTRADE_NEW_APP_VERSION_OU'].to_s.empty?)
    customPtradeAppDeployLab(nil)
    #downloadAppLogsForNewVersion
  else
    customPtradeAppDeployLab(ENV['PTRADE_NEW_APP_VERSION_OU'])
    #downloadAppLogsForNewVersion
  end

  displayPtradeAppOnlyVersion2(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
end


Given /^Ptrade App, Schema and optional Sdata are upgraded for LAB$/ do
  Actions.isIpValidInParams
  CONFIG.get['ORACLE_HOST'] = CONFIG.get['ORACLE_HOST_IP']
  CONFIG.get['CORE_HOST'] = CONFIG.get['CORE_HOST_IP']

  if (CONFIG.get['PTRADE_SCHEMA'] != 'ptrade' && CONFIG.get['PTRADE_SCHEMA'] != 'ptrade1')
    Actions.f 'ERROR: "PTRADE_SCHEMA" can be either "ptrade" or "ptrade1"'
    fail('ERROR: "PTRADE_SCHEMA" can be either "ptrade" or "ptrade1"')
  end

  ENV['PTRADE_NEW_APP_VERSION_OU'] = ENV['PTRADE_NEW_SCHEMA_VERSION_OU'] if(ENV['PTRADE_NEW_APP_VERSION_OU'].nil? && ENV['PTRADE_NEW_APP_VERSION_OU'].to_s.empty?)

  Actions.createLocalDirsTemplatesLogsDb
  steps %Q{
    Given Automation dir exists on oracle server2
    Given Automation dir exists on ptrade server2
  }

  if(!CONFIG.get['DEPLOY_SDATA'].nil? && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
    steps %Q{
      Given DB Sdata Custom Schema is built for LAB
    }
  else
    Actions.c '<b>NOT deploying SDATA for scratch</b>'
  end

  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade'
    displayDbSchemaVersion2('SDATA')
  elsif CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    displayDbSchemaVersion2('SDATA1')
  end

  stopRegularPtradeServiceNoFails(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])

  if(ENV['PTRADE_NEW_SCHEMA_VERSION_OU'].nil? && ENV['PTRADE_NEW_SCHEMA_VERSION_OU'].to_s.empty?)
    upgradePtradeToNewLabVersionLab(nil)
  else
    upgradePtradeToNewLabVersionLab(ENV['PTRADE_NEW_SCHEMA_VERSION_OU'])
  end

  #downloadDblogsForPtradeNewVersion

  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade'
    displayDbSchemaVersion2('PTRADE')
  elsif CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
  displayDbSchemaVersion2('PTRADE1')
  end

  if(ENV['PTRADE_NEW_APP_VERSION_OU'].nil? && ENV['PTRADE_NEW_APP_VERSION_OU'].to_s.empty?)
    customPtradeAppDeployLab(nil)
    #downloadAppLogsForNewVersion
  else
    customPtradeAppDeployLab(ENV['PTRADE_NEW_APP_VERSION_OU'])
    #downloadAppLogsForNewVersion
  end

  displayPtradeAppOnlyVersion2(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
end


Given /^Sdata and Ptrade App and Schema are Built$/ do
  Actions.createLocalDirs
  steps %Q{
    Given Sdata Schema is Built
  }
  stopPtradeServiceNoFail(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  deleteFolderContentsOnRemoteServerIfFolderExist(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], 'Automation/ers')
  buildPtradeNewSchema(CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'])
  uploadDirToRemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation')
  displayPtradeDbVersionForUpgrade(CONFIG.get['CORE_HOST_USER'])

end


Given /^Ptrade App, Schema and optional Sdata are built for LAB$/ do
  Actions.isIpValidInParams
  CONFIG.get['ORACLE_HOST'] = CONFIG.get['ORACLE_HOST_IP']
  CONFIG.get['CORE_HOST'] = CONFIG.get['CORE_HOST_IP']

  if (CONFIG.get['PTRADE_SCHEMA'] != 'ptrade' && CONFIG.get['PTRADE_SCHEMA'] != 'ptrade1')
    Actions.f 'ERROR: "PTRADE_SCHEMA" can be either "ptrade" or "ptrade1"'
    fail('ERROR: "PTRADE_SCHEMA" can be either "ptrade" or "ptrade1"')
  end

  ENV['PTRADE_NEW_APP_VERSION_OU'] = ENV['PTRADE_NEW_SCHEMA_VERSION_OU'] if(ENV['PTRADE_NEW_APP_VERSION_OU'].nil? && ENV['PTRADE_NEW_APP_VERSION_OU'].to_s.empty?)

  Actions.createLocalDirsTemplatesLogsDb
  steps %Q{
    Given Automation dir exists on oracle server2
    Given Automation dir exists on ptrade server2
  }

  if(!CONFIG.get['DEPLOY_SDATA'].nil? && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
    steps %Q{
      Given DB Sdata Custom Schema is built for LAB
    }
  else
    Actions.c '<b>NOT deploying SDATA for scratch</b>'
  end

  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade'
    displayDbSchemaVersion2('SDATA')
  elsif CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    displayDbSchemaVersion2('SDATA1')
  end

  stopRegularPtradeServiceNoFails(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])

  if(ENV['PTRADE_NEW_SCHEMA_VERSION_OU'].nil? && ENV['PTRADE_NEW_SCHEMA_VERSION_OU'].to_s.empty?)
    customPtradeSchemaDeployLab(nil)
    #downloadDblogsForPtradeNewVersion
  else
    customPtradeSchemaDeployLab(ENV['PTRADE_NEW_SCHEMA_VERSION_OU'])
    #downloadDblogsForPtradeNewVersion
  end

  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade'
    displayDbSchemaVersion2('PTRADE')
  elsif CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    displayDbSchemaVersion2('PTRADE1')
  end

  if(ENV['PTRADE_NEW_APP_VERSION_OU'].nil? && ENV['PTRADE_NEW_APP_VERSION_OU'].to_s.empty?)
    customPtradeAppDeployLab(nil)
    #downloadAppLogsForNewVersion
  else
    customPtradeAppDeployLab(ENV['PTRADE_NEW_APP_VERSION_OU'])
    #downloadAppLogsForNewVersion
  end

  displayPtradeAppOnlyVersion2(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
end

Given /^Old Ptrade App, Schema and optional Sdata are built for LAB$/ do
  Actions.isIpValidInParams
  CONFIG.get['ORACLE_HOST'] = CONFIG.get['ORACLE_HOST_IP']
  CONFIG.get['CORE_HOST'] = CONFIG.get['CORE_HOST_IP']

  if (CONFIG.get['PTRADE_SCHEMA'] != 'ptrade' && CONFIG.get['PTRADE_SCHEMA'] != 'ptrade1')
    Actions.f 'ERROR: "PTRADE_SCHEMA" can be either "ptrade" or "ptrade1"'
    fail('ERROR: "PTRADE_SCHEMA" can be either "ptrade" or "ptrade1"')
  end

  if (ENV['PTRADE_OLD_SCHEMA_VERSION'].nil? && ENV['PTRADE_OLD_SCHEMA_VERSION'].to_s.empty?)
    Actions.f 'ERROR: "PTRADE_OLD_SCHEMA_VERSION" not given'
    fail('ERROR: "PTRADE_OLD_SCHEMA_VERSION" not given')
  end

  ENV['PTRADE_OLD_APP_VERSION'] = ENV['PTRADE_OLD_SCHEMA_VERSION'] if(ENV['PTRADE_OLD_APP_VERSION'].nil? && ENV['PTRADE_OLD_APP_VERSION'].to_s.empty?)

  Actions.createLocalDirsTemplatesLogsDb
  steps %Q{
    Given Automation dir exists on oracle server2
    Given Automation dir exists on ptrade server2
  }

  if(!CONFIG.get['DEPLOY_SDATA'].nil? && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
    steps %Q{
      Given Old DB Sdata Custom Schema is built for LAB
    }
  else
    Actions.c '<b>NOT deploying SDATA for scratch</b>'
  end

  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade'
    displayDbSchemaVersion2('SDATA')
  elsif CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    displayDbSchemaVersion2('SDATA1')
  end

  stopRegularPtradeServiceNoFails(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])

  customPtradeSchemaDeployLab(ENV['PTRADE_OLD_SCHEMA_VERSION'])
  #downloadDblogsForPtradeNewVersion

  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade'
    displayDbSchemaVersion2('PTRADE')
  elsif CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    displayDbSchemaVersion2('PTRADE1')
  end

  customPtradeAppDeployLab(ENV['PTRADE_OLD_APP_VERSION'])
  #downloadAppLogsForNewVersion
  displayPtradeAppOnlyVersion2(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
end


Given /^Upgrade Ptrade to the Latest Lab version$/ do
  stopPtradeServiceNoFail(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  upgradePtradeToNewLabVersion
  buildPtradeApp(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], 'ptradeAPP_build_install_automatic.sh', Dir.getwd+'/templates/bash/', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation','')
  displayPtradeAppAndDbVersionForUpgrade(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])

end



Given /^Jenkins will email PassedOrFailed$/ do
  Actions.c 'See Your email :-)'
end


Given /^DB Sdata Custom Schema is built$/ do
  if(ENV['SDATA_OLD_SCHEMA_VERSION'].nil? || ENV['SDATA_OLD_SCHEMA_VERSION'].to_s.empty?)
    customSdataSchemaDeploy(nil)
    downloadDblogsForSdataNewVersion
  else
    customSdataSchemaDeploy(ENV['SDATA_OLD_SCHEMA_VERSION'])
    downloadDblogsForSdataOldVersion
  end
end

Given /^DB Sdata Custom Schema is built for LAB$/ do
  if(ENV['SDATA_NEW_SCHEMA_VERSION_OU'].nil? || ENV['SDATA_NEW_SCHEMA_VERSION_OU'].to_s.empty?)
    customSdataSchemaDeployLab(nil)
    downloadDblogsForSdataNewVersion
  else
    customSdataSchemaDeployLab(ENV['SDATA_NEW_SCHEMA_VERSION_OU'])
    downloadDblogsForSdataOldVersion
  end
end


Given /^Old DB Sdata Custom Schema is built for LAB$/ do
  if (ENV['SDATA_OLD_SCHEMA_VERSION'].nil? && ENV['SDATA_OLD_SCHEMA_VERSION'].to_s.empty?)
    Actions.f 'ERROR: "SDATA_OLD_SCHEMA_VERSION" not given'
    fail('ERROR: "SDATA_OLD_SCHEMA_VERSION" not given')
  end

  customSdataSchemaDeployLab(ENV['SDATA_OLD_SCHEMA_VERSION'])
  downloadDblogsForSdataOldVersion
end


Given /^Sdata Schema Installed$/ do
  target_schema = 'SDATA'
  t_schema = Actions.getDbQueryResultsWithoutFailure4(target_schema,target_schema.to_s.downcase,"select * from "+target_schema+".SCHEMA_VERSION")
  t_schema_version=t_schema[0]['VERSION_NAME'].to_s
  t_schema_created=t_schema[0]['CREATION_TIME'].to_s
  if (t_schema_version.nil? || t_schema_created.nil? )
    fail('SDATA Schema is NOT installed')
  else
    Actions.c '<b>SDATA Schema Version - '+t_schema_version+' '+t_schema_created+'</b>'
    Actions.setBuildProperty('APP_VERSION',t_schema_version.to_s)
  end

  moveAutomationDir(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'])
  moveAutomationDir(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  moveAutomationDir(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])

end


def displayDbSchemaVersion(schema)
  t_schema = Actions.getDbQueryResultsWithoutFailure4(schema,schema.to_s.downcase,"select * from "+schema+".SCHEMA_VERSION")
  t_schema_version=t_schema[0]['VERSION_NAME'].to_s
  t_schema_created=t_schema[0]['CREATION_TIME'].to_s
  if (t_schema_version.nil? || t_schema_created.nil? )
    fail('Error: '+schema+' Schema is NOT installed')
  else
    Actions.c schema+'<b> Schema Version: '+t_schema_version+' '+t_schema_created+'</b>'
    Actions.setBuildProperty('APP_VERSION',t_schema_version.to_s)
  end
end

def displayDbSchemaVersion2(schema)
  t_schema = Actions.getDbQueryResultsWithoutFailure2("select * from "+schema+".SCHEMA_VERSION")
  t_schema_version=t_schema[0]['VERSION_NAME'].to_s
  t_schema_created=t_schema[0]['CREATION_TIME'].to_s
  if (t_schema_version.nil? || t_schema_created.nil? )
    fail('Error: '+schema+' Schema is NOT installed')
  else
    Actions.c schema+'<b> Schema Version: '+t_schema_version+' '+t_schema_created+'</b>'
    Actions.setBuildProperty('APP_VERSION',t_schema_version.to_s)
  end
end


def stopPtradeServiceNoFails(host, user, pwd)
  Actions.c 'Stopping PTS services...'
  cmd = CONFIG.get['REMOTE_HOME']+'/'+user+'/Automation/PTS/bin/service.sh stop'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 30)
  Actions.c res.to_s
end

def stopRegularPtradeServiceNoFails(host, user, pwd)
  cmd = CONFIG.get['REMOTE_HOME']+'/'+user+'/PTS/bin/service.sh stop'
  Actions.c 'Stopping PTS services on '+host+': '+cmd
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 30)
  Actions.c res.to_s
end


def customSdataSchemaDeploy(version)
  fail('Please define missing params ORACLE_HOST...') if (CONFIG.get['ORACLE_HOST'].nil?)

  Actions.v 'Copying script and building Old schema to Oracle server... '
  #Custom Schema
  Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/db_config_sdata_example.sql', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/db_config_sdata_example.sql',40)
  Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/sdata_schema_install_automatic.sh', CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema_install_automatic.sh',40)

  #Custom Schema
  Actions.c 'Building SDATA DB Schema version '+version+' from scratch on '+CONFIG.get['ORACLE_HOST']+'...' if (!version.nil?)
  Actions.c 'Building SDATA DB Schema LAST version from scratch on '+CONFIG.get['ORACLE_HOST']+'...' if (version.nil?)

  cmd = "dos2unix "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema_install_automatic.sh"\
           +" && chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/sdata_schema_install_automatic.sh'
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema_install_automatic.sh" if (version.nil?)
  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/sdata_schema_install_automatic.sh -n "+version  if (!version.nil?)
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 600, true, '')

end



def customSdataSchemaDeployLab(version)
  fail('Please define missing params ORACLE_HOST_IP') if (CONFIG.get['ORACLE_HOST_IP'].nil?)

  mountHost = CONFIG.get['MOUNT_HOST']
  mountUser = CONFIG.get['MOUNT_USER']
  mountPwd = CONFIG.get['MOUNT_PWD']
  downloadFolder = "/export/home/"+mountUser+"/Automation_download"
  installScript = "sdata_schema_install_automatic.sh"
  installSupportFile = "db_config_sdata_example.sql"
  installSupportFile2 = ""
  downloadScript = "sdata_schema_download_automatic.sh"
  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    installScript = "sdata_schema1_install_automatic.sh"
    installSupportFile = "db_config_sdata1_example.sql"
    installSupportFile2 = "buildSchema_sdata1.sh"
    downloadScript = "sdata_schema1_download_automatic.sh"
  end
  scpScript = "scpFileRemotely.sh"

  sdata_schema = ''
  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade'
    sdata_schema = 'sdata'
  elsif CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    sdata_schema = 'sdata1'
  end
  Actions.c '<b>Getting SDATA DB Schema version '+version+' for "'+sdata_schema+'"...</b>' if (!version.nil?)
  Actions.c '<b>Getting the LAST version of SDATA DB Schema for "'+sdata_schema+'"...</b>' if (version.nil?)

  cmd = "rm -rf "+downloadFolder+" && mkdir -p "+downloadFolder
  res = Actions.SSH(mountHost,mountUser,mountPwd,cmd,20,false,'')

  Actions.uploadTemplates2(mountHost,mountUser,mountPwd,Dir.getwd+'/templates/bash/'+downloadScript,downloadFolder+'/'+downloadScript,40)
  Actions.rigthsForFile(mountHost,mountUser,mountPwd,downloadFolder,downloadScript,'755')
  Actions.uploadTemplates2(mountHost,mountUser,mountPwd,Dir.getwd+'/templates/bash/'+scpScript,downloadFolder+'/'+scpScript,40)
  Actions.rigthsForFile(mountHost,mountUser,mountPwd,downloadFolder,scpScript,'755')

  cmd = downloadFolder+'/'+downloadScript if (version.nil?)
  cmd = downloadFolder+'/'+downloadScript+" -n "+version  if (!version.nil?)
  res = Actions.SSH(mountHost, mountUser, mountPwd, cmd, 500, true, '')

  env_version = Actions.displayDownloadedTarVersion(sdata_schema,true,mountHost,mountUser,mountPwd)
  downloadedPackage = downloadFolder+'/'+env_version
  targetPackage = CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['ORACLE_HOST_USER']+"/Automation/"+env_version

  cmd = 'ls -lA '+downloadedPackage
  res = Actions.SSH(mountHost,mountUser,mountPwd,cmd,5,true,'')
  Actions.c 'Package found: '+res if(res)

  Actions.c 'Copying files to '+CONFIG.get['ORACLE_HOST_IP']+'...'
  Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/'+installSupportFile, CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installSupportFile,40)
  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/'+installSupportFile2, CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installSupportFile2,40)
    Actions.rigthsForFile(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH'], installSupportFile2, '755')
  end
  Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/'+installScript, CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installScript,40)
  Actions.rigthsForFile(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH'], installScript, '755')
  Actions.transferFileRemotely(scpScript,mountHost,mountUser,mountPwd,CONFIG.get['ORACLE_HOST_IP'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],downloadFolder,CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH'],env_version)
  Actions.c '<b>Downloaded package '+env_version+' to '+targetPackage+'</b>'

  #Custom Schema
  Actions.c 'Building SDATA DB Schema version '+version+' for "'+sdata_schema+'" from scratch on '+CONFIG.get['ORACLE_HOST_IP'] if (!version.nil?)
  Actions.c 'Building SDATA DB Schema LAST version for "'+sdata_schema+'" from scratch on '+CONFIG.get['ORACLE_HOST_IP'] if (version.nil?)

  cmd = "dos2unix "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installScript+" && chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installScript+" && chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+"db_config_sdata_example.sql"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

  if (!CONFIG.get['SDATA_EXTRACT_FOLDER'].nil?)
    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installScript+" extract_to: "+CONFIG.get['SDATA_EXTRACT_FOLDER']+" -p "+CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['ORACLE_HOST_USER']+"/Automation/"+env_version
    Actions.c 'Using SDATA_EXTRACT_FOLDER = '+CONFIG.get['SDATA_EXTRACT_FOLDER']
  else
    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installScript+" -p "+CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['ORACLE_HOST_USER']+"/Automation/"+env_version
  end

  res = Actions.SSH(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, CONFIG.get['DEPLOYMENT_TIMEOUT'].to_i, false, '')

end


def customPtradeSchemaDeploy(version)
  fail('Please define missing params ORACLE_HOST...') if (CONFIG.get['ORACLE_HOST'].nil?)

  Actions.c 'Building PTRADE DB Schema Version - '+version+' from scratch... ' if (!version.nil?)
  Actions.c 'Building PTRADE DB Schema LAST Version from scratch... ' if (version.nil?)

  createAutomationDirForUser(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'])
  uploadDirToRemoteAutomationFolder(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation')

  if (version.nil? || version.to_s.empty?)

    cmd = "dos2unix "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh "
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

    cmd ="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh"
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

    #cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh -n "+version  if (!version.nil?)
    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh" if (version.nil?)
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 300, false, '')
  else

    cmd =  "dos2unix "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/buildSchema_ptrade.sh"
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

    cmd ="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/buildSchema_ptrade.sh"
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

    cmd =  "dos2unix "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh"
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

    cmd ="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh"
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh -n "+version
    res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 300, false, '')

  end

end

def customPtradeSchemaDeployLab(version)
  fail('Please define missing params ORACLE_HOST_IP') if (CONFIG.get['ORACLE_HOST_IP'].nil?)

  mountHost = CONFIG.get['MOUNT_HOST']
  mountUser = CONFIG.get['MOUNT_USER']
  mountPwd = CONFIG.get['MOUNT_PWD']
  downloadFolder = "/export/home/"+mountUser+"/Automation_download"
  installScript = "ptradeDB_schema_install_automatic.sh"
  installSupportFile = ""
  downloadScript = "ptradeDB_schema_download_automatic.sh"
  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    installScript = "ptradeDB_schema1_install_automatic.sh"
    installSupportFile = "db_config_qa_ptrade_example.sql"
    downloadScript = "ptradeDB_schema1_download_automatic.sh"
  end
  scpScript = "scpFileRemotely.sh"

  Actions.c '<b>Getting PTRADE DB Schema version '+version+' for "'+CONFIG.get['PTRADE_SCHEMA']+'"...</b>' if (!version.nil?)
  Actions.c '<b>Getting the LAST version of PTRADE DB Schema for "'+CONFIG.get['PTRADE_SCHEMA']+'"...</b>' if (version.nil?)

  cmd = "rm -rf "+downloadFolder+" && mkdir -p "+downloadFolder
  res = Actions.SSH(mountHost,mountUser,mountPwd,cmd,20,false,'')

  Actions.uploadTemplates2(mountHost,mountUser,mountPwd,Dir.getwd+'/templates/bash/'+downloadScript,downloadFolder+'/'+downloadScript,40)
  Actions.rigthsForFile(mountHost,mountUser,mountPwd,downloadFolder,downloadScript,'755')
  Actions.uploadTemplates2(mountHost,mountUser,mountPwd,Dir.getwd+'/templates/bash/'+scpScript,downloadFolder+'/'+scpScript,40)
  Actions.rigthsForFile(mountHost,mountUser,mountPwd,downloadFolder,scpScript,'755')

  cmd = downloadFolder+'/'+downloadScript if (version.nil?)
  cmd = downloadFolder+'/'+downloadScript+" -n "+version  if (!version.nil?)
  res = Actions.SSH(mountHost, mountUser, mountPwd, cmd, 500, true, '')

  env_version = Actions.displayDownloadedTarVersion(CONFIG.get['PTRADE_SCHEMA'],true,mountHost,mountUser,mountPwd)
  downloadedPackage = downloadFolder+'/'+env_version
  targetPackage = CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['ORACLE_HOST_USER']+"/Automation/"+env_version

  cmd = 'ls -lA '+downloadedPackage
  res = Actions.SSH(mountHost,mountUser,mountPwd,cmd,5,true,'')
  Actions.c 'Package found: '+res if(res)
  Actions.c 'Copying files to '+CONFIG.get['ORACLE_HOST_IP']+'...'

  Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/'+installScript, CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installScript,40)
  Actions.rigthsForFile(CONFIG.get['ORACLE_HOST_IP'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH'],installScript,'755')
  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/'+installSupportFile, CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installSupportFile,40)
  end
  Actions.transferFileRemotely(scpScript,mountHost,mountUser,mountPwd,CONFIG.get['ORACLE_HOST_IP'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],downloadFolder,CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH'],env_version)

  Actions.c '<b>Downloaded package '+env_version+' to '+targetPackage+'</b>'
  Actions.c 'Building PTRADE DB Schema version '+version+' from scratch for "'+CONFIG.get['PTRADE_SCHEMA']+'"...' if (!version.nil?)
  Actions.c 'Building PTRADE DB Schema LAST version from scratch for "'+CONFIG.get['PTRADE_SCHEMA']+'"...' if (version.nil?)

  if (!CONFIG.get['PTRADE_DB_EXTRACT_FOLDER'].nil?)
    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installScript+" extract_to: "+CONFIG.get['PTRADE_DB_EXTRACT_FOLDER']+" -p "+CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['ORACLE_HOST_USER']+"/Automation/"+env_version
    Actions.c 'Using PTRADE_DB_EXTRACT_FOLDER = '+CONFIG.get['PTRADE_DB_EXTRACT_FOLDER']
  else
    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installScript+" -p "+CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['ORACLE_HOST_USER']+"/Automation/"+env_version
  end

  res = Actions.SSH(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, CONFIG.get['DEPLOYMENT_TIMEOUT'].to_i, false, '')

end


def customPtradeOldSchemaDeploy(version)
  fail('Please define missing params ORACLE_HOST...') if (CONFIG.get['ORACLE_HOST'].nil?)

  Actions.c 'Building PTRADE DB Schema Version - '+version+' from scratch... ' if (!version.nil?)
  Actions.c 'Building PTRADE DB Schema LAST Version from scratch... ' if (version.nil?)

  createAutomationDirForUser(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'])
  uploadDirToRemoteAutomationFolder(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation')


  cmd =  "dos2unix "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/buildSchema_ptrade1.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

  cmd ="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/buildSchema_ptrade1.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd =  "dos2unix "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema1_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

  cmd ="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema1_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema1_install_automatic.sh -n "+version if(!version.nil? && !version.to_s.empty?)
  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema1_install_automatic.sh"+version if(version.nil? || version.to_s.empty?) #WTF, man?
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 300, false, '')

end

def customPtradeOldSchemaDeploy2(version)
  fail('Please define missing params ORACLE_HOST') if (CONFIG.get['ORACLE_HOST'].nil?)

  Actions.c 'Building PTRADE DB Schema Version - '+version+' for '+CONFIG.get['CORE_HOST_USER1']+' from scratch... ' if (!version.nil?)
  Actions.c 'Building PTRADE DB Schema LAST Version  for '+CONFIG.get['CORE_HOST_USER1']+' from scratch... ' if (version.nil?)

  schemaInstallScript1 = 'ptradeDB_schema1_install_automatic.sh'
  schemaBuildScript1 = 'buildSchema_ptrade1.sh'
  dbConfigExample1 = 'db_config_qa_ptrade_example.sql'

  Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],Dir.getwd+'/templates/bash/'+schemaInstallScript1,CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/'+schemaInstallScript1,40)
  Actions.rigthsForFile(CONFIG.get['ORACLE_HOST'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation',schemaInstallScript1,'755')

  Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],Dir.getwd+'/templates/bash/'+schemaBuildScript1,CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/'+schemaBuildScript1,40)
  Actions.rigthsForFile(CONFIG.get['ORACLE_HOST'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation',schemaBuildScript1,'755')

  Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],Dir.getwd+'/templates/bash/'+dbConfigExample1,CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/'+dbConfigExample1,40)
  Actions.rigthsForFile(CONFIG.get['ORACLE_HOST'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation',dbConfigExample1,'755')

  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/"+schemaInstallScript1+" -n "+version if(!version.nil? || !version.to_s.empty?)
  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/"+schemaInstallScript1 if(version.nil? || version.to_s.empty?)
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 300, false, '')
  # Actions.f 'Output found while building schema: '+res.to_s if(!res.nil? && !res.to_s.empty?)

end


def customPtradeNewSchemaDeploy(version)
  fail('Please define missing params ORACLE_HOST...') if (CONFIG.get['ORACLE_HOST'].nil?)

  Actions.c 'Building PTRADE DB Schema Version - '+version+' for '+CONFIG.get['CORE_HOST_USER']+' from scratch... ' if (!version.nil?)
  Actions.c 'Building PTRADE DB Schema LAST Version  for '+CONFIG.get['CORE_HOST_USER']+' from scratch... ' if (version.nil?)

  createAutomationDirForUser(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'])
  uploadDirToRemoteAutomationFolder(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation')

  cmd = "dos2unix "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

  cmd ="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, false, '')

  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh -n "+version  if(!version.nil? && !version.to_s.empty?)
  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_install_automatic.sh" if(version.nil? || version.to_s.empty?)
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 300, false, '')

end

def customPtradeNewSchemaDeploy2(version)
  fail('Please define missing params ORACLE_HOST') if (CONFIG.get['ORACLE_HOST'].nil?)

  Actions.c 'Building PTRADE DB Schema Version - '+version+' for ptrade from scratch... ' if (!version.nil?)
  Actions.c 'Building PTRADE DB Schema LAST Version for ptrade from scratch... ' if (version.nil?)

  schemaInstallScript = 'ptradeDB_schema_install_automatic.sh'

  Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],Dir.getwd+'/templates/bash/'+schemaInstallScript,CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation/'+schemaInstallScript,40)
  Actions.rigthsForFile(CONFIG.get['ORACLE_HOST'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation',schemaInstallScript,'755')

  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/"+schemaInstallScript+" -n "+version if(!version.nil? || !version.to_s.empty?)
  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/"+schemaInstallScript if(version.nil? || version.to_s.empty?)
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 300, false, '')
  # Actions.f 'Output found while building schema: '+res.to_s if(!res.nil? && !res.to_s.empty?)
end


def customPtradeAppDeploy(version)
  stopPtradeServiceNoFails(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  createAutomationDirForUser(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  uploadDirToRemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation')
  buildPtradeApp(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], 'ptradeAPP_build_install_automatic.sh', Dir.getwd+'/templates/bash/', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation','') if(version.nil? || version.to_s.empty?)
  displayPtradeAppVersion(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
end



def customPtradeAppDeployLab(version)

  mountHost = CONFIG.get['MOUNT_HOST']
  mountUser = CONFIG.get['MOUNT_USER']
  mountPwd = CONFIG.get['MOUNT_PWD']
  downloadFolder = "/export/home/"+mountUser+"/Automation_download"
  installScript = "ptradeAPP_build_install_automatic.sh"
  downloadScript = "ptradeAPP_build_download_automatic_oracle.sh"
  scpScript = "scpFileRemotely.sh"

  Actions.c '<b>Getting PTRADE App version '+version+'...</b>' if (!version.nil?)
  Actions.c '<b>Getting the LAST version of PTRADE App...</b>' if (version.nil?)

  cmd = "rm -rf "+downloadFolder+" && mkdir -p "+downloadFolder
  res = Actions.SSH(mountHost,mountUser,mountPwd,cmd,20,false,'')

  Actions.uploadTemplates2(mountHost,mountUser,mountPwd,Dir.getwd+'/templates/bash/'+downloadScript,downloadFolder+'/'+downloadScript,40)
  Actions.rigthsForFile(mountHost,mountUser,mountPwd,downloadFolder,downloadScript,'755')
  Actions.uploadTemplates2(mountHost,mountUser,mountPwd,Dir.getwd+'/templates/bash/'+scpScript,downloadFolder+'/'+scpScript,40)
  Actions.rigthsForFile(mountHost,mountUser,mountPwd,downloadFolder,scpScript,'755')

  cmd = "dos2unix "+downloadFolder+'/'+downloadScript+" && "+"chmod 755 "+downloadFolder+'/'+downloadScript
  res = Actions.SSH(mountHost,mountUser,mountPwd,cmd,10,true,'')

  cmd = downloadFolder+'/'+downloadScript if (version.nil?)
  cmd = downloadFolder+'/'+downloadScript+" -n "+version  if (!version.nil?)
  res = Actions.SSH(mountHost, mountUser, mountPwd, cmd, 500, true, '')

  env_version = Actions.displayDownloadedTarVersion('ptrade',false,mountHost,mountUser,mountPwd)
  downloadedPackage = downloadFolder+'/'+env_version
  targetPackage = CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['CORE_HOST_USER']+"/Automation/"+env_version

  cmd = 'ls -lA '+downloadedPackage
  res = Actions.SSH(mountHost,mountUser,mountPwd,cmd,5,true,'')
  Actions.c 'Package found: '+res if(res)
  Actions.c 'Copying files to '+CONFIG.get['CORE_HOST_IP']+'...'

  Actions.uploadTemplates2(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/bash/'+installScript, CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/'+installScript,40)
  Actions.transferFileRemotely(scpScript,mountHost,mountUser,mountPwd,CONFIG.get['CORE_HOST_IP'],CONFIG.get['CORE_HOST_USER'],CONFIG.get['CORE_HOST_PWD'],downloadFolder,CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH'],env_version)

  Actions.c '<b>Downloaded package '+env_version+' to '+targetPackage+'</b>'
  Actions.c 'Building the version '+version+' PTRADE App from scratch...' if (!version.nil?)
  Actions.c 'Building the LAST version of PTRADE App from scratch...' if (version.nil?)

  cmd = "dos2unix "+CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+"/"+installScript+" && chmod 755 "+CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+"/"+installScript
  res = Actions.SSH(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 10, true, '')

  if (!CONFIG.get['PTRADE_APP_EXTRACT_FOLDER'].nil? && CONFIG.get['PTRADE_APP_INSTALL_FOLDER'].nil?)
    cmd = CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/'+installScript+" extract_to: "+CONFIG.get['PTRADE_APP_EXTRACT_FOLDER']+" -p "+CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['CORE_HOST_USER']+"/Automation/"+env_version
    Actions.c 'Using PTRADE_APP_EXTRACT_FOLDER = '+CONFIG.get['PTRADE_APP_EXTRACT_FOLDER']
  elsif (CONFIG.get['PTRADE_APP_EXTRACT_FOLDER'].nil? && !CONFIG.get['PTRADE_APP_INSTALL_FOLDER'].nil?)
    cmd = CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/'+installScript+" install_to: "+CONFIG.get['PTRADE_APP_INSTALL_FOLDER']+" -p "+CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['CORE_HOST_USER']+"/Automation/"+env_version
    Actions.c 'Using PTRADE_APP_INSTALL_FOLDER = '+CONFIG.get['PTRADE_APP_INSTALL_FOLDER']
  elsif (!CONFIG.get['PTRADE_APP_EXTRACT_FOLDER'].nil? && !CONFIG.get['PTRADE_APP_INSTALL_FOLDER'].nil?)
    cmd = CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/'+installScript+" extract_to: "+CONFIG.get['PTRADE_APP_EXTRACT_FOLDER']+" install_to: "+CONFIG.get['PTRADE_APP_INSTALL_FOLDER']+" -p "+CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['CORE_HOST_USER']+"/Automation/"+env_version
    Actions.c 'Using PTRADE_APP_EXTRACT_FOLDER = '+CONFIG.get['PTRADE_APP_EXTRACT_FOLDER']+', PTRADE_APP_INSTALL_FOLDER = '+CONFIG.get['PTRADE_APP_INSTALL_FOLDER']
  else
    cmd = CONFIG.get['REMOTE_PTRADE_TEMPLATE_DIR_PATH']+'/'+installScript+" -p "+CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['CORE_HOST_USER']+"/Automation/"+env_version
  end

  res = Actions.SSH(CONFIG.get['CORE_HOST_IP'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, CONFIG.get['DEPLOYMENT_TIMEOUT'].to_i, false, '')

end



def startRedis
  cmd = "/export/home/$USER/redis/src/startRedis.sh"
  res = Actions.SSH_NO_FAIL(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 60)
end


def displaySanityLogs(with_sdata, with_sdata1, with_ptrade, with_ptrade1)
  downloadDblogsForSdataOldVersion if(with_sdata1)
  downloadDblogsForSdataNewVersion if(with_sdata)
  if(with_ptrade1)
    Actions.SSH_NO_FAIL(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], "/export/home/"+CONFIG.get['CORE_HOST_USER1']+'/Automation/PTSlogsParser_ptrade1.sh', 120)
    sleep 20
    Actions.downloadCoreLogs(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  end
  if(with_ptrade)
    Actions.SSH_NO_FAIL(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], "/export/home/"+CONFIG.get['CORE_HOST_USER']+'/Automation/PTSlogsParser_ptrade.sh', 120)
    sleep 20
    Actions.downloadCoreLogs(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  end
  Actions.displayFilesForDownloadInFolder(Dir.getwd+'/logs/logs_'+@@time_stamp)
end


def downloadCustomBuildLogs(with_sdata,with_ptrade)
  downloadDblogsForSdataNewVersion if(with_sdata)
  Actions.downloadCoreLogs(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD']) if(with_ptrade)
end

##########builds

############Upgrade
def createAutomationDirForUserUpgrade(host, user, pwd)
  Actions.v 'Creating Automation dir on host '+host+' for user '+user+'... '
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/ers'
  res = Actions.SSH(host, user, pwd, cmd, 10, true, '')

  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/ers2'
  res = Actions.SSH(host, user, pwd, cmd, 10, true, '')

  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/data'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 10)

  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/data/tickets'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 10)
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/data/tickets/common'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 10)
  cmd = 'mkdir -p '+CONFIG.get['REMOTE_HOME']+'/'+user+'/'+'Automation/data/tickets/myt'
  res = Actions.SSH_NO_FAIL(host, user, pwd, cmd, 10)

end

Given /^beforeScenarioSteps$/ do
  Actions.removeOldOutput
  Actions.createLocalDirs
  stopPtradeServiceNoFail(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  stopPtradeServiceNoFail(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  moveAutomationDir(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'])
  moveAutomationDir(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  moveAutomationDir(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  steps %Q{
      Given Automation dir exist on oracle server
    }

end


Given /^beforeScenarioStepsSdata$/ do
  Actions.removeOldOutput
  Actions.createLocalDirs
  moveAutomationDir(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'])
  steps %Q{
      Given Automation dir exist on oracle server
  }

end



def upgradePtradeToNewLabVersion
  fail('Please define missing params ORACLE_HOST...') if (CONFIG.get['ORACLE_HOST'].nil?)
  Actions.c '<b>Performing PTRADE Upgrade...</b>'

  createAutomationDirForUser(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'])
  uploadDirToRemoteAutomationFolder(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['ORACLE_HOST_USER']+'/Automation')

  cmd = "dos2unix "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_upgrade_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

  cmd ="chmod 755 "+CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_upgrade_automatic.sh"
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 20, true, '')

  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_upgrade_automatic.sh" if(CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].nil? || CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].to_s.empty? )
  cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+"/ptradeDB_schema_upgrade_automatic.sh -n " +CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].to_s if(!CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].nil? || !CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].to_s.empty? )
  res = Actions.SSH(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, 600, false, '')

end

def upgradePtradeToNewLabVersionLab(version)
  fail('Please define missing params ORACLE_HOST_IP') if (CONFIG.get['ORACLE_HOST_IP'].nil?)

  mountHost = CONFIG.get['MOUNT_HOST']
  mountUser = CONFIG.get['MOUNT_USER']
  mountPwd = CONFIG.get['MOUNT_PWD']
  downloadFolder = "/export/home/"+mountUser+"/Automation_download"
  installScript = "ptradeDB_schema_upgrade_automatic.sh"
  downloadScript = "ptradeDB_schema_download_automatic.sh"
  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    installScript = "ptradeDB_schema1_upgrade_automatic.sh"
    downloadScript = "ptradeDB_schema1_download_automatic.sh"
  end
  scpScript = "scpFileRemotely.sh"

  Actions.c '<b>Getting PTRADE DB Schema version '+version+'...</b>' if (!version.nil?)
  Actions.c '<b>Getting the LAST version of PTRADE DB Schema...</b>' if (version.nil?)

  cmd = "rm -rf "+downloadFolder+" && mkdir -p "+downloadFolder
  res = Actions.SSH(mountHost,mountUser,mountPwd,cmd,20,false,'')

  Actions.uploadTemplates2(mountHost,mountUser,mountPwd,Dir.getwd+'/templates/bash/'+downloadScript,downloadFolder+'/'+downloadScript,40)
  Actions.rigthsForFile(mountHost,mountUser,mountPwd,downloadFolder,downloadScript,'755')
  Actions.uploadTemplates2(mountHost,mountUser,mountPwd,Dir.getwd+'/templates/bash/'+scpScript,downloadFolder+'/'+scpScript,40)
  Actions.rigthsForFile(mountHost,mountUser,mountPwd,downloadFolder,scpScript,'755')

  cmd = downloadFolder+'/'+downloadScript if (version.nil?)
  cmd = downloadFolder+'/'+downloadScript+" -n "+version  if (!version.nil?)
  res = Actions.SSH(mountHost, mountUser, mountPwd, cmd, 500, true, '')

  env_version = Actions.displayDownloadedTarVersion(CONFIG.get['PTRADE_SCHEMA'],true,mountHost,mountUser,mountPwd)
  downloadedPackage = downloadFolder+'/'+env_version
  targetPackage = CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['ORACLE_HOST_USER']+"/Automation/"+env_version

  cmd = 'ls -lA '+downloadedPackage
  res = Actions.SSH(mountHost,mountUser,mountPwd,cmd,5,true,'')
  Actions.c 'Package found: '+res if(res)
  Actions.c 'Copying files to '+CONFIG.get['ORACLE_HOST_IP']+'...'

  Actions.uploadTemplates2(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], Dir.getwd+'/templates/bash/'+installScript, CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installScript,40)
  Actions.rigthsForFile(CONFIG.get['ORACLE_HOST_IP'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH'],installScript,'755')
  Actions.transferFileRemotely(scpScript,mountHost,mountUser,mountPwd,CONFIG.get['ORACLE_HOST_IP'],CONFIG.get['ORACLE_HOST_USER'],CONFIG.get['ORACLE_HOST_PWD'],downloadFolder,CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH'],env_version)

  Actions.c '<b>Downloaded package '+env_version+' to '+targetPackage+'</b>'
  Actions.c 'Upgrading to PTRADE DB Schema version '+version+' for "'+CONFIG.get['PTRADE_SCHEMA']+'"...' if (!version.nil?)
  Actions.c 'Upgrading to PTRADE DB Schema LAST version for "'+CONFIG.get['PTRADE_SCHEMA']+'"...' if (version.nil?)

  if (!CONFIG.get['PTRADE_DB_EXTRACT_FOLDER'].nil?)
    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installScript+" extract_to: "+CONFIG.get['PTRADE_DB_EXTRACT_FOLDER']+" -p "+CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['ORACLE_HOST_USER']+"/Automation/"+env_version
    Actions.c 'Using PTRADE_DB_EXTRACT_FOLDER = '+CONFIG.get['PTRADE_DB_EXTRACT_FOLDER']
  else
    cmd = CONFIG.get['REMOTE_ORACLE_TEMPLATE_DIR_PATH']+'/'+installScript+" -p "+CONFIG.get['REMOTE_HOME']+"/"+CONFIG.get['ORACLE_HOST_USER']+"/Automation/"+env_version
  end

  res = Actions.SSH(CONFIG.get['ORACLE_HOST_IP'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'], cmd, CONFIG.get['DEPLOYMENT_TIMEOUT'].to_i, false, '')
end


Then /^DB tables DEAL TICKETS LEGS compared for both versions with latest version$/ do
  Actions.compareDbTableResultsForUpgrade(CONFIG.get['ORACLE_HOST_TEMPLATE_SCHEMA'], CONFIG.get['ORACLE_HOST_SCHEMA']) #('PTRADE1','PTRADE')
end


Then /^Old and New versions csv Folders are Matched excluding timestamps with latest version$/ do
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_csv/'+@@time_stamp + ' & mkdir latestVsUpgrade', 10)
  source_dir = Dir.getwd + '/templates/old_app_csv/'+@@time_stamp+'/latestVsUpgrade/'+@@time_stamp
  target_dir = Dir.getwd + '/templates/new_app_csv/'+@@time_stamp
  dir_count=Actions.compareCsvDirs(source_dir+'/common', target_dir+'/common')
  Actions.c (count-2).to_s+' folders have been compared in common folder' if(!$csv_folders_count.nil? && !dir_count.nil? && !dir_count[0].to_s.downcase.include?('error'))
  count=Actions.compareCsvDirs(source_dir+'/myt', target_dir+'/myt')
  Actions.c (count-2).to_s+' folders have been compared in myt folder' if(!$csv_folders_count.nil? && !dir_count.nil? && !dir_count[0].to_s.downcase.include?('error'))
  Actions.c $csv_files_count.to_s+' files have been compared' if(!$csv_files_count.nil?)

  if($csv_folders_count.nil? || $csv_folders_count==0)
    @@scenario_fails.push('0 Folders compared')
    Actions.f('0 Folders compared')
  end
  if($csv_files_count.nil? || $csv_files_count==0)
    @@scenario_fails.push('0 Files compared')
    Actions.f('0 Files compared')
  end

end


Then /^Old and New Saphire Jsons are Matched excluding sequence with latest version$/ do
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_json/'+@@time_stamp + ' & mkdir latestVsUpgrade', 10)
  template_json = Dir.getwd + '/templates/old_app_json/'+@@time_stamp+'/latestVsUpgrade/'+@@time_stamp+'/RedisMonitor1.txt'
  build_json = Dir.getwd + '/templates/new_app_json/'+@@time_stamp+'/RedisMonitor.txt'

  @@json_fails=[]
  Actions.c '<b>Comparing Sapphire Jsons...</b>'
  Actions.compareSaphireOutputJsonsForUpgrade(template_json, build_json)

end


def downloadCsvFolderForLatestVersion
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_csv/'+@@time_stamp + ' & mkdir latestVsUpgrade', 10)
  Actions.c 'Downloading MyT And Common csv files from Remote Folder for the Latest Lab Version'
  downloadDirFromRemote(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/old_app_csv/'+@@time_stamp+'/latestVsUpgrade', CONFIG.get['MYT_CSV_REMOTE_DIR_PATH1'])
end


def downloadJsonForLatestVersion
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_json/'+@@time_stamp + ' & mkdir latestVsUpgrade', 10)
  Actions.v('Downloading Sapphire Json for the Latest Lab Version')
  downloadFileFromRemote(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'],Dir.getwd+'/templates/old_app_json/'+@@time_stamp+'/latestVsUpgrade',  '/export/home/'+CONFIG.get['CORE_HOST_USER1']+'/Automation', 'RedisMonitor1.txt')
end



def compareCsvWithDifferentTimestamps
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_csv/'+@@time_stamp + ' & mkdir latestVsUpgrade', 10)
  source_dir = Dir.getwd + '/templates/old_app_csv/'+@@time_stamp+'/latestVsUpgrade/'+@@time_stamp
  target_dir = Dir.getwd + '/templates/new_app_csv/'+$old_json_timestamp
  count=Actions.compareCsvDirs(source_dir+'/common', target_dir+'/common')
  Actions.c (count-2).to_s+' folders have been compared in common folder' if(!$csv_folders_count.nil?)
  count=Actions.compareCsvDirs(source_dir+'/myt', target_dir+'/myt')
  Actions.c (count-2).to_s+' folders have been compared in myt folder' if(!$csv_folders_count.nil?)
  #Actions.c $csv_files_count.to_s+' files have been compared' if(!$csv_files_count.nil?)

  if($csv_folders_count==0)
    @@scenario_fails.push('0 Folders compared')
    Actions.f('0 Folders compared')
  end
  if($csv_files_count==0)
    @@scenario_fails.push('0 Files compared')
    Actions.f('0 Files compared')
  end
end





def compareJsonWithDifferentTimestamps
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_json/'+@@time_stamp + ' & mkdir latestVsUpgrade', 10)
  template_json = Dir.getwd + '/templates/old_app_json/'+@@time_stamp+'/latestVsUpgrade/'+@@time_stamp+'/RedisMonitor1.txt'
  build_json = Dir.getwd + '/templates/new_app_json/'+$old_json_timestamp+'/RedisMonitor.txt'

  @@json_fails=[]
  Actions.compareSaphireOutputJsonsForUpgrade(template_json, build_json)
end


def changeTimeStamp
  time = Time.new
  @@time_stamp= time.day.to_s+'-'+time.month.to_s+'-'+time.year.to_s+'_'+time.hour.to_s+'-'+time.min.to_s+'-'+time.sec.to_s #Time.now.to_i.to_s
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/new_app_csv & mkdir '+@@time_stamp, 10)
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_csv'+' & mkdir '+@@time_stamp, 10)
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/new_app_json'+' & mkdir '+@@time_stamp, 10)
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/old_app_json'+' & mkdir '+@@time_stamp, 10)
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/myt/source'+' & mkdir '+@@time_stamp, 10)
  Actions.WINCMD_NO_FAIL('cd '+Dir.getwd+'/templates/myt/target'+' & mkdir '+@@time_stamp, 10)

end



def copyFile(file, from, to)
  Actions.v 'Copying file '+file+' from'+from+' to'+to
  cmd ="cp -f "+from+'/' + file+' '+to
  res = Actions.SSH(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], cmd, 10, false, '')
end




def debugUpgrade
  ##temp
  killRedisRoot(CONFIG.get['CORE_HOST'])
  stopPtradeServiceNoFail(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  stopPtradeServiceNoFail(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  moveAutomationDir(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'])
  moveAutomationDir(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  createAutomationDirForUserUpgrade(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  uploadDirToRemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/bash', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation')
  uploadDirToRemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/ers', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/ers')
  uploadDirToRemoteAutomationFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/ers2', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/ers2')
  uploadDirToRemoteAutomationFolder(CONFIG.get['SAPHIRE_REDIS_HOST1'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['SAPHIRE_REMOTE_HOST1_PWD'], Dir.getwd+'/templates/config', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation')
  buildPtradeNewSchema(CONFIG.get['PTRADE_OLD_SCHEMA_VERSION'])
  buildPtradeApp(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], 'ptradeAPP_build_install_automatic.sh', Dir.getwd+'/templates/bash/', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation','') if(CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].nil? || CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].to_s.empty? )
  buildPtradeApp(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], 'ptradeAPP_build_install_automatic.sh', Dir.getwd+'/templates/bash/', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/', CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU']) if(!CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].nil? || !CONFIG.get['PTRADE_NEW_SCHEMA_VERSION_OU'].to_s.empty? )
  displayPtradeAppAndDbVersionForUpgrade(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  upgradePtradeToNewLabVersion
  buildPtradeApp(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], 'ptradeAPP_build_install_automatic.sh', Dir.getwd+'/templates/bash/', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation','')
  uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/new_app_config2/prod.conf', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/config/prod.conf')
  uploadDirToRemoteFolder(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'], Dir.getwd+'/templates/new_app_config2/fix/rtns/qfj.cfg', CONFIG.get['REMOTE_HOME']+'/'+CONFIG.get['CORE_HOST_USER']+'/Automation/PTS/config/fix/rtns/qfj.cfg')
  displayPtradeAppAndDbVersionForUpgrade(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])

  Actions.cleanupMsl(CONFIG.get['CORE_HOST_USER1'], CONFIG.get['MSL_HOST']) #temp
  ### Run MslErSender with other folder <ers2> and Start 2nd app
  killRedisRoot(CONFIG.get['CORE_HOST'])
  restartRedisWithNewConfigForNewVersion
  restartPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  runRemoteMslSender4upgrade2(CONFIG.get['CORE_HOST_USER'], false, 'ers2', CONFIG.get['MSL_HOST'])
  stopPtradeService(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
  downloadCsvFolderForNewVersion
  downloadJsonForNewVersion
end


Given /^Automation dir is shifted on both oracle and app servers$/ do
  Actions.createLocalDirs

  moveAutomationDir(CONFIG.get['ORACLE_HOST'], CONFIG.get['ORACLE_HOST_USER'], CONFIG.get['ORACLE_HOST_PWD'])
  moveAutomationDir(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER1'], CONFIG.get['CORE_HOST_PWD'])
  moveAutomationDir(CONFIG.get['CORE_HOST'], CONFIG.get['CORE_HOST_USER'], CONFIG.get['CORE_HOST_PWD'])
end

####



############Upgrade

Given /^Code Tested2$/  do
  debugUpgrade
end