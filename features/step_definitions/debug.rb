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

#Constants
#Bar Fields
OPEN_FIELD = "<OPEN>" #1
HIGH_FIELD = "<HIGH>" #2
LOW_FIELD = "<LOW>" #3
CLOSE_FIELD = "<CLOSE>" #4
VOLUME_FIELD = "<VOLUME>" #5
DATE_FIELD = "<DATE>" #5

#user in entry_type and exit_type
BUY_ENTRY = 1
BUY_EXIT = 2
SELL_ENTRY =3
SELL_EXIT = 4

#Strat Params
BREAKOUT_MULTIPLIER = 2
$avg_period = 10

#ToDo maxLoss,AvgLoss MaxConsecutive PL,display date + test bars + param start stats
#fx from finam not to revert - dja from wsj should be reverted
###############Test Scenarios
=begin

1.Even if 70/30 of Profit trades in order to benefit from Martinale 80/20 drawdowns should be no more than (Drawdown = Profit * 2)
  Following from Distribution that 6-70% of price distributions are in range +- 0.3% ...
  Given Entry on +-0.3% gives 0.2-0.3% profit - Drawdown should be no less then Entry(price-+percent_indicator_entry) Drawdown = Entry - percent_indicator_entry * 2
  In such way each loss will be covered by Martingale next deal

  if we have 3 fail sequnces with 3 trades each where loss = profit * 3 then in order to cover the loss we should reinvest as follows :
  Lets assume that 1% max loss (10 percent with leverage = 100% - 300% loss = 3*3*3 = 27)
  27-35 times Multiplier on Worst Case Sequence i.e. = in order to cover losses from 1000$ trades we should invest 30000$






=end


Given /^Code Tested$/  do
#TODO merge Profits  & Losses + display Entries/Exits on the Graph
=begin
  a = [12,3,4,5,123,4,5,6,7,7,7,7,8,8,8,5,66]
  a.sort!
  elements = a.count
  center =  elements/2
  median = elements.even? ? (a[center] + a[center+1])/2 : a[center]
=end

=begin
  array = [
      {:price => 1, :count => 3},
      {:price => 2, :count => 3},
      {:price => 3, :count => 3},
  ]
  array.map{|x| x[:price]}
=end

  #USD000000TOD_160101_160214.txt EURUSD000TOM_050101_160214_1.txt /DjaHistoricalPrices2000-2016.csv
  file_name = 'DjaHistoricalPrices2000-2016.csv'
  readCsvFile(Dir.getwd+"/logs/"+file_name)#USD000UTSTOM_160101_160214.txt USD000UTSTOM_050101_160214_1.txt
  #calculateBarsSpread($avg_period,0)
  #getAvgChannelBreakoutProfitLoss

  #TODO reverse if lastDate > firstDate
  $source_hash.reverse! if file_name.include?('Dj') #TEMP for DJIA#################################################
  begin
    getPercentChannelBreakoutProfitLoss(0.7,0,0.2) #TODO for now is limited till 1%; usd/rub - 0.555,0,0.5 ; #0.8,1,0.5 8/2  8/3 7/3 7/2 #eurusd - 0.222 -[0.555] -{0.22/0.33} 0.333,0,0.33
  rescue Exception=>e
    puts 'Exception: ' +  e.message if !e.nil? && !e.message.to_s.empty?
    puts 'Backtrace: ' +  e.backtrace.to_s if !e.nil?
  end


end



$source_hash=nil
def readCsvFile(file_path)
  $source_hash = Actions.getHashMapFromCsvFile(file_path)
end

#single_avg_signals={'bar_index'=>0,'above_avg'=>false,'below_avg'=>false,'open'=>0,'high'=>0,'low'=>0,'close'=>0}
trade_indicator={'bar_index_entry' => 0, 'entry_type' => 0, 'entry_price' => 0, 'exit_type' => 0, 'exit_price' => 0, 'bar_index_entry' => 0, 'entry_max_profit' => 0, 'entry_max_loss' => 0}

def calculateBarsSpread(avg_bars_period,start_bar) #ToDo ts for MinMax avg bar
  $avg_indicators=[]
  #ToDo add MinMaxFromOpen
  bar_indicator={'bar_index' => 0, 'avg_close_price' => 0, 'avg_high_price' => 0, 'avg_low_price' => 0, 'highlow_percent_from_close' => 0, 'nextbar_percent_from_high' => 0, 'nextbar_percent_from_low' => 0, 'open' => 0, 'high' => 0, 'low' => 0, 'close' => 0}
  $source_hash.each_with_index { |bar, index|
    start_bar=index+avg_bars_period # -1 for starting from 0 , to count deals next period =+1 onRule?
    break if (start_bar>$source_hash.length)

    highlow_percent_from_close_arr=0 #[] #ToDo to continue with next indicator + ToDo trades with nextDay
    avg_close_price=0
    avg_high_price=0 #from close-1
    avg_low_price=0 #from close-1
    period_high_percent_from_close = 0
    period_low_percent_from_close = 10000000
    for j in index..start_bar #b/c starting from 0 for OPEN,Starting from 1 when CLOSE
      #next if j==0 #To calculate previous close
      break if index+avg_bars_period+3>$source_hash.length #for entry on 2 second positive close after signal
      if j==0 # to calculate previous Avg
        j=1
        next
      end
      #current_bar_indicator = bar_indicator #ToDo change open with close
      highlow_percent_from_close = ($source_hash[j][HIGH_FIELD].to_f-$source_hash[j][LOW_FIELD].to_f)/$source_hash[j-1][CLOSE_FIELD].to_f*100
      highlow_percent_from_close_arr=highlow_percent_from_close_arr+highlow_percent_from_close
      avg_close_price = avg_close_price+$source_hash[j][CLOSE_FIELD].to_f
      avg_high_price = avg_high_price+$source_hash[j][HIGH_FIELD].to_f
      avg_low_price = avg_low_price+$source_hash[j][LOW_FIELD].to_f

      period_high_percent_from_close = 0
      highlow_percent_from_close > period_high_percent_from_close ? period_high_percent_from_close = highlow_percent_from_close  : period_high_percent_from_close
      if j==start_bar
        current_bar_avg=nil
        avg_period_indicator={'period_last_bar_index' => 'NA', 'period_avg_highlow_percent_from_close' => 'NA', 'period_high_percent_from_close' => 'NA', 'period_low_percent_from_close' => 'NA'}
        current_bar_avg = avg_period_indicator
        current_bar_avg['period_last_bar_index'] = j
        current_bar_avg['period_avg_highlow_percent_from_close'] = (highlow_percent_from_close_arr/avg_bars_period).to_f.round(2)
        current_bar_avg['avg_close_price'] = (avg_close_price/avg_bars_period).to_f.round(2)
        current_bar_avg['avg_high_price'] = (avg_high_price/avg_bars_period).to_f.round(2)
        current_bar_avg['avg_low_price'] = (avg_low_price/avg_bars_period).to_f.round(2)
        current_bar_avg['open'] = $source_hash[j][OPEN_FIELD].to_f
        current_bar_avg['high'] = $source_hash[j][HIGH_FIELD].to_f
        current_bar_avg['low'] = $source_hash[j][LOW_FIELD].to_f
        current_bar_avg['close'] = $source_hash[j][CLOSE_FIELD].to_f
        current_bar_avg['max_period_volatile_percent_from_close'] = period_high_percent_from_close


        $avg_indicators.push current_bar_avg
        #addSignalForCrossMa1(index, $source_hash, avg_bars_period)
      end


    end
  }

  avg_high_low_max=0
  avg_high_low_min=0
  avg_of_high_low_avg=0
  maxNextBarVolatilityFromClose = 0
  avg_median=0
  $avg_indicators.each { |avg|
    avg_high_low_max=avg['period_avg_highlow_percent_from_close'] if avg_high_low_max==0
    avg_high_low_min=avg['period_avg_highlow_percent_from_close'] if avg_high_low_min==0


    avg_high_low_max=avg['period_avg_highlow_percent_from_close'] if avg['period_avg_highlow_percent_from_close']>avg_high_low_max
    avg_high_low_min=avg['period_avg_highlow_percent_from_close'] if avg['period_avg_highlow_percent_from_close']<avg_high_low_min

    avg_of_high_low_avg=avg_of_high_low_avg+avg_high_low_min=avg['period_avg_highlow_percent_from_close']
    #maxNextBarVolatilityFromClose = avg['max_period_volatile_percent_from_close'] if avg['max_period_volatile_percent_from_close']>0
  }
  avg_of_high_low_avg=(avg_of_high_low_avg/$avg_indicators.length).to_f.round(2)
  avg_high_low_max=avg_high_low_max.to_f.round(2)
  avg_high_low_min=avg_high_low_min.to_f.round(2)

  puts 'AvgPeriod - '+avg_bars_period.to_s+ ', Total MinHighLowAvg - '+avg_high_low_min.to_s+'%, MaxHighLowAvg - '+avg_high_low_max.to_s+'%, AvgOfHighLowAvg - ' + avg_of_high_low_avg.to_s+'% '#', MaxNextBarVolatilityFromClose - ' + maxNextBarVolatilityFromClose.to_f.round(2).to_s + '%'
end

#ToDo - till EoD,EoW,EoM for IntraWeekMonthDay trading
#will enter trade intraday on 2 DOUBLE channel breakout of Avg HighLow Spread
$channel_breakout_indicator={'bar_index'=>'NA','Direction'=>'NA','PriceEntry'=>'NA','PL_next_N_bars'=>1,'up_to_next_N_bars_max_profit_percent'=>'NA','up_to_next_N_bars_max_loss_percent'=>'NA','up_to_next_N_bars_min_profit_percent'=>'NA','up_to_next_N_bars_min_loss_percent'=>'NA','maxHighLowAvgPercent'=>'NA'}
$channel_breakout_indicators_arr=[]
$long_trades_count=0
$short_trades_count=0
def getAvgChannelBreakoutProfitLoss


  $avg_indicators.each_with_index { |bar,index|
    next if index==0
    current_bar = bar
    #period_avg_highlow_percent_from_close ? toImplement ?
    breakout_percent_multiplier = current_bar['max_period_volatile_percent_from_close'].to_f*BREAKOUT_MULTIPLIER #< 1 ? current_bar['avg_high_price']*2+1 : current_bar['avg_high_price']*2
    breakout_long_price = $avg_indicators[index-1]['close'] + $avg_indicators[index-1]['close'].to_f * breakout_percent_multiplier/100
    breakout_short_price = $avg_indicators[index-1]['close'] - $avg_indicators[index-1]['close'].to_f * breakout_percent_multiplier/100
    entry_price = nil
    entry_direction = nil

    current_signal = {} #$channel_breakout_indicator
    if (bar['high'] > breakout_long_price && bar['low'] < breakout_short_price)
      current_signal['Direction'] = 'BI_DIRECTIONAL_BREAKOUT'
      current_signal['maxHighLowAvgPercent'] = current_bar['avg_high_price']
      $channel_breakout_indicators_arr.push current_signal
      puts 'Bi-Directional Breakout for bar_index - ' + current_signal['bar_index']
    next
    end


    long_signal_exist=true
    !$channel_breakout_indicators_arr.to_a.empty? && $channel_breakout_indicators_arr.last['bar_index'].to_i+$avg_period<index ? long_signal_exist=false : long_signal_exist=true
    long_signal_exist = false if $channel_breakout_indicators_arr.to_a.empty?
    if(bar['high'] > breakout_long_price && !long_signal_exist)
      $long_trades_count+=1
      entry_direction = 'Long'
      current_signal['bar_index'] = index
      current_signal['Direction'] = entry_direction
      current_signal['PriceEntry'] = breakout_long_price
      next_bars_to_check = 1
      index+$avg_period <= $avg_indicators.length ? next_bars_to_check = $avg_period : next_bars_to_check = $avg_indicators.length-index
      current_signal['PL_next_N_bars'] = next_bars_to_check
      min = getMinMaxPrice($avg_indicators.slice(index,next_bars_to_check))['min'] #.to_f.round(2)
      max = getMinMaxPrice($avg_indicators.slice(index,next_bars_to_check))['max'] #.to_f.round(2)

      #if current_signal['Direction'].to_s.downcase='long'
        profit = ((max/current_signal['PriceEntry'].to_f)-1)*100
        loss = ((min/current_signal['PriceEntry'].to_f)-1)*100
        current_signal['up_to_next_N_bars_max_profit_percent'] = profit
        current_signal['up_to_next_N_bars_max_loss_percent'] = loss
      #end

      $channel_breakout_indicators_arr.push current_signal
      #next



    end


    short_signal_exist=true
    !$channel_breakout_indicators_arr.to_a.empty? && $channel_breakout_indicators_arr.last['bar_index'].to_i+$avg_period<index ? short_signal_exist=false : short_signal_exist=true
    short_signal_exist = false if $channel_breakout_indicators_arr.to_a.empty?
    if(bar['low'] < breakout_short_price && !short_signal_exist)
      $short_trades_count+=1
      entry_direction = 'Short'
      current_signal['bar_index'] = index
      current_signal['Direction'] = entry_direction
      current_signal['PriceEntry'] = breakout_short_price
      next_bars_to_check = 1
      index+$avg_period <= $avg_indicators.length ? next_bars_to_check = $avg_period : next_bars_to_check = $avg_indicators.length-index
      current_signal['PL_next_N_bars'] = next_bars_to_check
      min = getMinMaxPrice($avg_indicators.slice(index,next_bars_to_check))['min']#.to_f.round(2)
      max = getMinMaxPrice($avg_indicators.slice(index,next_bars_to_check))['max']#.to_f.round(2)


      #if current_signal['Direction'].to_s.downcase='short'
      profit = ((current_signal['PriceEntry'].to_f/min)-1)*100
      loss = ((current_signal['PriceEntry'].to_f/max)-1)*100
      current_signal['up_to_next_N_bars_max_profit_percent'] = profit
      current_signal['up_to_next_N_bars_max_loss_percent'] = loss
      #end

      $channel_breakout_indicators_arr.push current_signal
      #next

    end


  }

  total_breakout_profit_percent = 0
  total_breakout_loss_percent = 0
  max_breakout_profit_percent = 0
  max_breakout_loss_percent  =  100000000 #ToDo
  avg_breakout_profit_percent = 0
  avg_breakout_loss_percent = 0 #ToDo
  $channel_breakout_indicators_arr.each { |signal|
    total_breakout_profit_percent = total_breakout_profit_percent+signal['up_to_next_N_bars_max_profit_percent']
    total_breakout_loss_percent = total_breakout_loss_percent+signal['up_to_next_N_bars_max_loss_percent']
    signal['up_to_next_N_bars_max_profit_percent'].to_f > max_breakout_profit_percent  ? max_breakout_profit_percent=signal['up_to_next_N_bars_max_profit_percent'].to_f : max_breakout_profit_percent
    signal['up_to_next_N_bars_max_loss_percent'].to_f < max_breakout_loss_percent  ? max_breakout_loss_percent=signal['up_to_next_N_bars_max_loss_percent'].to_f : max_breakout_loss_percent
  }

 if ($channel_breakout_indicators_arr.length > 0 )
  avg_breakout_profit_percent = (total_breakout_profit_percent/$channel_breakout_indicators_arr.length).to_f.round(2)
  avg_breakout_loss_percent = (total_breakout_loss_percent/$channel_breakout_indicators_arr.length).to_f.round(2)
  puts ' total_profit_percent - ' + total_breakout_profit_percent.round(2).to_s + '% , total_loss_percent - ' + total_breakout_loss_percent.round(2).to_s+'%'
  puts ' avg_breakout_profit_percent - ' + avg_breakout_profit_percent.round(2).to_s + '% , max_breakout_profit_percent - ' + max_breakout_profit_percent.round(2).to_s+'%'
  puts ' avg_breakout_loss_percent - ' + avg_breakout_loss_percent.round(2).to_s + '% , max_breakout_loss_percent - ' + max_breakout_loss_percent.round(2).to_s+'%'
  puts ' long_trades_count: ' + $long_trades_count.to_s + ', short_trades_count: ' + $short_trades_count.to_s


  puts "Profit/Loss Between Breakout signals"
  swing_profit=0 #%
  swing_loss=0 #%
  period_total_profit = 0 #%
  period_total_loss = 0 #%
  $channel_breakout_indicators_arr.each_with_index{ |entry,index|
     next if $channel_breakout_indicators_arr[index+1].nil?
     entry_price = entry['PriceEntry']
     entry_index = entry['bar_index']
     entry_direction = entry['Direction']
     exit_price = $channel_breakout_indicators_arr[index+1]['PriceEntry']
     exit_index = $channel_breakout_indicators_arr[index+1]['bar_index']

     period_min = getMinMaxPrice($avg_indicators.slice(entry_index,exit_index))['min']
     period_max = getMinMaxPrice($avg_indicators.slice(entry_index,entry_index))['max']
     period_max_profit_percent = 0
     period_max_loss_percent = 0


     entry_profit = 0
     entry_loss = 0
     if entry_direction.to_s.downcase == 'long'
       period_max_profit_percent=(period_max-entry_price)/entry_price*100 if period_max > entry_price
       period_max_loss_percent=(entry_price-period_min)/entry_price*100 if period_min < entry_price
       period_total_profit+=period_max_profit_percent
       period_total_loss+=period_max_loss_percent

       if exit_price.to_f > entry_price.to_f #profit
         entry_profit = (exit_price.to_f - entry_price.to_f) / entry_price.to_f * 100
       else #loss
         entry_loss = (entry_price.to_f-exit_price.to_f) / entry_price.to_f * 100
       end
     else #short
       period_max_profit_percent=(entry_price-period_min)/entry_price*100 if period_min < entry_price
       period_max_loss_percent=(period_max-entry_price)/entry_price*100 if period_max > entry_price
       period_total_profit+=period_max_profit_percent
       period_total_loss+=period_max_loss_percent

       if exit_price.to_f < entry_price.to_f #profit
         entry_profit = (entry_price.to_f-exit_price.to_f) / entry_price.to_f * 100
       else #loss
         entry_loss = (exit_price.to_f-entry_price.to_f) / entry_price.to_f * 100
       end
     end
     swing_profit+=entry_profit
     swing_loss+=entry_loss # negative minus sign  - excluded for loss,hence loss % is positive
     puts 'EntryDirection: '+entry_direction+' EntryIndex: ' + entry_index.to_s  + ' EntryPrice: '+entry_price.round(2).to_s + ' ExitIndex: ' + exit_index.to_s + ' ExitPrice: ' + exit_price.round(2).to_s + ' EntryProfit: ' + entry_profit.round(2).to_s  + '% EntryLoss: ' + entry_loss.round(2).to_s + '%'+ ' PeriodMaxProfit: ' + period_max_profit_percent.round(2).to_s + '% PeriodMaxLoss: '+period_max_profit_percent.round(2).to_s+'%'
  }
  puts 'TotalTrades: ' + $channel_breakout_indicators_arr.length.to_s + ' TotalProfit: ' +swing_profit.round(2).to_s + '% TotalLoss: ' +swing_loss.round(2).to_s+'% '
  puts 'TotalMaxPeriodProfit: ' + period_total_profit.round(2).to_s + '%' + ' TotalMaxPeriodLoss: ' + period_total_loss.round(2).to_s + '%'

 else
   puts 'NO BREAKOUT Signals found'
 end
end




def getPercentChannelBreakoutProfitLoss(percentFromClose,nextBarsPL,percentPL)


###new query code
  #populate % bar changes <TIME> sometimes exist in Daity for Daily data + exist separate in Intraday data
  $source_hash.each_with_index.select {|bar,index|
    next if index == 0
    $source_hash[index]['<CHANGE_PERCENT>'] = (bar['<CLOSE>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f - 1)*100
  }

  #populate change AD distribution #TODO positive_negative profit_loss drawdown distibutions + max consecutive losses
  # 0-9 = 0.1-0.9% #ToDo later 11>1% 322>2% 33>3% 55>5%
  $change_distribution = {'total'=>0,'1'=>0,'2'=>0,'3'=>0,'4'=>0,'5'=>0,'6'=>0,'7'=>0,'8'=>0,'9'=>0,'10'=>0,'11'=>0,'22'=>0,'33'=>0,'55'=>0}
  $change_positive_distribution = {'total'=>0,'1'=>0,'2'=>0,'3'=>0,'4'=>0,'5'=>0,'6'=>0,'7'=>0,'8'=>0,'9'=>0,'10'=>0,'11'=>0,'22'=>0,'33'=>0,'55'=>0}
  $change_negative_distribution = {'total'=>0,'1'=>0,'2'=>0,'3'=>0,'4'=>0,'5'=>0,'6'=>0,'7'=>0,'8'=>0,'9'=>0,'10'=>0,'11'=>0,'22'=>0,'33'=>0,'55'=>0}
  $source_hash.each_with_index.select {|bar,index|
    next if index == 0
    change = $source_hash[index]['<CHANGE_PERCENT>'].to_f > 0 ? $source_hash[index]['<CHANGE_PERCENT>'].to_f : $source_hash[index]['<CHANGE_PERCENT>'].to_f * -1
    case
      when change <= 0.1 && change > 0
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['1'] = $change_distribution['1'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['1'] = $change_positive_distribution['1'].to_i+1

      when change >= -0.1 && change <= 0
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['1'] = $change_distribution['1'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['1'] = $change_negative_distribution['1'].to_i+1

      when change <= 0.2 && change > 0.1
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['2'] = $change_distribution['2'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['2'] = $change_positive_distribution['2'].to_i+1

      when change >= -0.2 && change <= -0.1
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['2'] = $change_distribution['2'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['2'] = $change_negative_distribution['2'].to_i+1

      when change <= 0.3 && change > 0.2
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['3'] = $change_distribution['3'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['3'] = $change_positive_distribution['3'].to_i+1

      when change >= -0.3 && change <= -0.2
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['3'] = $change_distribution['3'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['3'] = $change_negative_distribution['3'].to_i+1

      when change <= 0.4 && change > 0.3
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['4'] = $change_distribution['4'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['4'] = $change_positive_distribution['4'].to_i+1

      when change >= -0.4 && change <= -0.3
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['4'] = $change_distribution['4'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['4'] = $change_negative_distribution['4'].to_i+1

      when change <= 0.5 && change > 0.4
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['5'] = $change_distribution['5'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['5'] = $change_positive_distribution['5'].to_i+1

      when change >= -0.5 && change <= -0.4
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['5'] = $change_distribution['5'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['5'] = $change_negative_distribution['5'].to_i+1

      when change <= 0.6 && change > 0.5
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['6'] = $change_distribution['6'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['6'] = $change_positive_distribution['6'].to_i+1

      when change >= -0.6 && change <= -0.5
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['6'] = $change_distribution['6'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['6'] = $change_negative_distribution['6'].to_i+1


      when change <= 0.7 && change > 0.6
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['7'] = $change_distribution['7'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['7'] = $change_positive_distribution['7'].to_i+1

      when change >= -0.7 && change <= -0.6
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['7'] = $change_distribution['7'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['7'] = $change_negative_distribution['7'].to_i+1

      when change <= 0.8 && change > 0.7
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['8'] = $change_distribution['8'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['8'] = $change_positive_distribution['8'].to_i+1

      when change >= -0.8 && change <= -0.7
        $change_distribution['total'] = $change_distribution['total'].to_i+=1
        $change_distribution['8'] = $change_distribution['7'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['8'] = $change_negative_distribution['8'].to_i+1

      when change <= 0.9 && change > 0.8
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['9'] = $change_distribution['9'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['9'] = $change_positive_distribution['9'].to_i+1

      when change >= -0.9 && change <= -0.8
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['9'] = $change_distribution['9'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['9'] = $change_negative_distribution['9'].to_i+1

      when change <= 1 && change > 0.9
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['10'] = $change_distribution['10'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['10'] = $change_positive_distribution['10'].to_i+1

      when change >= -1 && change <= -0.9
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['10'] = $change_distribution['10'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['10'] = $change_negative_distribution['10'].to_i+1

      when change <= 2 && change > 1
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['11'] = $change_distribution['11'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['11'] = $change_positive_distribution['11'].to_i+1

      when change >= -2 && change <= -1
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['11'] = $change_distribution['11'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['11'] = $change_negative_distribution['11'].to_i+1

      when change <= 3 && change > 2
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['22'] = $change_distribution['22'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['22'] = $change_positive_distribution['22'].to_i+1

      when change >= -3 && change <= -2
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['22'] = $change_distribution['22'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['22'] = $change_negative_distribution['22'].to_i+1

      when change <= 5 && change > 3
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['33'] = $change_distribution['33'].to_i+1
        $change_positive_distribution['total'] = $change_positive_distribution['total'].to_i+1
        $change_positive_distribution['33'] = $change_positive_distribution['33'].to_i+1

      when change >= -5 && change <= -3
        $change_distribution['total'] = $change_distribution['total'].to_i+1
        $change_distribution['33'] = $change_distribution['33'].to_i+1
        $change_negative_distribution['total'] = $change_negative_distribution['total'].to_i+1
        $change_negative_distribution['33'] = $change_negative_distribution['33'].to_i+1

    end



  }

  $select=[]

  #select breakout signals
  breakout_signals = $source_hash.each_with_index.select {|bar,index| index != 0 && \
                    ( (bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 >= percentFromClose  \
                    || ($source_hash[index-1]['<CLOSE>'].to_f / bar['<LOW>'].to_f - 1)*100 >= percentFromClose )}
  $select.push '=====breakout_signals: ' + breakout_signals.length.to_s

  #select profit trades #TODO to think about sequence HL and StopLoss B/C volatility
  profit_trades = $source_hash.each_with_index.select {|bar,index| index != 0 && \
                        ( (bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 >= percentFromClose+percentPL \
                     || ($source_hash[index-1]['<CLOSE>'].to_f / bar['<LOW>'].to_f - 1)*100 >= percentFromClose+percentPL )}
  $select.push '=====profit_trades: ' + profit_trades.length.to_s
  profit_trades.each{|bar|  $select.push('[' + bar[0][DATE_FIELD].to_s + ']') }

  #select loss trades
  loss_trades = $source_hash.each_with_index.select {|bar,index| index != 0 && \
                         ((bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 >= percentFromClose && \
                          (bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 <= percentFromClose+percentPL && \
                          $source_hash[index]['<CLOSE>'].to_f < $source_hash[index]['<CLOSE>'].to_f*(1+percentFromClose)) \
  || (($source_hash[index-1]['<CLOSE>'].to_f / bar['<LOW>'].to_f - 1)*100 >= percentFromClose && \
      ($source_hash[index-1]['<CLOSE>'].to_f / bar['<LOW>'].to_f - 1)*100 <= percentFromClose+percentPL && \
       $source_hash[index]['<CLOSE>'].to_f > $source_hash[index-1]['<CLOSE>'].to_f*(1-percentFromClose))
  }
  $select.push '=====loss_trades: ' + loss_trades.length.to_s
  loss_trades.each{|bar| $select.push('[' + bar[0][DATE_FIELD].to_s + ']')}


  #select profit trades on bar close - exit on close if TP percent PL unmet
  profit_trades_with_close = $source_hash.each_with_index.select {|bar,index| index != 0 && \
                      ( (bar['<CLOSE>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 >= percentFromClose \
                     && ( (bar['<CLOSE>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 < percentFromClose+percentPL \
                     || ($source_hash[index-1]['<CLOSE>'].to_f / bar['<CLOSE>'].to_f-1)*100 >= percentFromClose ) \
                     && ($source_hash[index-1]['<CLOSE>'].to_f / bar['<CLOSE>'].to_f-1)*100 < percentFromClose+percentPL)  }
  $select.push '=====profit_trades_with_close when TP unmet: ' + profit_trades_with_close.length.to_s




  #select bi-breakout signals
  bi_breakout_signals = $source_hash.each_with_index.select {|bar,index| index != 0 && \
                         ( (bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 >= percentFromClose  \
                        && ($source_hash[index-1]['<CLOSE>'].to_f / bar['<LOW>'].to_f - 1)*100 >= percentFromClose )}
  $select.push '=====bi_breakout_signals: ' + bi_breakout_signals.length.to_s


  #select bi-profit trades
  bi_profit_trades = $source_hash.each_with_index.select {|bar,index| index != 0 && \
                    ( (bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 >= percentFromClose+percentPL \
                    &&  ($source_hash[index-1]['<CLOSE>'].to_f / bar['<LOW>'].to_f - 1)*100 >= percentFromClose+percentPL )}
  $select.push '=====bi_profit_trades: ' + bi_profit_trades.length.to_s


  #select bi-profit trades with drawdownPL from entry where drawdown=percentPL*2 ?
  bi_profit_drawdown_pl_trades = $source_hash.each_with_index.select {|bar,index| index != 0 && \
                                ( ((bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 >= percentFromClose \
                                && ($source_hash[index-1]['<CLOSE>'].to_f*(1+percentFromClose)/bar['<LOW>'].to_f - 1)*100 >= percentPL*2)) \
                                || (($source_hash[index-1]['<CLOSE>'].to_f / bar['<LOW>'].to_f - 1)*100 >= percentFromClose  \
                                && (bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f*(1-percentFromClose) - 1)*100 >= percentPL*2)}
  $select.push '=====bi_profit_drawdown_pl*2_trades: ' + bi_profit_drawdown_pl_trades.length.to_s


  #select profit trades excluding Bi-Breakout
  breakout_indexes = bi_breakout_signals.collect{|bar| bar[1]}
  profit_trades_excluded_bi_breakouts = []
  profit_trades.each { |bar|
    profit_trades_excluded_bi_breakouts.push bar if !breakout_indexes.include?(bar[1])
  }
  $select.push '=====profit_trades_excluded_bi_breakouts: ' + profit_trades_excluded_bi_breakouts.length.to_s


  #select bi_signals_with_ma_cross when MaCross in Direction of Signal
  crossMa1 = 3
  crossMa2 = 9
  bi_signals_with_ma_cross = $source_hash.each_with_index.select {|bar,index| index != 0 && index>crossMa2 &&
                                ( ((bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 >= percentFromClose &&
                                    #getAvgValue(crossMa1,index-1,$source_hash,'CLOSE').to_f > getAvgValue(crossMa2,index-1,$source_hash,'CLOSE').to_f) \
                                    $source_hash[index-1]['<CLOSE>'].to_f*(1+percentFromClose) > getAvgValue(crossMa1,index-1,$source_hash,'CLOSE').to_f) \
                                || (($source_hash[index-1]['<CLOSE>'].to_f / bar['<LOW>'].to_f - 1)*100 >= percentFromClose &&
                                    # getAvgValue(crossMa1,index-1,$source_hash,'CLOSE').to_f < getAvgValue(crossMa2,index-1,$source_hash,'CLOSE').to_f) )}
                                    $source_hash[index-1]['<CLOSE>'].to_f*(1-percentFromClose) < getAvgValue(crossMa2,index-1,$source_hash,'CLOSE').to_f) )}
  $select.push '=====bi_signals_with_ma_cross: ' + bi_signals_with_ma_cross.length.to_s


  #select bi_profit_trades_with_ma_cross when MaCross in Direction of Signal
  crossMa1 = 3
  crossMa2 = 9
  bi_profit_trades_with_ma_cross = $source_hash.each_with_index.select {|bar,index| index != 0 && index>crossMa2 &&
      ( ((bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 >= percentFromClose &&
          #getAvgValue(crossMa1,index-1,$source_hash,'CLOSE').to_f >  getAvgValue(crossMa2,index-1,$source_hash,'CLOSE').to_f && \
          $source_hash[index-1]['<CLOSE>'].to_f*(1+percentFromClose) > getAvgValue(crossMa1,index-1,$source_hash,'CLOSE').to_f && \
          (bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 >= percentFromClose+percentPL) \
      || (($source_hash[index-1]['<CLOSE>'].to_f / bar['<LOW>'].to_f - 1)*100 >= percentFromClose && \
          #getAvgValue(crossMa1,index-1,$source_hash,'CLOSE').to_f <  getAvgValue(crossMa2,index-1,$source_hash,'CLOSE').to_f && \
          $source_hash[index-1]['<CLOSE>'].to_f*(1-percentFromClose) < getAvgValue(crossMa2,index-1,$source_hash,'CLOSE').to_f && \
          ($source_hash[index-1]['<CLOSE>'].to_f / bar['<LOW>'].to_f - 1)*100 >= percentFromClose+percentPL  ))}
  $select.push '=====bi_profit_trades_with_ma_cross: ' + bi_profit_trades_with_ma_cross.length.to_s


  #TODO - to continue STEP next days + drawdowns + investigate opposit with - loss
  #select Count of MaSingle cross profits # todo losses (HighLows) from crosses

 #d = getMinMaxHighLowPrice2(($source_hash[21,10])['high'].to_f/$source_hash[20]['<CLOSE>'].to_f-1)*100  #>=percentPL
  singleMa = 200
  percentPL = 0.1
  periodPL = 1
  periodPlStep = 2
  bi_profit_signals_with_ma_single = $source_hash.each_with_index.select {|bar,index| index>periodPL  && index+1+periodPL<$source_hash.length-1 &&
      ( ($source_hash[index]['<CLOSE>'].to_f > getAvgValue(singleMa,index-1,$source_hash,'HIGH').to_f && getAvgValue(singleMa,index-1,$source_hash,'HIGH').to_f>0 \
        #  && (getMinMaxHighLowPrice2($source_hash[index+1,periodPL])['max'].to_f/ $source_hash[index]['<CLOSE>'].to_f-1)*100 >=percentPL \
       )  || ($source_hash[index]['<CLOSE>'].to_f < getAvgValue(singleMa,index-1,$source_hash,'LOW').to_f  && getAvgValue(singleMa,index-1,$source_hash,'LOW').to_f>0 \
        #  && (getMinMaxHighLowPrice2($source_hash[index+1,periodPL])['min'].to_f/ $source_hash[index]['<CLOSE>'].to_f-1)*100 >=percentPL \
       )   )}

  $select.push '=====bi_profit_signals_with_ma_single count: ' + bi_profit_signals_with_ma_single.length.to_s + ' ma='+singleMa.to_s #+' with profit ' + percentPL.to_s + '% + LOSS NOT COUNTED'


  bi_profit_trades_with_ma_single = $source_hash.each_with_index.select {|bar,index| index>periodPL  && index+1+periodPL<$source_hash.length-1 &&
       ( ($source_hash[index]['<CLOSE>'].to_f > getAvgValue(singleMa,index-1,$source_hash,'HIGH').to_f && getAvgValue(singleMa,index-1,$source_hash,'HIGH').to_f>0 \
          && (getMinMaxHighLowPrice2($source_hash[index+periodPlStep,periodPL])['max'].to_f/ $source_hash[index]['<CLOSE>'].to_f-1)*100 >=percentPL \
       )  || ($source_hash[index]['<CLOSE>'].to_f < getAvgValue(singleMa,index-1,$source_hash,'LOW').to_f  && getAvgValue(singleMa,index-1,$source_hash,'LOW').to_f>0 \
          && (getMinMaxHighLowPrice2($source_hash[index+periodPlStep,periodPL])['min'].to_f/ $source_hash[index]['<CLOSE>'].to_f-1)*100 >=percentPL \
       )   )}

  $select.push '=====bi_profit_trades_with_ma_single: ' + bi_profit_trades_with_ma_single.length.to_s + ' ma='+singleMa.to_s+' with profit ' + percentPL.to_s + '% + LOSS NOT COUNTED'





  #select 1direction-breakout trades with drawdownPL from CLOSE where drawdown=percentPL
  $source_hash.each_with_index.select {|bar,index|
   index != 0 && ( (bar['<HIGH>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f-1)*100 >= percentFromClose+percentPL &&
        (($source_hash[index-1]['<CLOSE>'].to_f/100)/bar['<LOW>'].to_f - 1)*100 >= percentPL )  ||
        (($source_hash[index-1]['<CLOSE>'].to_f / bar['<LOW>'].to_f - 1)*100 >= percentPL  &&
            (bar['<LOW>'].to_f / $source_hash[index-1]['<CLOSE>'].to_f/100 - 1)*100 >= percentPL )}



  #ToDo Month/Day/Hour/Min profit/loss/volatile distibution
  ###end of new query code

  $same_bar_bi_directional_breakout_count = 0
  $period_bi_directional_ProfitLoss_count = 0
  $same_bar_breakout_profit_count= 0
  $same_bar_total_profit = 0 # Total loss included
  $same_bar_total_drawdown = 0
  $same_bar_total_loss = 0

  $source_hash.each_with_index { |bar,index|
    next if index==0
    break if index+nextBarsPL > $source_hash.length-1
    current_bar = bar
#TODO - to continue
    breakout_long_price = $source_hash[index-1]['<CLOSE>'].to_f * (1+percentFromClose/100)
    breakout_short_price = $source_hash[index-1]['<CLOSE>'].to_f  - ($source_hash[index-1]['<CLOSE>'].to_f * percentFromClose/100)
    entry_price = nil
    entry_direction = nil

    current_signal = {} #$channel_breakout_indicator
    if (bar[HIGH_FIELD].to_f > breakout_long_price && bar[LOW_FIELD].to_f < breakout_short_price)
      current_signal['bar_index'] = index
      current_signal['Direction'] = 'BI_DIRECTIONAL_BREAKOUT - LongEntryFirst' #Since long deals are more frequent we'll execute Long first
      current_signal['maxHighLowAvgPercent'] = current_bar['avg_high_price']
      $channel_breakout_indicators_arr.push current_signal
      puts '===================Bi-Directional Breakout for bar_index - ' + current_signal['bar_index'].to_s
      $same_bar_bi_directional_breakout_count+=1
      #next #TODO to exclude
    end



    long_signal_exist=true
    !$channel_breakout_indicators_arr.to_a.empty? && $channel_breakout_indicators_arr.last['bar_index'].to_i+nextBarsPL<index ? long_signal_exist=false : long_signal_exist=true
    long_signal_exist = false if $channel_breakout_indicators_arr.to_a.empty?
    if(bar[HIGH_FIELD].to_f > breakout_long_price && !long_signal_exist)
      $long_trades_count+=1
      entry_direction = 'Long'
      current_signal['bar_index'] = index
      current_signal['Direction'] = entry_direction
      current_signal['PriceEntry'] = breakout_long_price.to_f
      next_bars_to_check = nextBarsPL+1
      #index+next_bars_to_check <= $avg_indicators.length ? next_bars_to_check = $avg_period : next_bars_to_check = $avg_indicators.length-index
      current_signal['PL_next_N_bars'] = next_bars_to_check
      min = getMinMaxHighLowPrice2($source_hash.slice(index,next_bars_to_check))['min'].to_f #.to_f.round(2)
      max = getMinMaxHighLowPrice2($source_hash.slice(index,next_bars_to_check))['max'].to_f #.to_f.round(2)

      #if current_signal['Direction'].to_s.downcase='long'
      profit = ((max/current_signal['PriceEntry'])-1)*100 #maxProfit  i.e. same bar high
      loss = ((min/current_signal['PriceEntry'])-1)*100
      current_signal['up_to_next_N_bars_max_profit_percent'] = profit
      current_signal['up_to_next_N_bars_max_loss_percent'] = loss
      #end
       if (profit>=percentPL && loss<=-percentPL)
         $period_bi_directional_ProfitLoss_count+=1
         puts '===Period_bi_directional_ProfitLoss_count for bar: '+current_signal['bar_index'].to_s
         $same_bar_breakout_profit_count+=1
         $same_bar_total_profit-=percentPL
         current_signal['Profit'] = -percentPL
         $same_bar_total_loss+=-percentPL
         next
       end

      str_per_profit = ' Profit % for bar: ' + current_signal['bar_index'].to_s + ' is: '
      str_per_drawdown = ', Drawdown % is: '
      if percentPL <= profit
        $same_bar_breakout_profit_count+=1
        $same_bar_total_profit+=percentPL #TakeProfit
        str_per_profit<<percentPL.to_s
        str_per_profit<<str_per_drawdown<<loss.round(2).to_s
        current_signal['Profit'] = percentPL
      else #loss
         if $source_hash[current_signal['bar_index']][LOW_FIELD].to_f <= breakout_short_price # if profit unmet exit on opposite breakout
           $same_bar_total_profit-=percentPL # loss on stop  - same as profit
           str_per_profit<<-percentPL.to_s
           str_per_profit<<str_per_drawdown<<loss.round(2).to_s
           $same_bar_total_loss+=-percentPL #StopLoss
           current_signal['Profit'] = -percentPL
           #TODO Double entry
         else
           res = (current_signal['PriceEntry'].to_f/$source_hash[current_signal['bar_index']][CLOSE_FIELD].to_f-1)*100 #if no stop exit on same close
           $same_bar_total_profit+=res
           str_per_profit<<res.to_s
           str_per_profit<<str_per_drawdown<<loss.round(2).to_s
            if res < 0
              $same_bar_total_loss+=res
              current_signal['Profit'] = res
            end

         end
      end
      $same_bar_total_drawdown+=loss
      puts str_per_profit


      $channel_breakout_indicators_arr.push current_signal
      #next



    end


    short_signal_exist=true
    !$channel_breakout_indicators_arr.to_a.empty? && $channel_breakout_indicators_arr.last['bar_index'].to_i+nextBarsPL<index ? short_signal_exist=false : short_signal_exist=true
    short_signal_exist = false if $channel_breakout_indicators_arr.to_a.empty?
    if(bar[LOW_FIELD].to_f < breakout_short_price && !short_signal_exist)
      $short_trades_count+=1
      entry_direction = 'Short'
      current_signal['bar_index'] = index
      current_signal['Direction'] = entry_direction
      current_signal['PriceEntry'] = breakout_short_price
      next_bars_to_check = nextBarsPL+1
      #index+next_bars_to_check <= $avg_indicators.length ? next_bars_to_check = next_bars_to_check : next_bars_to_check = $avg_indicators.length-index
      current_signal['PL_next_N_bars'] = next_bars_to_check
      min = getMinMaxHighLowPrice2($source_hash.slice(index,next_bars_to_check))['min'].to_f #.to_f.round(2)
      max = getMinMaxHighLowPrice2($source_hash.slice(index,next_bars_to_check))['max'].to_f #.to_f.round(2)

      #Todo refactor from 652 for LongShort

      #if current_signal['Direction'].to_s.downcase='short'
      profit = ((current_signal['PriceEntry'].to_f/min)-1)*100
      loss = ((current_signal['PriceEntry'].to_f/max)-1)*100
      current_signal['up_to_next_N_bars_max_profit_percent'] = profit
      current_signal['up_to_next_N_bars_max_loss_percent'] = loss
      #end


      if (profit>=percentPL && loss<=-percentPL)
        $period_bi_directional_ProfitLoss_count+=1
        puts '===Period_bi_directional_ProfitLoss_count for bar: '+current_signal['bar_index'].to_s
        $same_bar_breakout_profit_count+=1 #ToDo refactor+remove duplicate
        $same_bar_total_profit-=percentPL
        current_signal['Profit'] = -percentPL
        $same_bar_total_loss+=-percentPL
        next
      end

      str_per_profit = ' Profit % for bar: ' + current_signal['bar_index'].to_s + ' is: '
      str_per_drawdown = ', Drawdown % is: '
      if percentPL <= profit
        $same_bar_breakout_profit_count+=1
        $same_bar_total_profit+=percentPL #TakeProfit
        str_per_profit<<percentPL.to_s
        str_per_profit<<str_per_drawdown<<loss.round(2).to_s
        current_signal['Profit'] = percentPL
      else #exit on bar close if Profit unmet
        if $source_hash[current_signal['bar_index']][HIGH_FIELD].to_f >= breakout_long_price # if profit unmet exit on opposite breakout
          $same_bar_total_profit-=percentPL
          str_per_profit<<'-'+percentPL.to_s
          str_per_profit<<str_per_drawdown<<loss.round(2).to_s
          $same_bar_total_loss+=-percentPL #StopLoss
          current_signal['Profit'] = -percentPL
          #TODO Double entry
        else
          res = ($source_hash[current_signal['bar_index']][CLOSE_FIELD].to_f/current_signal['PriceEntry'].to_f-1)*100
          $same_bar_total_profit+=res
          str_per_profit<<res.to_s
          str_per_profit<<str_per_drawdown<<loss.round(2).to_s
          $same_bar_total_loss+=res if res < 0
          current_signal['Profit'] = res
        end
      end
      puts str_per_profit
      $same_bar_total_drawdown+=loss

      $channel_breakout_indicators_arr.push current_signal
      #next

    end


  }


  total_breakout_profit_percent = 0
  total_breakout_loss_percent = 0
  max_breakout_profit_percent = 0
  max_breakout_loss_percent  =  100000000 #ToDo
  avg_breakout_profit_percent = 0
  avg_breakout_loss_percent = 0 #ToDo
  $channel_breakout_indicators_arr.each { |signal|
    total_breakout_profit_percent = total_breakout_profit_percent+signal['up_to_next_N_bars_max_profit_percent'] if !signal['up_to_next_N_bars_max_profit_percent'].nil?
    total_breakout_loss_percent = total_breakout_loss_percent+signal['up_to_next_N_bars_max_loss_percent'] if !signal['up_to_next_N_bars_max_loss_percent'].nil?
    signal['up_to_next_N_bars_max_profit_percent'].to_f > max_breakout_profit_percent  ? max_breakout_profit_percent=signal['up_to_next_N_bars_max_profit_percent'].to_f : max_breakout_profit_percent
    signal['up_to_next_N_bars_max_loss_percent'].to_f < max_breakout_loss_percent  ? max_breakout_loss_percent=signal['up_to_next_N_bars_max_loss_percent'].to_f : max_breakout_loss_percent
  }

  if ($channel_breakout_indicators_arr.length > 0 )
    avg_breakout_profit_percent = (total_breakout_profit_percent/$channel_breakout_indicators_arr.length).to_f.round(2)
    avg_breakout_loss_percent = (total_breakout_loss_percent/$channel_breakout_indicators_arr.length).to_f.round(2)
    puts ' SameBarTotalProfit excl. Loss: '+$same_bar_total_profit.round(2).to_s+'% SameBarTotalDrawDown: '+$same_bar_total_drawdown.round(2).to_s + \
         ' SameBarTotalLoss: '+$same_bar_total_loss.round(2).to_s + \
         '%,Max_total_profit_percent: ' + total_breakout_profit_percent.round(2).to_s + '% , Max_total_loss_percent: ' + total_breakout_loss_percent.round(2).to_s+'% [? precedence HL,hence maybe no loss sometimes]'
    puts ' Avg_breakout_profit_percent: ' + avg_breakout_profit_percent.round(2).to_s + '% , Max_breakout_profit_percent: ' + max_breakout_profit_percent.round(2).to_s+'%'
    puts ' Avg_breakout_loss_percent: ' + avg_breakout_loss_percent.round(2).to_s + '% , Max_breakout_loss_percent: ' + max_breakout_loss_percent.round(2).to_s+'%'
    puts ' Total trades count: '+($long_trades_count+$short_trades_count).to_s+' long_trades_count: ' + $long_trades_count.to_s + ', short_trades_count: ' + $short_trades_count.to_s
    puts ' BiSignal Breakout Amount: ' + $same_bar_bi_directional_breakout_count.to_s + ', in PERIOD_bi_directional_ProfitLoss_count: ' + $period_bi_directional_ProfitLoss_count.to_s + ' [? precedence HL] '
    puts ' '+percentPL.to_s + '% profit in SameBar trades count: ' + $same_bar_breakout_profit_count.to_s

  end


  #select loss trades amount
  $loss_trades_count = 0
  $consecutive_loss_trades_amount = 0
  $max_consecutive_loss_trades_amount = 0
  $total_loss_percent = 0
  loss_trades = $channel_breakout_indicators_arr.each_with_index.select {|bar,index|
     if bar['Profit'].to_f < 0
       $loss_trades_count+=1
       $total_loss_percent+=bar['Profit'].to_f
       if(index>1 && $channel_breakout_indicators_arr[index-1]['bar_index'].to_i+1 == $channel_breakout_indicators_arr[index]['bar_index'].to_i && $channel_breakout_indicators_arr[index-1]['Profit'].to_f < 0)
         $consecutive_loss_trades_amount+=1
         $max_consecutive_loss_trades_amount=$consecutive_loss_trades_amount if $consecutive_loss_trades_amount > $max_consecutive_loss_trades_amount
       else
         $consecutive_loss_trades_amount = 0
       end
     end
  }
  puts ' Loss Trades Count: ' + $loss_trades_count.to_s + ' Loss Trade Avg: ' + ($total_loss_percent/loss_trades.length).to_s
  puts ' Max Loss Consecutive Amount: ' + $max_consecutive_loss_trades_amount.to_s
#loss_trades.select{|bar,index| bar['Profit'].to_f < -0.4 }

  $select.each{|row| puts row}


end



#TODO 80#20 25#75 30#70 35#65



def getMinMaxPrice(bars_array)
  min = 1000000000
  max = 0
  bars_array.each { |bar|
    max=bar['high'] if bar['high'] > max
    min=bar['low'] if bar['low'] < min
  }

  max = nil if max==0
  min = nil if min==1000000000
  return {'min'=> min, 'max'=> max}
end



def getMinMaxHighLowPrice2(bars_array)
  min = 1000000000
  max = 0
  bars_array.each { |bar|
    max=bar[HIGH_FIELD].to_f if bar[HIGH_FIELD].to_f > max
    min=bar[LOW_FIELD].to_f if bar[LOW_FIELD].to_f < min
  }

  max = nil if max==0
  min = nil if min==1000000000
  return {'min'=> min, 'max'=> max}
end


#back testing
# Scenario1: run by [num=3] periods back minStep=[20d] and find Max/Min-1=percent_range[6%]
# IF Found assign to arr
# if NOT FOUND percent_range step back next 20d if currentStepMax > previousStepMax -> max = currentStepMax





$signals_ma1_arr=[]
def addSignalForCrossMa1(current_bar_index,bars_array,avg_period)
  #signal entry above/below avg after 1and2nd bar close in signal direction - entry on close
  if(current_bar_index+1+1<=bars_array.length && current_bar_index>1+1+avg_period) #additional +1 - at least 1/next day exist in order to test profit/loss
    current_close=bars_array.select{|elem| elem['period_last_bar_index']==current_bar_index}
    before_bar_close=bars_array.select{|elem| elem['period_last_bar_index']==current_bar_index-1}
    next_bar_close=bars_array.select{|elem| elem['period_last_bar_index']==current_bar_index+1}

    #single_avg_signals={'bar_index'=>0,'percent_above_avg'=>false,'_percent_below_avg'=>false,'open'=>0,'high'=>0,'low'=>0,'close'=>0}
    current_signal={}
    #LongEntry
    if  current_close['close'].to_f>before_bar_close['avg_close_price'].to_f && next_bar_close['close'].to_f>current_close['close'].to_f
      current_signal['bar_index'].to_f = next_bar_close['bar_index'].to_f
      current_signal['open'].to_f = next_bar_close['open'].to_f
      current_signal['high'].to_f = next_bar_close['high'].to_f
      current_signal['low'].to_f = next_bar_close['low'].to_f

      # current close/above previous day close avg
      current_signal['signal_percent_above_avg'].to_f = (next_bar_close['close'].to_f-before_bar_close['avg_close_price'].to_f/before_bar_close['avg_close_price'].to_f*100).to_f.round(2)
      #ToDo Max ProfitLoss between signal and entry+between entry and exit
      maxProfitPercentTillEntry = 0
      if current_close['high'].to_f>=next_bar_close['high'].to_f
        maxProfitPercentTillEntry=((current_close['high'].to_f-before_bar_close['avg_close_price'].to_f)/before_bar_close['avg_close_price'].to_f*100).to_f.round(2)
      else
        maxProfitPercentTillEntry=((next_bar_close['high'].to_f-before_bar_close['avg_close_price'].to_f)/before_bar_close['avg_close_price'].to_f*100).to_f.round(2)
      end
      current_signal['maxProfitPercentTillEntry'] = maxProfitPercentTillEntry

      maxLossPercentTillEntry = 0
      if current_close['low'].to_f<=next_bar_close['low'].to_f
        maxLossPercentTillEntry=((before_bar_close['avg_close_price'].to_f-current_close['low'].to_f)/before_bar_close['avg_close_price'].to_f*100).to_f.round(2)
      else
        maxLossPercentTillEntry=((before_bar_close['avg_close_price'].to_f-current_close['low'].to_f)/before_bar_close['avg_close_price'].to_f*100).to_f.round(2)
      end
      current_signal['maxLossPercentTillEntry'] = maxLossPercentTillEntry


      current_signal['avg_period'] = avg_period
      current_signal['avg_value'] = before_bar_close['avg_close_price']
      #
    end

    #ShortEntry
    if current_close['close'].to_f<before_bar_close['avg_close_price'].to_f && next_bar_close['close'].to_f<current_close['close'].to_f
      current_signal['bar_index'].to_f = next_bar_close['bar_index'].to_f
      current_signal['open'].to_f = next_bar_close['open'].to_f
      current_signal['high'].to_f = next_bar_close['high'].to_f
      current_signal['low'].to_f = next_bar_close['low'].to_f

      # current close/below previous day close avg
      current_signal['signal_percent_below_avg'] = (before_bar_close['avg_close_price']-next_bar_close['close']/before_bar_close['avg_close_price']*100).to_f.round(2)
      maxProfitPercentTillEntry = 0
      if current_close['low'].to_f<=next_bar_close['low'].to_f
        maxProfitPercentTillEntry=((before_bar_close['avg_close_price'].to_f-current_close['low'].to_f)/before_bar_close['avg_close_price'].to_f*100).to_f.round(2)
      else
        maxProfitPercentTillEntry=((before_bar_close['avg_close_price'].to_f-next_bar_close['low'].to_f)/before_bar_close['avg_close_price'].to_f*100).to_f.round(2)
      end
      current_signal['maxProfitPercentTillEntry'] = maxProfitPercentTillEntry

      maxLossPercentTillEntry = 0 #todo to check if high>avg +above P/L too
      if current_close['high'].to_f>=next_bar_close['high'].to_f
        maxLossPercentTillEntry=((current_close['high'].to_f-before_bar_close['avg_close_price'].to_f)/before_bar_close['avg_close_price'].to_f*100).to_f.round(2)
      else
        maxLossPercentTillEntry=(current_close['high'].to_f-(before_bar_close['avg_close_price'].to_f)/before_bar_close['avg_close_price'].to_f*100).to_f.round(2)
      end
      current_signal['maxLossPercentTillEntry'] = maxLossPercentTillEntry
      current_signal['avg_period'] = avg_period
      current_signal['avg_value'] = before_bar_close['avg_close_price']
      #
    end


    $signals_ma1_arr.push(current_signal)
  end
end



#ToDo to split to return bars array in order to apply on them required indicator
def getMaxSpreadPercentFromBarsBefore(current_bar_index,days_before_amount,bars_array)
   if(current_bar_index-days_before_amount<0 || current_bar_index-days_before_amount>bars_array.length )
    return nil # ERROR + no kindOF?(ARRAY)
   else
     #return cutted bars array - FUTURE FIX

   end

end


def getBarsByIndex(bars_amount,before_bar_index,bars_array)

end

def getBarsByTime(bars_amount,before_bar_date,bars_array)

end


#Indicators
def getAvgValue(bars_period,before_bar_index,bars_array,ohlc_type)
  return nil if before_bar_index-bars_period<1 || bars_array.length-before_bar_index<bars_period+1 || bars_array.nil? || bars_array.to_a.empty? || ohlc_type.nil? || ohlc_type.to_s.empty? || bars_period.to_s.empty? || before_bar_index.to_s.empty?
  ohlc_type_field="PRICE FIELD IS NOT_DEFINED"
  case ohlc_type
    when OPEN_FIELD,OPEN_FIELD.to_s.downcase,"open","OPEN",1
      ohlc_type_field = OPEN_FIELD
    when HIGH_FIELD,HIGH_FIELD.to_s.downcase,"high","HIGH",2
      ohlc_type_field = HIGH_FIELD
    when LOW_FIELD,LOW_FIELD.to_s.downcase,"low","LOW",3
      ohlc_type_field = LOW_FIELD
    when CLOSE_FIELD,CLOSE_FIELD.to_s.downcase,"close","CLOSE",4
      ohlc_type_field = CLOSE_FIELD
    else
      puts "You must setup PRICE FIELD by <OPEN><HIGH><LOW><CLOSE>"
  end

  total = 0
  avg = 0
  avg_arr =  bars_array.each_with_index.select {|bar,index| !bars_array.nil? && before_bar_index < bars_array.length  &&  before_bar_index-bars_period > 0 \
             && index > before_bar_index-bars_period && index <= before_bar_index
  }

  avg_arr.each{|bar|
    total+=bar[0][ohlc_type_field].to_f}
  avg = (total/bars_period).to_f.round(4) if total!=0
  return avg #> 0 ? avg : nil

end




#Trades
def enterIfMaxSpreadAsTwiceOfAvg

end


def orderType(longOrShort) #long,buy -1, short,sell -2

end


def positionType(openOrClose) #open -1,close-2

end

def executeTrade(amount,longOrShort,openOrClose)

end

