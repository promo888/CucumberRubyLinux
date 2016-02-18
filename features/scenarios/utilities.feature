@utilities
Feature: Build old and new versions with schemas from scratch or upgrade, submit ers, compare db and output from adapters

  @mslCleaner
  Scenario: remove dump file, truncate tables and perform restart on a given MSL
  Given MSL is up and running
  Then MSL is cleaned
  And Jenkins will email PassedOrFailed