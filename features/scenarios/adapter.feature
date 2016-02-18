@old
Feature: Tidy Adapters Test

  @old
  Scenario Outline: Submit ER and test Adapters
    When User is running LOCAL ER Simulator <er_file_path> <scenario_folder>
    Then DB tables DEAL TICKETS LEGS are matched by <scenario_type> <deal_type>
    Then MyTreasury adapter csv file is matched
    Then Sapphire Redis json matched with ER
    Then Kafka adapter mbr file is matched
    Then TOF adapter fix output is matched
    Then Traiana adapter is matched
    Then Status of All adapters

    Examples:
      |er_file_path                                               |scenario_folder | scenario_type|  deal_type  |
      |libs/MSLErSender/bin/ers/Scenario1/ER2_SPOT_SP-PC_MT.txt   |ers/Scenario1   | SP_PC        |  spot       |
      |libs/MSLErSender/bin/ers/Scenario2/ER2_FWD_SP-PC_MT.txt    |ers/Scenario2   | SP_PC        |  forward    |
      |libs/MSLErSender/bin/ers/Scenario3/ER2_SWAP_SP-PC_MT.txt   |ers/Scenario3   | SP_PC        |  swap       |


