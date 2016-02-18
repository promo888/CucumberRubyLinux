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

#user in entry_type and exit_type
BUY_ENTRY = 1
BUY_EXIT = 2
SELL_ENTRY =3
SELL_EXIT = 4


Given /^Code Tested$/  do

  #Actions.checkRtnsDelievery(Dir.getwd + '/templates/old_app_rtns/pts_tidy_3.log', CONFIG.get['CORE_HOST_USER1'])
  #Actions.checkRtnsDelievery(Dir.getwd + '/templates/new_app_rtns/pts_tidy_3.log', CONFIG.get['CORE_HOST_USER'])

  #log_file_path1=Dir.getwd + '/templates/old_app_rtns/pts_tidy_3.log'
  #log_file_path2=Dir.getwd + '/templates/new_app_rtns/pts_tidy_3.log'
  #Actions.compareOutgoingRtns(log_file_path1,log_file_path2)

=begin
  steps %Q{
    Then Old and New versions Traiana outgoing data compared as CSV
  }
=end

  file_path=Dir.getwd+"/logs/USD000UTSTOM_160101_160214.txt"
  source_hash = Actions.getHashMapFromCsvFile(file_path)

  single_avg_signals={'bar_index'=>0,'above_avg'=>false,'below_avg'=>false,'open'=>0,'high'=>0,'low'=>0,'close'=>0}
  trade_indicator={'bar_index_entry'=>0,'entry_type'=>0,'entry_price'=>0,'exit_type'=>0,'exit_price'=>0,'bar_index_entry'=>0,'entry_max_profit'=>0,'entry_max_loss'=>0}


  avg_bars_period = 3 #ToDo ts for MinMax avg bar
  i=0 #starting bar
  avg_indicators=[]
  #ToDo add MinMaxFromOpen
   bar_indicator={'bar_index'=>0,'avg_close_price'=>0,'avg_high_price'=>0,'avg_low_price'=>0,'highlow_percent_from_close'=>0,'nextbar_percent_from_low'=>0,'nextbar_percent_from_low'=>0,'open'=>0,'high'=>0,'low'=>0,'close'=>0}
   source_hash.each_with_index { |bar,index|
   i=index+avg_bars_period # -1 for starting from 0 , to count deals next period =+1 onRule?
   break if(i>source_hash.length)

   highlow_percent_from_close_arr=0 #[] #ToDo to continue with next indicator + ToDo trades with nextDay
   avg_close_price=0
   avg_high_price=0 #from close-1
   avg_low_price=0 #from close-1
   for j in index..i #b/c starting from 0 for OPEN,Starting from 1 when CLOSE
     #next if j==0 #To calculate previous close
     break if index+avg_bars_period+3>source_hash.length #for entry on 2 second positive close after signal
     if j==0  # to calculate previous Avg
       j=1
       next
     end
     #current_bar_indicator = bar_indicator #ToDo change open with close
     highlow_percent_from_close = (source_hash[j][HIGH_FIELD].to_f-source_hash[j][LOW_FIELD].to_f)/source_hash[j-1][CLOSE_FIELD].to_f*100
     highlow_percent_from_close_arr=highlow_percent_from_close_arr+highlow_percent_from_close
     avg_close_price = avg_close_price+source_hash[j][CLOSE_FIELD].to_f
     avg_high_price = avg_high_price+source_hash[j][HIGH_FIELD].to_f
     avg_low_price = avg_low_price+source_hash[j][LOW_FIELD].to_f
     if j==i
      current_bar_avg=nil
      avg_period_indicator={'period_last_bar_index'=>0,'period_avg_highlow_percent_from_close'=>0,'period_avg_decline_percent'=>0, 'period_avg_advance_percent'=>0}
      current_bar_avg = avg_period_indicator
      current_bar_avg['period_last_bar_index'] = j
      current_bar_avg['period_avg_highlow_percent_from_close'] = (highlow_percent_from_close_arr/avg_bars_period).to_f.round(2)
      current_bar_avg['avg_close_price'] = (avg_close_price/avg_bars_period).to_f.round(2)
      current_bar_avg['avg_high_price'] = (avg_high_price/avg_bars_period).to_f.round(2)
      current_bar_avg['avg_low_price'] = (avg_low_price/avg_bars_period).to_f.round(2)
      current_bar_avg['open'] = source_hash[j][OPEN_FIELD].to_f
      current_bar_avg['high'] = source_hash[j][HIGH_FIELD].to_f
      current_bar_avg['low'] = source_hash[j][LOW_FIELD].to_f
      current_bar_avg['close'] = source_hash[j][CLOSE_FIELD].to_f



      avg_indicators.push current_bar_avg
     end

     #signal entry above/below avg after 1and2nd bar close in signal direction

     if(j+2+1<=source_hash.length && j>2+1+avg_bars_period)
       current_close=avg_indicators.select{|elem| elem['period_last_bar_index']==j}
       next_bar_close=avg_indicators.select{|elem| elem['period_last_bar_index']==j+1}
       next_next_bar_close=avg_indicators.select{|elem| elem['period_last_bar_index']==j+2}

       #single_avg_signals={'bar_index'=>0,'percent_above_avg'=>false,'_percent_below_avg'=>false,'open'=>0,'high'=>0,'low'=>0,'close'=>0}
       current_signal={}
       #LongEntry
       if current_close['close']>current_close['avg_close_price'] && next_bar_close['close']>current_close['close'] && next_next_bar_close['close']>next_bar_close['close']
         current_signal['bar_index'] = source_hash[j]['bar_index']
             current_signal['open'] = source_hash[j]['open']
                 current_signal['high'] = source_hash[j]['high']
                     current_signal['low'] = source_hash[j]['low']
                         current_signal['percent_above_avg'] = source_hash[j]['close']
                             current_signal['points_above_avg'] = source_hash[j]['bar_index']
                                 current_signal['percent_below_avg'] = source_hash[j]['bar_index']
                                     current_signal['points_below_avg'] = source_hash[j]['bar_index']
                                         current_signal['avg_period'] = source_hash[j]['bar_index']
                                             current_signal['avg_value'] = source_hash[j]['bar_index']
       end

       #ShortEntry
       if current_close['close']<current_close['avg_close_price'] && next_bar_close['close']<current_close['close'] && next_next_bar_close['close']<next_bar_close['close']

       end


     end


   end
  }

  avg_high_low_max=0
  avg_high_low_min=0
  avg_of_high_low_avg=0
  avg_median=0
  avg_indicators.each{|avg|
    avg_high_low_max=avg['period_avg_highlow_percent_from_close'] if avg_high_low_max==0
    avg_high_low_min=avg['period_avg_highlow_percent_from_close'] if avg_high_low_min==0


    avg_high_low_max=avg['period_avg_highlow_percent_from_close'] if avg['period_avg_highlow_percent_from_close']>avg_high_low_max
    avg_high_low_min=avg['period_avg_highlow_percent_from_close'] if avg['period_avg_highlow_percent_from_close']<avg_high_low_min

    avg_of_high_low_avg=avg_of_high_low_avg+avg_high_low_min=avg['period_avg_highlow_percent_from_close']
  }
  avg_of_high_low_avg=(avg_of_high_low_avg/avg_indicators.length).to_f.round(2)
  avg_high_low_max=avg_high_low_max.to_f.round(2)
  avg_high_low_min=avg_high_low_min.to_f.round(2)

  puts 'AvgPeriod - '+avg_bars_period.to_s+ ', MinHighLowAvg - '+avg_high_low_min.to_s+'%, MaxHighLowAvg - '+avg_high_low_max.to_s+'%, AvgOfHighLowAvg - ' + avg_of_high_low_avg.to_s+'% '





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

  #bars_array

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

