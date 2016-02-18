require 'time'
begin
  require '../../features/helpers/Actions'
rescue LoadError
end



Before do |scenario|
  $world = self
  @@scenario_fails = []
  time = Time.new
  @@time_stamp= time.day.to_s+'-'+time.month.to_s+'-'+time.year.to_s+'_'+time.hour.to_s+'-'+time.min.to_s+'-'+time.sec.to_s #Time.now.to_i.to_s
  @@before_upgrade_timestamp=@@time_stamp
  $VERBOSE = nil


  #Actions.WINCMD_NO_FAIL("TASKKILL /F /IM cmd.exe /T",20)
  if (scenario.source[1].tags[0].name.to_s.include?('@sanity-sdata-only'))
      Actions.valid_IP_v4?(CONFIG.get['ORACLE_HOST'])
      Actions.isUp?(CONFIG.get['ORACLE_HOST'])
  elsif (scenario.source[1].tags[0].name.to_s.include?('@sdata_lab'))
      CONFIG.get['ORACLE_HOST'] = CONFIG.get['ORACLE_HOST_IP']
      Actions.valid_IP_v4?(CONFIG.get['ORACLE_HOST'])
      Actions.isUp?(CONFIG.get['ORACLE_HOST'])
  elsif (!scenario.source[1].tags[0].name.to_s.include?('@mslCleaner') && !scenario.source[1].tags[0].name.to_s.include?('@test'))
    if scenario.source[1].tags[0].name.to_s.downcase.include?('lab')
      CONFIG.get['ORACLE_HOST'] = CONFIG.get['ORACLE_HOST_IP']
      CONFIG.get['CORE_HOST'] = CONFIG.get['CORE_HOST_IP']
    end
    Actions.valid_IP_v4?(CONFIG.get['ORACLE_HOST'])
    Actions.isUp?(CONFIG.get['ORACLE_HOST'])
    Actions.valid_IP_v4?(CONFIG.get['CORE_HOST'])
    Actions.isUp?(CONFIG.get['CORE_HOST'])
    if !scenario.source[1].tags[0].name.to_s.downcase.include?('lab')
      Actions.valid_IP_v4?(CONFIG.get['MSL_HOST_IP'])
      Actions.isUp?(CONFIG.get['MSL_HOST_IP'])
      Actions.valid_IP_v4?(CONFIG.get['MSL_HOST2_IP'])
      Actions.isUp?(CONFIG.get['MSL_HOST2_IP'])
      isMslRunning?(CONFIG.get['MSL_HOST_IP'])
      isMslRunning?(CONFIG.get['MSL_HOST2_IP'])
    end

  end
end

After do |scenario|

  Actions.v 'Starting post-scenario tasks...'

   #sanity scratch
   if scenario.source[1].tags[0].name.to_s.include?('@sanity-with-sdata-concurrent')
    if (!CONFIG.get['DEPLOY_SDATA'].nil? && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
      Actions.displaySanityLogs(true, true, true, true)
    else
      Actions.displaySanityLogs(false, false, true, true)
    end
   elsif scenario.source[1].tags[0].name.to_s.include?('@sanity-sdata-only')
     Actions.displaySanityLogs(true, true, false, false)
   end

   #sanity upgrade
   if scenario.source[1].tags[0].name.to_s.include?('@sanity-with-sdata-productionVsUpgrade2-concurrent')
     if (!CONFIG.get['DEPLOY_SDATA'].nil? && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
       Actions.displaySanityLogs(true, true, true, true)
     else
       Actions.displaySanityLogs(false, false, true, true)
     end
   end

   #custom builds
  if CONFIG.get['PTRADE_SCHEMA'] == 'ptrade'
    Actions.displaySanityLogs(true, false, true, false) if(scenario.source[1].tags[0].name.to_s.include?('@sdata_and_ptrade_lab'))
    Actions.displaySanityLogs(true, false, false, false) if(scenario.source[1].tags[0].name.to_s.include?('@sdata_lab'))
    Actions.displaySanityLogs(false, false, true, false) if(scenario.source[1].tags[0].name.to_s.include?('@ptrade_lab'))
    Actions.displaySanityLogs(true, false, true, false) if(scenario.source[1].tags[0].name.to_s.include?('@ptrade_upgrade_lab') && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
    Actions.displaySanityLogs(false, false, true, false) if(scenario.source[1].tags[0].name.to_s.include?('@ptrade_upgrade_lab') && CONFIG.get['DEPLOY_SDATA'].to_s.downcase!='true')
    Actions.displaySanityLogs(true, false, true, false) if(scenario.source[1].tags[0].name.to_s.include?('@ptrade_scratch_and_upgrade_lab') && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
    Actions.displaySanityLogs(false, false, true, false) if(scenario.source[1].tags[0].name.to_s.include?('@ptrade_scratch_and_upgrade_lab') && CONFIG.get['DEPLOY_SDATA'].to_s.downcase!='true')
  elsif CONFIG.get['PTRADE_SCHEMA'] == 'ptrade1'
    Actions.displaySanityLogs(false, true, false, true) if(scenario.source[1].tags[0].name.to_s.include?('@sdata_and_ptrade_lab'))
    Actions.displaySanityLogs(false, true, false, false) if(scenario.source[1].tags[0].name.to_s.include?('@sdata_lab'))
    Actions.displaySanityLogs(false, false, false, true) if(scenario.source[1].tags[0].name.to_s.include?('@ptrade_lab'))
    Actions.displaySanityLogs(false, true, false, true) if(scenario.source[1].tags[0].name.to_s.include?('@ptrade_upgrade_lab') && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
    Actions.displaySanityLogs(false, false, false, true) if(scenario.source[1].tags[0].name.to_s.include?('@ptrade_upgrade_lab') && CONFIG.get['DEPLOY_SDATA'].to_s.downcase!='true')
    Actions.displaySanityLogs(false, true, false, true) if(scenario.source[1].tags[0].name.to_s.include?('@ptrade_scratch_and_upgrade_lab') && CONFIG.get['DEPLOY_SDATA'].to_s.downcase=='true')
    Actions.displaySanityLogs(false, false, false, true) if(scenario.source[1].tags[0].name.to_s.include?('@ptrade_scratch_and_upgrade_lab') && CONFIG.get['DEPLOY_SDATA'].to_s.downcase!='true')
  end

   scenario.fail('See Errors in Red') if(!@@scenario_fails.empty?)
end

Around('@test') do |scenario, block|
  Timeout.timeout(600) do
    block.call
    #puts '@test TIMEOUT'
  end
end

Around('@sanity-sdata-only') do |scenario, block|
  #Actions.displaySanityLogs(true, true, false, false) if(!@@scenario_fails.empty?)
  Timeout.timeout(3000) do
    block.call
  end
end

Around('@sanity-with-sdata-oldAndNewVsUpgrade2') do |scenario, block|
  #Actions.displaySanityLogs(true, true, true, true) if(!@@scenario_fails.empty?)
  Timeout.timeout(3600) do
    block.call
  end
end



### Custom Builds

Around('@sdata_and_ptrade_lab') do |scenario, block|
  #Actions.displaySanityLogs(true, false, true, false) if(!@@scenario_fails.empty?)
  Timeout.timeout(CONFIG.get['DEPLOYMENT_TIMEOUT'].to_i) do
    block.call
  end
end

Around('@sdata_lab') do |scenario, block|
  #Actions.displaySanityLogs(true, false, true, false) if(!@@scenario_fails.empty?)
  Timeout.timeout(CONFIG.get['DEPLOYMENT_TIMEOUT'].to_i) do
    block.call
  end
end

Around('@ptrade_lab') do |scenario, block|
  #Actions.displaySanityLogs(true, false, true, false) if(!@@scenario_fails.empty?)
  Timeout.timeout(CONFIG.get['DEPLOYMENT_TIMEOUT'].to_i) do
    block.call
  end
end

Around('@ptrade_upgrade_lab') do |scenario, block|
  #Actions.displaySanityLogs(true, false, false, false) if(!@@scenario_fails.empty?)
  Timeout.timeout(CONFIG.get['DEPLOYMENT_TIMEOUT'].to_i) do
    block.call
  end
end

Around('@ptrade_scratch_and_upgrade_lab') do |scenario, block|
  #Actions.displaySanityLogs(true, false, false, false) if(!@@scenario_fails.empty?)
  Timeout.timeout(CONFIG.get['DEPLOYMENT_TIMEOUT'].to_i) do
    block.call
  end
end