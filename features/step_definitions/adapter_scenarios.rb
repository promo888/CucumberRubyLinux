require 'cucumber'
require 'json'

begin
  require '../../../features/helpers/Actions'
  require '../../../features/helpers/Config.rb'
  include Config
rescue LoadError
end



#C:\Users\ibershtein\RubymineProjects\Automation>cucumber -t @adapters -f html --out report.html -f json --out report.json >sanity.log
When /^User is running LOCAL ER Simulator (.*) (.*)$/  do |er_file_path,scenario_folder|
  $cmd_res=nil
  $exec_id=nil
  $er=nil


  $cmd_res = Actions::WINCMD('cd ' +Dir.getwd+'/libs/MSLErSender/bin & mslErSender.bat ' + scenario_folder, 60, 'txt with execId') #Run ER Simulator
  $exec_ids = $cmd_res.to_s.scan(/txt with execId(.*?)\[(.*?)\]/i)
  $exec_id = $exec_ids[0][1]
  puts '<br>'+'Following ExecID is Found - ' + $exec_id + '<br>'


  $er = Actions.getHashFromErFile(er_file_path) #parse ER file
  puts '<br> Current ER file ' + $er.to_s + '<br>'





end

Then /^DB tables DEAL TICKETS LEGS are matched by (.*) (.*)$/  do |scenario_type,deal_type|
  $db_res = nil
  $deals_amount = nil
  $deal_legs_amount = nil
  $ticket_legs_amount = nil
    case $er['securityType'] #TODO verify Excel missing scenarios + to variate deals by scenario_type SP-SP,SP-PC,SPOT,PC-SP folders
      when 'FX_SPOT'
        $deals_amount = 1
        $deal_legs_amount = 1
        $ticket_legs_amount = 1
      when 'FX_FWD'
        $deals_amount = 1
        $deal_legs_amount = 1
        $ticket_legs_amount = 1
      when 'FX_SWAP'
        $deals_amount = 1
        $legs_amount = 2
        $ticket_legs_amount = 2

    end
  matchDbFxDeal("select * from fx_deal where EXEC_ID='" + $exec_id+"'",$deals_amount)

  matchDbFxDealLeg("select * from fx_deal_leg where EXEC_ID='" + $exec_id+"' and FP_SIDE=1",$deal_legs_amount) if (deal_type=='swap') #match FirstParty
  matchDbFxDealLeg("select * from fx_deal_leg where EXEC_ID='" + $exec_id+"' and FP_SIDE=0",$deal_legs_amount) #match CounterParty
  matchDbFxTicketLeg("select * from fx_ticket_leg where EXEC_ID='" + $exec_id+"' and LEG_TYPE=0", 1) if (deal_type=='forward' || deal_type=='spot') #Match No Legs
  matchDbFxTicketLeg("select * from fx_ticket_leg where EXEC_ID='" + $exec_id+"' and LEG_TYPE=1", 1) if (deal_type=='swap') #match FirstLeg #TODO if correct by leg_type? or by EXEC_ID+0001/2
  matchDbFxTicketLeg("select * from fx_ticket_leg where EXEC_ID='" + $exec_id+"' and LEG_TYPE=2",1) if (deal_type=='swap') #match SecondLeg #TODO if correct by leg_type?

end


Then /^MyTreasury adapter csv file is matched$/  do

end

Then /^Sapphire Redis json matched with ER$/  do

end

Then /^Kafka adapter mbr file is matched$/  do

end

Then /^TOF adapter fix output is matched$/  do

end

Then /^Traiana adapter is matched$/  do

end

Then /^Status of All adapters$/  do
   # puts "<br><br>Redis adapter failed...<br>"
   # fail( "Redis adapter failed..\r\n")
end




def matchDbFxDeal(query,rows_amount)
  sleep 5
  $db_res = Actions.getDbQueryResults(query, rows_amount)
  puts '<br> query ' + query + ' results : <br>' + $db_res[0].to_s + '<br>'

  puts '<br> ASSERTED - '+ rows_amount.to_s + ' rows amount for query - ' + query + '<br>'

  #$db_res[0]['EXEC_ID'].equal?($exec_id)
  failOrContinueOnAssert($db_res[0]['EXEC_ID'],$exec_id,true,"DB FX_DEAL[EXEC_ID] should be equal to " + $exec_id + ' but Actual is '+$db_res[0]['EXEC_ID'])
  # ? failOrContinueOnMatch($er['executingParty']['floorKey'],$db_res[0]['EFP_INSTITUTION_KEY'],true,"DB FX_DEAL[EFP_INSTITUTION_KEY] should be equal to " + $er['executingParty']['floorKey'] + ' but Actual is '+$db_res[0]['EFP_INSTITUTION_KEY'].to_s)
  failOrContinueOnMatch($er['secondaryExecId'],$db_res[0]['EXEC_ID2'],true,"DB ECP_ORDER_ID should be equal to " +$er['secondaryExecId'] + ' but Actual is '+$db_res[0]['EXEC_ID2'].to_s)
# ?  failOrContinueOnAssert($db_res[0]['MARKET_SEGMENT'],$er['marketSegmentId'],true,"DB FX_DEAL[MARKET_SEGMENT] should be equal to " + $er['marketSegmentId'].to_s+ ' but Actual is '+$db_res[0]['MARKET_SEGMENT'].to_s)
  failOrContinueOnAssert($db_res[0]['INSTR_SEC_ID'],$er['securityId'],true,"DB FX_DEAL[INSTR_SEC_ID] should be equal to " + $er['securityId']+ ' but Actual is '+$db_res[0]['INSTR_SEC_ID'].to_s)
  failOrContinueOnMatch($er['symbol'],$db_res[0]['INSTR_SYMBOL'],true,"DB FX_DEAL[INSTR_SYMBOL] should be equal to " + $er['symbol'] + ' but Actual is '+$db_res[0]['INSTR_SYMBOL'].to_s)
  #failOrContinueOnAssert($db_res[0]['INSTR_PRODUCT_TYPE'],$er['securityType'],true,"DB FX_DEAL[INSTR_PRODUCT_TYPE] should be equal to " + $er['securityType']+ ' but Actual is '+$db_res[0]['INSTR_PRODUCT_TYPE'].to_s)
  #failOrContinueOnAssert($db_res[0]['IS_TERM_CCY'],$er['isTermCcy'],true,"DB FX_DEAL[IS_TERM_CCY] should be equal to " + $er['isTermCcy']+ ' but Actual is '+$db_res[0]['IS_TERM_CCY'].to_s)
  failOrContinueOnMatch($er['orderId'],$db_res[0]['EFP_EBS_ORDER_ID'],true,"DB FX_DEAL[EFP_EBS_ORDER_ID] should be equal to " +$er['orderId'] + ' but Actual is '+$db_res[0]['EFP_EBS_ORDER_ID'].to_s)
  failOrContinueOnMatch($er['clOrdId'],$db_res[0]['EFP_ORDER_ID'],true,"DB FX_DEAL[EFP_ORDER_ID] should be equal to " +$er['clOrdId'] + ' but Actual is '+$db_res[0]['EFP_ORDER_ID'].to_s)
  #failOrContinueOnMatch($er['secondaryExecId'],$db_res[0]['ECP_ORDER_ID'],true,"DB FX_DEAL[ECP_ORDER_ID] should be equal to " +$er['secondaryExecId'] + ' but Actual is '+$db_res[0]['ECP_ORDER_ID'].to_s)
  failOrContinueOnMatch($er['executingParty']['floorCode'],$db_res[0]['EFP_FLOOR'],true,"DB FX_DEAL[EFP_FLOOR] should be equal to " + $er['executingParty']['floorCode']+ ' but Actual is '+$db_res[0]['EFP_FLOOR'].to_s)
  failOrContinueOnAssert($db_res[0]['EFP_FLOOR_KEY'],$er['executingParty']['floorKey'],true,"DB FX_DEAL[EFP_FLOOR_KEY] should be equal to " + $er['executingParty']['floorKey']+ ' but Actual is '+$db_res[0]['EFP_FLOOR_KEY'].to_s)
 # failOrContinueOnMatch($er['executingParty']['traderId'],$db_res[0]['EFP_TRADER'],true,"DB FX_DEAL[EFP_TRADER] should be equal to " + $er['executingParty']['traderId']+ ' but Actual is '+$db_res[0]['EFP_TRADER'].to_s)
  failOrContinueOnMatch($er['counterParty']['floorCode'],$db_res[0]['ECP_FLOOR'],true,"DB FX_DEAL[ECP_FLOOR] should be equal to " + $er['counterParty']['floorCode']+ ' but Actual is '+$db_res[0]['ECP_FLOOR'].to_s)
  failOrContinueOnAssert($db_res[0]['ECP_FLOOR_KEY'],$er['counterParty']['floorKey'],true,"DB FX_DEAL[ECP_FLOOR_KEY] should be equal to " + $er['counterParty']['floorKey']+ ' but Actual is '+$db_res[0]['ECP_FLOOR_KEY'].to_s)
#  failOrContinueOnMatch($er['counterParty']['traderId'],$db_res[0]['ECP_TRADER'],true,"DB FX_DEAL[ECP_TRADER] should be equal to " + $er['counterParty']['traderId'].to_s + ' but Actual is '+$db_res[0]['ECP_TRADER'].to_s)

  val = $er['unsolicitedIndicator'] == 'true' ? '1' : '0'
  failOrContinueOnAssert($db_res[0]['IND_UNSOLICITED'],val,true,"DB FX_DEAL[IND_UNSOLICITED] should be equal to " + val+ ' but Actual is '+$db_res[0]['IND_UNSOLICITED'].to_s)

  orderType=''
  case $er['ordType']
    when 'LIMIT' #TODO to continue with types
      orderType = '0'
  end
  failOrContinueOnAssert($db_res[0]['ORD_TYPE'],orderType,true,"DB FX_DEAL[ORD_TYPE] should be equal to " + orderType+ ' but Actual is '+$db_res[0]['ORD_TYPE'].to_s)

  failOrContinueOnAssert($db_res[0]['ORD_QUOTE_REQUEST_ID'],$er['clQuoteReqId'],true,"DB FX_DEAL[ORD_QUOTE_REQUEST_ID] should be equal to " + $er['clQuoteReqId']+ ' but Actual is '+$db_res[0]['ORD_QUOTE_REQUEST_ID'].to_s)

  #calculated/new fields
  failOrContinueOnAssert($db_res[0]['TXN_TIME'],$er['transactTime'],true,"DB FX_DEAL[TXN_TIME] should be equal to " + $er['transactTime'] + ' but Actual is '+$db_res[0]['TXN_TIME'].to_s)
  #failOrContinueOnAssert($db_res[0]['TRADE_DATE'],$er['tradeDate'],true,"DB FX_DEAL[TRADE_DATE] should be equal to " + $er['tradeDate']+ ' but Actual is '+$db_res[0]['TRADE_DATE'].to_s)
  #failOrContinueOnAssert($db_res[0]['SPOT_SETTL_DATE'],$er['spotSettlDate'],true,"DB FX_DEAL[SPOT_SETTL_DATE] should be equal to " + $er['spotSettlDate'].to_s + ' but Actual is '+$db_res[0]['SPOT_SETTL_DATE'].to_s)

  #for swap deals only #TODO ord SWAP section and missing ENUMs
  if $er['securityType']=='FX_SWAP'
    failOrContinueOnAssert($db_res[0]['PX_SWAP_POINTS'],$er['tradeSwapPoints']['mantissa'],true,"DB FX_DEAL[PX_SWAP_POINTS] should be equal to " + $er['tradeSwapPoints']['mantissa'].to_s+ ' but Actual is '+$db_res[0]['PX_SWAP_POINTS'].to_s)
    failOrContinueOnAssert($db_res[0]['PX_SWAP_POINTS_EXP'],$er['tradeSwapPoints']['exponent'],true,"DB FX_DEAL[PX_SWAP_POINTS_EXP] should be equal to " + $er['tradeSwapPoints']['exponent'].to_s + ' but Actual is '+$db_res[0]['PX_SWAP_POINTS_EXP'].to_s)
  end





end



def matchDbFxDealLeg(query,rows_amount)
 $db_res = Actions.getDbQueryResults(query, rows_amount)
  puts '<br> query ' + query + ' results : <br>' + $db_res[0].to_s + '<br>'
  puts '<br> ASSERTED - '+ rows_amount.to_s + ' rows amount for query - ' + query + '<br>'

 failOrContinueOnAssert($db_res[0]['EXEC_ID'],$exec_id,true,"DB FX_DEAL_LEG[EXEC_ID] should be equal to " + $exec_id + ' but Actual is '+$db_res[0]['EXEC_ID'].to_s)

 #TODO this one is covered by query  where FP_SIDE = 1,other query where FP_SIDE=0 for counterparty
=begin
 legSide = $er['tradeLeg']['legSide'] == 'BUY' ? '1' : '0'
 failOrContinueOnAssert($db_res[0]['FP_SIDE'],legSide,true,"DB FX_DEAL_LEG[FP_SIDE] should be equal to " + legSide + ' but Actual is '+$db_res[0]['FP_SIDE'])
=end
  # ? failOrContinueOnAssert($db_res[0]['PX_ALLIN'],$er['tradeLeg']['tradePx']['mantissa'],true,"DB FX_DEAL_LEG[PX_ALLIN] should be equal to " + $er['tradeLeg']['tradePx']['mantissa'] + ' but Actual is '+$db_res[0]['PX_ALLIN'].to_s)
  failOrContinueOnAssert($db_res[0]['PX_EXP'],$er['tradeLeg']['tradePx']['exponent'],true,"DB FX_DEAL_LEG[PX_EXP] should be equal to " + $er['tradeLeg']['tradePx']['exponent'] + ' but Actual is '+$db_res[0]['PX_EXP'].to_s)


  case $er['securityType'] #TODO verify with Larisa +Excel missing scenarios
    when 'FX_SPOT'
      failOrContinueOnAssert($db_res[0]['PX_SPOT_ALLIN'],$er['tradeLeg']['tradeSpotRate']['mantissa'],true,"DB FX_DEAL_LEG[PX_SPOT_ALLIN] should be equal to " + $er['tradeLeg']['tradeSpotRate']['mantissa'] + ' but Actual is '+$db_res[0]['PX_SPOT_ALLIN'].to_s)
      failOrContinueOnAssert($db_res[0]['PX_SPOT_EXP'],$er['tradeLeg']['tradeSpotRate']['exponent'],true,"DB FX_DEAL_LEG[PX_SPOT_EXP] should be equal to " + $er['tradeLeg']['tradeSpotRate']['exponent'] + ' but Actual is '+$db_res[0]['PX_SPOT_EXP'].to_s)

    when 'FX_FWD' #TODO ? 0 if spot ?
      failOrContinueOnAssert($db_res[0]['PX_FWDP_ALLIN'],$er['tradeLeg']['tradeForwardPoints']['mantissa'],true,"DB FX_DEAL_LEG[PX_FWDP_ALLIN] should be equal to " + $er['tradeLeg']['tradeForwardPoints']['mantissa'] + ' but Actual is '+$db_res[0]['PX_FWDP_ALLIN'].to_s)
      failOrContinueOnAssert($db_res[0]['PX_FWDP_EXP'],$er['tradeLeg']['tradeForwardPoints']['exponent'],true,"DB FX_DEAL_LEG[PX_SPOT_EXP] should be equal to " + $er['tradeLeg']['tradeForwardPoints']['exponent'] + ' but Actual is '+$db_res[0]['PX_SPOT_EXP'].to_s)

    when 'FX_SWAP'
      puts 'TODO' #TODO

  end

  failOrContinueOnAssert($db_res[0]['QTY_DEALT'],$er['tradeLeg']['tradeQty']['mantissa'],true,"DB FX_DEAL_LEG[QTY_DEALT] should be equal to " + $er['tradeLeg']['tradeQty']['mantissa'] + ' but Actual is '+$db_res[0]['QTY_DEALT'].to_s)
  failOrContinueOnAssert($db_res[0]['QTY_DEALT_EXP'],$er['tradeLeg']['tradeQty']['exponent'],true,"DB FX_DEAL_LEG[QTY_DEALT_EXP] should be equal to " + $er['tradeLeg']['tradeQty']['exponent'] + ' but Actual is '+$db_res[0]['QTY_DEALT_EXP'].to_s)
 # ? swap fails failOrContinueOnAssert($db_res[0]['QTY_CNTR'],$er['tradeLeg']['tradeContraQty']['mantissa'],true,"DB FX_DEAL_LEG[QTY_CNTR] should be equal to " + $er['tradeLeg']['tradeContraQty']['mantissa'] + ' but Actual is '+$db_res[0]['QTY_CNTR'].to_s)
#  failOrContinueOnAssert($db_res[0]['QTY_DEALT_EXP'],$er['tradeLeg']['tradeContraQty']['exponent'],true,"DB FX_DEAL_LEG[QTY_DEALT_EXP] should be equal to " + $er['tradeLeg']['tradeContraQty']['exponent'] + ' but Actual is '+$db_res[0]['QTY_DEALT_EXP'].to_s)
#  failOrContinueOnAssert($db_res[0]['DATE_SETTLEMENT'],$er['instrumentLeg']['settlDate'],true,"DB FX_DEAL_LEG[DATE_SETTLEMENT] should be equal to " + $er['instrumentLeg']['settlDate'] + ' but Actual is '+$db_res[0]['DATE_SETTLEMENT'].to_s)



end



#TODO to continue + complete tenor here and fx_deal
def matchDbFxTicketLeg(query,rows_amount)
  $db_res = Actions.getDbQueryResults(query, rows_amount)
  puts '<br> query ' + query + ' results : <br>' + $db_res[0].to_s + '<br>'

  puts '<br> ASSERTED - '+ rows_amount.to_s + ' rows amount for query - ' + query + '<br>'

 #as in fx_deal
 failOrContinueOnAssert($db_res[0]['EXEC_ID'],$exec_id,true,"DB FX_TICKET_LEG[EXEC_ID] should be equal to " + $exec_id + ' but Actual is '+$db_res[0]['EXEC_ID'].to_s)
 failOrContinueOnAssert($db_res[0]['TXN_TIME'],$er['transactTime'],true,"DB FX_TICKET_LEG[TXN_TIME] should be equal to " + $er['transactTime'] + ' but Actual is '+$db_res[0]['TXN_TIME'].to_s)
 failOrContinueOnMatch($er['secondaryExecId'],$db_res[0]['EXEC_ID2'],true,"DB FX_TICKET_LEG[EXEC_ID2] should be equal to " +$er['secondaryExecId'] + ' but Actual is '+$db_res[0]['EXEC_ID2'].to_s)
 failOrContinueOnAssert($db_res[0]['INSTR_SEC_ID'],$er['securityId'],true,"DB FX_TICKET_LEG[INSTR_SEC_ID] should be equal to " + $er['securityId']+ ' but Actual is '+$db_res[0]['INSTR_SEC_ID'].to_s)
 failOrContinueOnMatch($er['symbol'],$db_res[0]['INSTR_SYMBOL'],true,"DB FX_TICKET_LEG[INSTR_SYMBOL] should be equal to " + $er['symbol'] + ' but Actual is '+$db_res[0]['INSTR_SYMBOL'].to_s)

 #failOrContinueOnAssert($db_res[0]['INSTR_PRODUCT_TYPE'],$er['securityType'],true,"DB FX_DEAL[INSTR_PRODUCT_TYPE] should be equal to " + $er['securityType']+ ' but Actual is '+$db_res[0]['INSTR_PRODUCT_TYPE'].to_s)
 #failOrContinueOnAssert($db_res[0]['MARKET_SEGMENT'],$er['marketSegmentId'],true,"DB FX_DEAL[MARKET_SEGMENT] should be equal to " + $er['marketSegmentId']+ ' but Actual is '+$db_res[0]['MARKET_SEGMENT'].to_s)
 #failOrContinueOnAssert($db_res[0]['DATE_SETTLEMENT'],$er['instrumentLeg']['settlDate'],true,"DB FX_DEAL_LEG[DATE_SETTLEMENT] should be equal to " + $er['instrumentLeg']['settlDate'] + ' but Actual is '+$db_res[0]['DATE_SETTLEMENT'].to_s)
 #failOrContinueOnAssert($db_res[0]['FP_ROLE'],$er['tradeDate'],true,"DB FX_TICKET_LEG[TRADE_DATE] should be equal to " + $er['tradeDate']+ ' but Actual is '+$db_res[0]['TRADE_DATE'].to_s)
 #failOrContinueOnAssert($db_res[0]['SPOT_SETTL_DATE'],$er['spotSettlDate'],true,"DB FX_TICKET_LEG[SPOT_SETTL_DATE] should be equal to " + $er['spotSettlDate'].to_s + ' but Actual is '+$db_res[0]['SPOT_SETTL_DATE'].to_s)
 #failOrContinueOnAssert($db_res[0]['IS_TERM_CCY'],$er['isTermCcy'],true,"DB FX_TICKET_LEG[IS_TERM_CCY] should be equal to " + $er['isTermCcy']+ ' but Actual is '+$db_res[0]['IS_TERM_CCY'].to_s)


  #TODO to complete fx_deal_leg vs ticket_leg section
  #as in fx_deal_leg
  failOrContinueOnAssert($db_res[0]['QTY_DEALT'],$er['tradeLeg']['tradeQty']['mantissa'],true,"DB FX_TICKET_LEG[QTY_DEALT] should be equal to " + $er['tradeLeg']['tradeQty']['mantissa'] + ' but Actual is '+$db_res[0]['QTY_DEALT'].to_s)
  failOrContinueOnAssert($db_res[0]['QTY_DEALT_EXP'],$er['tradeLeg']['tradeQty']['exponent'],true,"DB FX_TICKET_LEG[QTY_DEALT_EXP] should be equal to " + $er['tradeLeg']['tradeQty']['exponent'] + ' but Actual is '+$db_res[0]['QTY_DEALT_EXP'].to_s)
  #swap fails failOrContinueOnAssert($db_res[0]['QTY_CNTR'],$er['tradeLeg']['tradeContraQty']['mantissa'],true,"DB FX_TICKET_LEG[QTY_CNTR] should be equal to " + $er['tradeLeg']['tradeContraQty']['mantissa'] + ' but Actual is '+$db_res[0]['QTY_CNTR'].to_s)

  if $er['securityType']=='FX_SPOT'
    failOrContinueOnAssert($db_res[0]['PX_SPOT_ALLIN'],$er['tradeLeg']['tradeSpotRate']['mantissa'],true,"DB FX_TICKET_LEG[PX_SPOT_ALLIN] should be equal to " + $er['tradeLeg']['tradeSpotRate']['mantissa'] + ' but Actual is '+$db_res[0]['PX_SPOT_ALLIN'].to_s)
    failOrContinueOnAssert($db_res[0]['PX_SPOT_EXP'],$er['tradeLeg']['tradeSpotRate']['exponent'],true,"DB FX_TICKET_LEG[PX_SPOT_EXP] should be equal to " + $er['tradeLeg']['tradeSpotRate']['exponent'] + ' but Actual is '+$db_res[0]['PX_SPOT_EXP'].to_s)
  end

  if $er['securityType']=='FX_FWD'
    failOrContinueOnAssert($db_res[0]['PX_FWDP_ALLIN'],$er['tradeLeg']['tradeForwardPoints']['mantissa'],true,"DB FX_TICKET_LEG[PX_FWDP_ALLIN] should be equal to " + $er['tradeLeg']['tradeForwardPoints']['mantissa'] + ' but Actual is '+$db_res[0]['PX_FWDP_ALLIN'].to_s)
    failOrContinueOnAssert($db_res[0]['PX_FWDP_EXP'],$er['tradeLeg']['tradeForwardPoints']['exponent'],true,"DB FX_TICKET_LEG[PX_SPOT_EXP] should be equal to " + $er['tradeLeg']['tradeForwardPoints']['exponent'] + ' but Actual is '+$db_res[0]['PX_SPOT_EXP'].to_s)
  end

  if $er['securityType']=='FX_SWAP'
    failOrContinueOnAssert($db_res[0]['PX_SWAP_POINTS'],$er['tradeSwapPoints']['mantissa'],true,"DB FX_TICKET_LEG[PX_SWAP_POINTS] should be equal to " + $er['tradeSwapPoints']['mantissa'].to_s+ ' but Actual is '+$db_res[0]['PX_SWAP_POINTS'].to_s)
    failOrContinueOnAssert($db_res[0]['PX_SWAP_POINTS_EXP'],$er['tradeSwapPoints']['exponent'],true,"DB FX_TICKET_LEG[PX_SWAP_POINTS_EXP] should be equal to " + $er['tradeSwapPoints']['exponent'] + ' but Actual is '+$db_res[0]['PX_SWAP_POINTS_EXP'].to_s)
  end

 # ? swap fails failOrContinueOnAssert($db_res[0]['PX_ALLIN'],$er['tradeLeg']['tradePx']['mantissa'],true,"DB FX_TICKET_LEG[PX_ALLIN] should be equal to " + $er['tradeLeg']['tradePx']['mantissa'] + ' but Actual is '+$db_res[0]['PX_ALLIN'].to_s)
  failOrContinueOnAssert($db_res[0]['PX_EXP'],$er['tradeLeg']['tradePx']['exponent'],true,"DB FX_TICKET_LEG[PX_EXP] should be equal to " + $er['tradeLeg']['tradePx']['exponent'] + ' but Actual is '+$db_res[0]['PX_EXP'].to_s)
  failOrContinueOnMatch($er['orderId'],$db_res[0]['EFP_EBS_ORDER_ID'],true,"DB FX_TICKET_LEG[EFP_EBS_ORDER_ID] should be equal to " +$er['orderId'] + ' but Actual is '+$db_res[0]['EFP_EBS_ORDER_ID'].to_s)
  failOrContinueOnMatch($er['clOrdId'],$db_res[0]['EFP_ORDER_ID'],true,"DB FX_TICKET_LEG[EFP_ORDER_ID] should be equal to " +$er['clOrdId'] + ' but Actual is '+$db_res[0]['EFP_ORDER_ID'].to_s)
  #failOrContinueOnMatch($er['executingParty']['floorCode'],$db_res[0]['EFP_FLOOR'],true,"DB FX_TICKET_LEG[EFP_FLOOR] should be equal to " + $er['executingParty']['floorCode']+ ' but Actual is '+$db_res[0]['EFP_FLOOR'].to_s)
  #failOrContinueOnAssert($db_res[0]['EFP_FLOOR_KEY'],$er['executingParty']['floorKey'],true,"DB FX_TICKET_LEG[EFP_FLOOR_KEY] should be equal to " + $er['executingParty']['floorKey']+ ' but Actual is '+$db_res[0]['EFP_FLOOR_KEY'].to_s)
  #failOrContinueOnMatch($er['executingParty']['traderId'],$db_res[0]['EFP_TRADER'],true,"DB FX_TICKET_LEG[EFP_TRADER] should be equal to " + $er['executingParty']['traderId']+ ' but Actual is '+$db_res[0]['EFP_TRADER'].to_s)
  #failOrContinueOnMatch($er['executingParty']['floorKey'],$db_res[0]['EFP_INSTITUTION_KEY'],true,"DB FX_TICKET_LEG[EFP_INSTITUTION_KEY] should be equal to " + $er['executingParty']['floorKey'] + ' but Actual is '+$db_res[0]['EFP_INSTITUTION_KEY'].to_s)
  failOrContinueOnMatch($er['secondaryExecId'],$db_res[0]['EXEC_ID2'],true,"DB FX_TICKET_LEG[ECP_ORDER_ID] should be equal to " +$er['secondaryExecId'] + ' but Actual is '+$db_res[0]['EXEC_ID2'].to_s)
  #failOrContinueOnAssert($db_res[0]['ECP_FLOOR_KEY'],$er['counterParty']['floorKey'],true,"DB FX_TICKET_LEG[ECP_FLOOR_KEY] should be equal to " + $er['counterParty']['floorKey']+ ' but Actual is '+$db_res[0]['ECP_FLOOR_KEY'].to_s)
  #failOrContinueOnMatch($er['counterParty']['traderId'],$db_res[0]['ECP_TRADER'],true,"DB FX_TICKET_LEG[ECP_TRADER] should be equal to " + $er['counterParty']['traderId'].to_s + ' but Actual is '+$db_res[0]['ECP_TRADER'].to_s)





end





def failOrContinueOnAssert(str1,str2,fail,fail_details) # if fail = true ->the test/scenario will fail,otherwise will log the error
   fail(fail_details) if(str1.to_s!=str2.to_s && fail) #&& !fail_details.empty?
   @@scenario_fails.push(fail_details) if(!fail)

   puts '<br>' + ' ASSERTED - ' + fail_details + '<br>'
end

def failOrContinueOnMatch(str1,str2,fail,fail_details) # if fail = true ->the test/scenario will fail,otherwise will log the error
  fail(fail_details) if((!str1.to_s.include?(str2.to_s) || str1.nil? ||str2.nil?) && fail) #&& !fail_details.empty? #!str1.to_s.include?(str2.to_s)
  @@scenario_fails.push(fail_details) if(!fail)

  puts '<br>' + ' ASSERTED - ' + fail_details.to_s + '<br>'
end