Given /^MSL is up and running$/ do
  Actions.isIpValidInParams

  cmd = 'uptime'
  res = Actions.SSH(CONFIG.get['MSL_HOST_CUSTOM_IP'], CONFIG.get['MSL_HOST_USER'], CONFIG.get['MSL_HOST_PWD'], cmd, 15, true, '')
  if (res.nil? || res.to_s.empty?)
    @@scenario_fails.push('Error: MSL is probably not up')
    fail('Error: cannot connect to given MSL '+CONFIG.get['MSL_HOST_CUSTOM_IP']+', check that the machine is up')
  end
  Actions.v 'Output of uptime check: '+res

  cmd = 'ps -aef|grep postgres|grep -v grep'
  res = Actions.SSH(CONFIG.get['MSL_HOST_CUSTOM_IP'], CONFIG.get['MSL_HOST_USER'], CONFIG.get['MSL_HOST_PWD'], cmd, 15, true, '')
  if (res.nil? || res.to_s.empty?)
    @@scenario_fails.push('Error: postgres is not running')
    fail('Error: cannot find running postgres on the given MSL '+CONFIG.get['MSL_HOST_CUSTOM_IP']+', check that the service is launched')
  end
  Actions.v 'Output of ps check: '+res
end

Then /^MSL is cleaned$/ do
  Actions.createLocalDirsTemplatesLogs
  createDirForUser(CONFIG.get['MSL_HOST_CUSTOM_IP'], CONFIG.get['MSL_HOST_USER'], CONFIG.get['MSL_HOST_PWD'], 'Automation_utilities')
  Actions.cleanupMslCustom(CONFIG.get['MSL_HOST_CUSTOM_IP'], 'Automation_utilities')
end

def isMslRunning?(mslIP)
  Actions.v 'Checking MSL '+mslIP+' uptime...'
  cmd = 'uptime'
  res = Actions.SSH(mslIP, CONFIG.get['MSL_HOST_USER'], CONFIG.get['MSL_HOST_PWD'], cmd, 15, true, '')
  if (res.nil? || res.to_s.empty?)
    @@scenario_fails.push('Error: MSL is probably not up')
    fail('Error: cannot connect to given MSL '+mslIP+', check that the machine is up')
  end
  Actions.v 'Output of MSL '+mslIP+' uptime check: '+res

  Actions.v 'Checking MSL '+mslIP+' postgres processes...'
  cmd = 'ps -aef|grep postgres|grep -v grep'
  res = Actions.SSH(mslIP, CONFIG.get['MSL_HOST_USER'], CONFIG.get['MSL_HOST_PWD'], cmd, 15, true, '')
  if (res.nil? || res.to_s.empty?)
    @@scenario_fails.push('Error: postgres is not running')
    fail('Error: cannot find running postgres on the given MSL '+mslIP+', check that the service is launched')
  end
  Actions.v 'Output of MSL '+mslIP+' ps check: '+res
end