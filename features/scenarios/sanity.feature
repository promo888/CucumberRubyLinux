  @sanity
  Feature: Test All Ptrade Adapters

  @diff @all_adapters
  Scenario: Test Ptrade DB and Adapters
       Given SDATA SCHEMAS Test Setup is Done
       Then SDATA schema compared
       Given PTRADE SCHEMAS Test Setup is Done
       Given Msl Recovery setup is Done
    Then DB tables DEAL TICKETS LEGS are matched vs template
    Then Template and Downloaded MyT csv Folders are Matched excluding timestamps
    Then Template and Downloaded Saphire Jsons are Matched excluding sequence
