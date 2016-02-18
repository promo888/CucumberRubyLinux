@sanity2
Feature: Build old and new versions with schemas from scratch or upgrade, submit ers, compare db and output from adapters

  @sanity-sdata-only
  Scenario: Build old and new versions  SDATA schemas from scratch
    Given SDATA SCHEMAS Setup is Done - Parcipany and Last Lab versions
    Then SDATA schema compared
    Then Jenkins will email PassedOrFailed


  @sanity-with-sdata-concurrent
  Scenario: Build old and new versions WITH Sdata and Ptrade schemas from scratch, submit ers, compare db and output from adapters
    Given SDATA SCHEMAS Concurrent Setup is Done - Parcipany and Last Lab versions
    Given Ptrade Apps And Schemas are built for Production version and  New Lab version
    Then DB tables DEAL TICKETS LEGS compared for both versions
    Then Old and New versions csv Folders are Matched excluding timestamps
    Then Old and New Saphire Jsons are Matched excluding sequence
    #Then Old and New versions Traiana outgoing data compared as CSV
    #Then Old and New versions RTNS outgoing data compared
    Then Jenkins will email PassedOrFailed


  @sanity-with-sdata-productionVsUpgrade2-concurrent
  Scenario: Build old and new versions WITH Sdata and Ptrade schemas from scratch,upgrade to Lab latest version, submit ers, compare db and output from adapters
    Given SDATA SCHEMAS Concurrent Setup is Done - Production version for both users
    Given Ptrade Apps And Schemas are built for Production for both users
    Given Ptrade App and Schemas are Upgraded to the Last Sdata and Ptrade Lab version
    Then Ptrade App is restarted and data downloaded for both users
    Then DB tables DEAL TICKETS LEGS compared for both versions
    Then Old and New versions csv Folders are Matched excluding timestamps after upgrade
    Then Old and New Saphire Jsons are Matched excluding sequence after upgrade
    #Then Old and New versions Traiana outgoing data compared as CSV
    #Then Old and New versions RTNS outgoing data compared
    Then Jenkins will email PassedOrFailed