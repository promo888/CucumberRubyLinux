@custom
Feature: Deploy Ptrade App and Schema or/and Sdata schema from Scratch,if version not defined as param the last version will be built


  @sdata
  Scenario: """
				    MOUNT TO BUILDSERVER/RELEASES SHOULD EXIST ON DEPLOYMENT PC
					Test Deploy SDATA Schema from Scratch on custom servers,if version not defined as param the last version will be built
                    You can define any param such as version,user,pwd,host,port...etc
                    Edit Jenkins Job->Configure->Run Batch Command-> Your Params->Save (append to the end of line cucumber...MYPARAM=MYVALUE)
                    Params List can be found under Job->Workspace->environments.yaml under the CUSTOM section
                    Insert Your email in Jenkins in order to get PASS/FAIL email when done
                    Enjoy :)
					"""
    Given Sdata Schema is Built
    Then  Jenkins will email PassedOrFailed


  @ptrade
  Scenario: """
			MOUNT TO BUILDSERVER/RELEASES SHOULD EXIST ON DEPLOYMENT PC
			Test Deploy Ptrade App and Schema from Scratch on custom servers,if version not defined as param the last version will be built
            You can define any param such as version,user,pwd,host,port...etc
            Edit Jenkins Job->Configure->Run Batch Command-> Your Params->Save (append to the end of line cucumber...MYPARAM=MYVALUE)
            Params List can be found under Job->Workspace->environments.yaml under the CUSTOM section
            Insert Your email in Jenkins in order to get PASS/FAIL email when done
            Enjoy :)
			"""
    Given Ptrade App and Schema are Built
    Then  Jenkins will email PassedOrFailed



  @sdata_and_ptrade
  Scenario: """
			MOUNT TO BUILDSERVER/RELEASES SHOULD EXIST ON DEPLOYMENT PC
			Test Deploy Ptrade App and Schema from Scratch(Production versions) on custom servers,if version not defined as param the last version will be built
            You can define any param such as version,user,pwd,host,port...etc
            Edit Jenkins Job->Configure->Run Batch Command-> Your Params->Save (append to the end of line cucumber...MYPARAM=MYVALUE)
            Params List can be found under Job->Workspace->environments.yaml under the CUSTOM section
            Insert Your email in Jenkins in order to get PASS/FAIL email when done
            Enjoy :)
			"""
    Given Sdata and Ptrade App and Schema are Built
    Then  Jenkins will email PassedOrFailed


  @sdata_and_ptrade_upgrade
  Scenario: """
			MOUNT TO BUILDSERVER/RELEASES SHOULD EXIST ON DEPLOYMENT PC
			Test Deploy Ptrade App and Schema from Scratch(Production versions) on custom servers,then Upgrade Ptrade App and Schema to the Latest Lab version,
			 if version not defined as param the last version will be built
            You can define any param such as version,user,pwd,host,port...etc
            Edit Jenkins Job->Configure->Run Batch Command-> Your Params->Save (append to the end of line cucumber...MYPARAM=MYVALUE)
            Params List can be found under Job->Workspace->environments.yaml under the CUSTOM section
            Insert Your email in Jenkins in order to get PASS/FAIL email when done
            Enjoy :)
			"""
    Given Sdata and Ptrade App and Schema are Built
    Then  Upgrade Ptrade to the Latest Lab version
    Then  Jenkins will email PassedOrFailed



  @sdata_lab
  Scenario: "Building SDATA SCHEMA"
    Given Sdata Schema is built for LAB
    Then  Jenkins will email PassedOrFailed

  @ptrade_lab
  Scenario: "Building PTRADE SCHEMA and APP"
    Given Ptrade App and Schema are built for LAB
    Then  Jenkins will email PassedOrFailed

  @sdata_and_ptrade_lab
  Scenario: "Building PTRADE SCHEMA and APP, building SDATA is optional"
    Given Ptrade App, Schema and optional Sdata are built for LAB
    Then  Jenkins will email PassedOrFailed

  @ptrade_upgrade_lab
  Scenario: "Upgrading PTRADE SCHEMA and building newer APP, building SDATA is optional"
    Given Ptrade App, Schema and optional Sdata are upgraded for LAB
    Then  Jenkins will email PassedOrFailed

  @ptrade_scratch_and_upgrade_lab
  Scenario: "Building PTRADE SCHEMA and APP, upgrading PTRADE SCHEMA and building newer APP, building SDATA is optional"
    Given Old Ptrade App, Schema and optional Sdata are built for LAB
    Given Ptrade App, Schema and optional Sdata are upgraded for LAB
    Then  Jenkins will email PassedOrFailed