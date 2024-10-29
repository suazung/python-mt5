




//  ----------------- when cant connect port ---------------------
// 1. open cmd
// 2. netstat -aon | findstr :5557
// 3. taskkill /PID <process_id> /F



#property strict


#ifdef __MQL4__
string BaseCurrency() { return ( AccountCurrency() ); }
double Point( string symbol ) { return ( MarketInfo( symbol, MODE_POINT ) ); }
double TickSize( string symbol ) { return ( MarketInfo( symbol, MODE_TICKSIZE ) ); }
double TickValue( string symbol ) { return ( MarketInfo( symbol, MODE_TICKVALUE ) ); }
#endif
#ifdef __MQL5__
string BaseCurrency() { return ( AccountInfoString( ACCOUNT_CURRENCY ) ); }
double Point( string symbol ) { return ( SymbolInfoDouble( symbol, SYMBOL_POINT ) ); }
double TickSize( string symbol ) { return ( SymbolInfoDouble( symbol, SYMBOL_TRADE_TICK_SIZE ) ); }
double TickValue( string symbol ) { return ( SymbolInfoDouble( symbol, SYMBOL_TRADE_TICK_VALUE ) ); }
#endif



#include <Trade/Trade.mqh>
#include <Zmq/Zmq.mqh>


int diffTimeSierraChartAndMT5(datetime currentTimeSierraChart  ) ;




input group           "--------- General Input---------"   
input double Lot = 0.1;
input double thisBalance = 100000 ;
input double percentToRisk = 0.8 ;
input string symbol = "GBPUSD" ;

input group           "--------- News Input ---------"
input string currencyPair1 = "GBP";          // currency code 1 like (GBP)
input string currencyPair2 = "USD";          // currency code 2 like (USD)
input int minuteBeforeCurrent = 30 ;        // minute before current time (30 min = 30)
input int minuteAfterCurrent = 2 ;         // minute after current time (2 min = 2)

input group           "--------- Strtegy Code Input---------"   
input int DOUBLE_TOP_CODE = 1000 ;
input int DOUBLE_BOTTOM_CODE = 2000 ;
input int BUY_LONG_RANGE_CODE = 3000 ;
input int SELL_LONG_RANGE_CODE = 4000 ;
input int BUG_BUY_CODE = 5000 ;
input int BUG_SELL_CODE = 6000 ;

input int TEST_BUY_CODE = 500000 ;
input int TEST_SELL_CODE = 700000 ;


input group           "--------- Allow Trade Input ---------"   
input bool allowTrade = true ;           // is allowed treade?
input bool allowNewsTrade = false ;      // is allowed News treade?   
input bool allowHedgeTrade = false ;     // is allowed Hedgeging treade? 



input group           "--------- TCP port number Input ---------"  
input int portNumber = 5557 ;



int i = 0;  // ตัวแปรที่ใช้เพิ่มค่า
Context context("mt5server");
Socket socket(context, ZMQ_REP);  // ใช้ REP (Reply) socket

CTrade trade;

int digits ;  
double onePips ;



int buy_count = -1;   
int sell_count = -1;                   //#1 initialize counts
    
void OnInit()
{
    string portString = "tcp://*:" + IntegerToString(portNumber)  ;
    
    //if (!socket.bind("tcp://*:5557"))  // ผูก socket 
    if (!socket.bind(portString)  )   // ผูก socket 
    {
        Print("ไม่สามารถผูก socket กับพอร์ต 5557");
        
    }
    else
    {
        Print("MT5 server started and listening on port 5557");
    }
    
    digits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
     //int floatOfSybol = digits-1 ;
    onePips = MathPow(10, -1*digits)*10 ;
    onePips = NormalizeDouble(onePips,digits); 
    Print("digit = ",digits , " | 1 pips = " , onePips) ;
    
    
    
   double pointValue = PointValue( symbol ); 
   double riskAmount = thisBalance * (percentToRisk/100) ;  // -----------------------------  1000 dollar
   double riskPoints = 50;   // -----------------------------   5 pips
   double riskLots   = riskAmount / ( pointValue * riskPoints );
   PrintFormat( "\nlots for %s is %f",
                symbol,  riskLots );
                
        
    double min_volume = SymbolInfoDouble("GBPUSD", SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble("GBPUSD", SYMBOL_VOLUME_MAX);
   Print("Min volume: ", min_volume, ", Max volume: ", max_volume);            
                
                
}

void OnTick()
{
    ZmqMsg request;
    if (socket.recv(request))  // ตรวจสอบว่ามีข้อความจาก Python หรือไม่
    {
        // แปลงข้อความที่รับเป็นสตริง
        string request_str = request.getData();
        Print("Received data: ", request_str);

        string arr[];
        StringSplit(request_str, ',', arr);

        if (ArraySize(arr) == 4)
        {
            // แปลงข้อความเป็นตัวเลข
            int uniq = StringToInteger(arr[0]);
            int signal = StringToInteger(arr[1]);
            string m1TimeStringSierraChart = arr[2] ;
            string currentTimeStringSierraChart = arr[3] ;

            datetime m1TimeSierraChart = StringToTime(m1TimeStringSierraChart) ;
            datetime currentTimeSierraChart = StringToTime(currentTimeStringSierraChart) ;           
            
            int t1 = diffTimeSierraChartAndMT5(currentTimeSierraChart) ;
            
            datetime m1TimeForMT5 = m1TimeSierraChart - t1 ;
            
            int indexM1 = iBarShift(symbol, PERIOD_M1, m1TimeForMT5);
            double lowM1 = iLow(symbol, PERIOD_M1, indexM1);
            double highM1 = iHigh(symbol, PERIOD_M1, indexM1);
            
            
            // คำนวณผลลัพธ์
            int result = uniq*signal*10 ;

             digits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
             onePips = MathPow(10, -1*digits)*10 ;
             onePips = NormalizeDouble(onePips,digits);
            
           
            int tpInNumber = getTPPipsFromUniqueNumber(uniq);
            
            
            if(tpInNumber != -1 )
            {               
                                               
               if(signal == 1 ||  signal == 500 )
               {
                  double last_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
                  double sl = lowM1 - onePips ;
                  double tp = last_price + tpInNumber*onePips ;
                  
                  last_price = NormalizeDouble(last_price,digits); 
                  sl = NormalizeDouble(sl,digits); 
                  tp = NormalizeDouble(tp,digits); 
                  
                  double point = Point( symbol );
                  double slPoint = (last_price-sl)/point ; 
                  double lot = calLotSize(slPoint) ;
                  lot = NormalizeDouble(lot,2); 
                  Print("sl point = ",slPoint , "lot = " , lot) ;
                     
                  openPosition( symbol ,  lot ,  signal ,  sl ,  tp , allowTrade ,  allowHedgeTrade ,  allowNewsTrade) ;
                  
                  
               }
               else if(signal == -1 || signal == -500 )
               {
                  double last_price = SymbolInfoDouble(symbol, SYMBOL_BID);
                  double sl = highM1 + onePips ;
                  double tp = last_price - tpInNumber*onePips ;
                  
                  last_price = NormalizeDouble(last_price,digits); 
                  sl = NormalizeDouble(sl,digits); 
                  tp = NormalizeDouble(tp,digits); 
                  
                  double point = Point( symbol );
                  double slPoint = (sl-last_price)/point ; 
                  double lot = calLotSize(slPoint) ;
                  lot = NormalizeDouble(lot,2); 
                  Print("sl point = ",slPoint , "lot = " , lot) ;
                     
                  openPosition( symbol , lot ,  signal ,  sl ,  tp , allowTrade ,  allowHedgeTrade ,  allowNewsTrade) ;
                  
                  
               }
           
                         
            }            
                   
            
            // ส่งผลลัพธ์กลับไปยัง Python
            ZmqMsg reply(IntegerToString(result));
            socket.send(reply);
            
            Print("Sent result: ", IntegerToString(result));
            Print("signal num: ", IntegerToString(signal));
            Print("M1 mt5 time: ", m1TimeForMT5 );
            Print("M1 Low:",DoubleToString(lowM1) );
            Print("M1 High:",DoubleToString(highM1) );
            Print("current time: ", currentTimeStringSierraChart );
            
            datetime currentTimeMT5 = TimeCurrent();
            int timeDiff = currentTimeMT5 - (currentTimeSierraChart - t1) ;
            Print("time diff :",IntegerToString(timeDiff) );
            //Print("t1:",IntegerToString(t1) );
        }
        else
        {
            Print("ข้อมูลที่ได้รับไม่ถูกต้อง: ", request_str);
        }
    }
    
    
       
    
   
   //getNumberOfPositionNow(symbol , buy_count,sell_count);
   
   //Print("\n\n buy = ",buy_count , " | sell = " ,sell_count );



}


void OnDeinit(const int reason)
{
   Print("MT5 server stopped and resources freed.");
}


double calLotSize(double riskPoints)
{
   double pointValue = PointValue( symbol ); 
   double riskAmount = thisBalance * (percentToRisk/100) ;  // -----------------------------  1000 dollar
   //double riskPoints = 50;   // -----------------------------   5 pips
   double riskLots   = riskAmount / ( pointValue * riskPoints );
   
   PrintFormat( "\nlots for %s is %f", symbol,  riskLots );
   
   return riskLots;

}


int diffTimeSierraChartAndMT5(datetime currentTimeSierraChart  )
{
   
   //datetime currentTimeSierraChart = StringToTime(currentTimeString) ;
   datetime currentTimeMT5 = TimeCurrent();
   
   int t1 = currentTimeSierraChart-currentTimeMT5 ;
   
   
   int secondOfHour = 3600;
   int tolorent = 100 ;
   int pos_or_neg = 0;
   
   if(t1 > 0) 
      pos_or_neg = 1;
   else if(t1 < 0)
      pos_or_neg = -1; 
      
   t1 = MathAbs(t1) ;
      
   if( (t1 <= 0+tolorent) && (t1 > 0-tolorent) )    // 3600
      return 0*pos_or_neg ;
   else if( (t1 <= secondOfHour+tolorent) && (t1 > secondOfHour-tolorent) )    // diff 1hr
      return secondOfHour*pos_or_neg ;
   else if( (t1 <= 2*secondOfHour+tolorent) && (t1 > 2*secondOfHour-tolorent) ) // diff 2hr
      return 2*secondOfHour*pos_or_neg ;
   else if( (t1 <= 3*secondOfHour+tolorent) && (t1 > 3*secondOfHour-tolorent) )  // diff 3hr
      return 3*secondOfHour*pos_or_neg ;
   else if( (t1 <= 4*secondOfHour+tolorent) && (t1 > 4*secondOfHour-tolorent) )  // diff 4hr
      return 4*secondOfHour*pos_or_neg ;
   else if( (t1 <= 5*secondOfHour+tolorent) && (t1 > 5*secondOfHour-tolorent) )  // diff 5hr
      return 5*secondOfHour*pos_or_neg ;
   else if( (t1 <= 6*secondOfHour+tolorent) && (t1 > 6*secondOfHour-tolorent) )  // diff 6hr
      return 6*secondOfHour*pos_or_neg ;
   else if( (t1 <= 7*secondOfHour+tolorent) && (t1 > 7*secondOfHour-tolorent) )  // diff 7hr
      return 7*secondOfHour*pos_or_neg ;
   else if( (t1 <= 8*secondOfHour+tolorent) && (t1 > 8*secondOfHour-tolorent) )  // diff 8hr
      return 8*secondOfHour*pos_or_neg ;
   else if( (t1 <= 9*secondOfHour+tolorent) && (t1 > 9*secondOfHour-tolorent) )  // diff 9hr
      return 9*secondOfHour*pos_or_neg ;
   else if( (t1 <= 10*secondOfHour+tolorent) && (t1 > 10*secondOfHour-tolorent) )  // diff 10hr
      return 10*secondOfHour*pos_or_neg ;
   else if( (t1 <= 11*secondOfHour+tolorent) && (t1 > 11*secondOfHour-tolorent) )  // diff 11hr
      return 11*secondOfHour*pos_or_neg ;
   else if( (t1 <= 12*secondOfHour+tolorent) && (t1 > 12*secondOfHour-tolorent) )  // diff 12hr
      return 12*secondOfHour*pos_or_neg ;
   else if( (t1 <= 13*secondOfHour+tolorent) && (t1 > 13*secondOfHour-tolorent) )  // diff 13hr
      return 13*secondOfHour*pos_or_neg ;
   else if( (t1 <= 14*secondOfHour+tolorent) && (t1 > 14*secondOfHour-tolorent) )  // diff 14hr
      return 14*secondOfHour*pos_or_neg ;
   else if( (t1 <= 15*secondOfHour+tolorent) && (t1 > 15*secondOfHour-tolorent) )  // diff 15hr
      return 15*secondOfHour*pos_or_neg ;
   else if( (t1 <= 16*secondOfHour+tolorent) && (t1 > 16*secondOfHour-tolorent) )  // diff 16hr
      return 16*secondOfHour*pos_or_neg ;
   else if( (t1 <= 17*secondOfHour+tolorent) && (t1 > 17*secondOfHour-tolorent) )  // diff 17hr
      return 17*secondOfHour*pos_or_neg ;
   else if( (t1 <= 18*secondOfHour+tolorent) && (t1 > 18*secondOfHour-tolorent) )  // diff 18hr
      return 18*secondOfHour*pos_or_neg ;
   else if( (t1 <= 19*secondOfHour+tolorent) && (t1 > 19*secondOfHour-tolorent) )  // diff 19hr
      return 19*secondOfHour*pos_or_neg ;
   else if( (t1 <= 20*secondOfHour+tolorent) && (t1 > 20*secondOfHour-tolorent) )  // diff 20hr
      return 20*secondOfHour*pos_or_neg ;
   else if( (t1 <= 21*secondOfHour+tolorent) && (t1 > 21*secondOfHour-tolorent) )  // diff 21hr
      return 21*secondOfHour*pos_or_neg ;
   else if( (t1 <= 22*secondOfHour+tolorent) && (t1 > 22*secondOfHour-tolorent) )  // diff 22hr
      return 22*secondOfHour*pos_or_neg ;
   else if( (t1 <= 23*secondOfHour+tolorent) && (t1 > 23*secondOfHour-tolorent) )  // diff 23hr
      return 23*secondOfHour*pos_or_neg ; 
   else if( (t1 <= 24*secondOfHour+tolorent) && (t1 > 24*secondOfHour-tolorent) )  // diff 24hr
      return 24*secondOfHour*pos_or_neg ;                                                                  
  
   return -1;
   
}


void getNumberOfPositionNow(string mySymbol , int& buy_count , int& sell_count)
{
   buy_count = 0;
   sell_count= 0;
   
   for(int i = PositionsTotal() - 1 ; i >= 0 ; i--)   //#2 not i <= 0 
   {
      PositionGetTicket(i);                            //#3 Missing PositionGetTicket(i);    
     
       if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY
          && PositionGetString(POSITION_SYMBOL) == mySymbol)            
       {
         buy_count++;
       }
       if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL
          && PositionGetString(POSITION_SYMBOL) == mySymbol)    
       {
        sell_count++;
       }

   } // for loop end




}



void openPosition(string symbol , double lot , int signal , double sl , double tp ,
                 bool allowTrade , bool allowHedgeTrade , bool allowNewsTrade)
{
   
   int buy_count = -1 ;
   int sell_count = -1 ;
   getNumberOfPositionNow(symbol , buy_count, sell_count);


   bool haveNews = haveHighImpactNewsEvent() ;
   
   if( allowTrade == false)
   {
      if(signal == 1 || signal == 500 ) 
      { 
         double last_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
         Print("buy signal but trade not allow");
         Print("buy at " , last_price ," | lot = ", lot ," | SL at " , sl , " | TP at " , tp);
      }
      
      if(signal == -1 || signal == -500)
      {
         double last_price = SymbolInfoDouble(symbol, SYMBOL_BID);
         Print("sell signal but trade not allow");
         Print("sell at " , last_price ," | lot = ", lot ," | SL at " , sl , " | TP at " , tp);
      } 
      
      Print("HTTP and Socket work fine !!!");
      
      return;
   }
   
   
   if(haveNews && allowNewsTrade == false) 
   {
      if(signal == 1 || signal == 500) 
      {
         double last_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
         Print("buy signal but have News and it not allow");
         Print("buy at " , last_price ," | lot = ", lot ," | SL at " , sl , " | TP at " , tp);
      }
      if(signal == -1 || signal == -500) 
      {
         double last_price = SymbolInfoDouble(symbol, SYMBOL_BID);
         Print("sell signal but have News and it not allow");
         Print("sell at " , last_price ," | lot = ", lot ," | SL at " , sl , " | TP at " , tp);
      }
      return;
   }
   
   if( (signal == 1 || signal == 500) && sell_count > 0 && allowHedgeTrade == false )
   {
      double last_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      Print("having buy now and hedging not allow !!");
      Print("buy at " , last_price ," | lot = ", lot ," | SL at " , sl, " | TP at " , tp);
      return;
   } 
   if( (signal == -1 || signal == -500) && buy_count > 0 && allowHedgeTrade == false ) 
   {
      double last_price = SymbolInfoDouble(symbol, SYMBOL_BID);
      Print("having sell now and hedging not allow !!");
      Print("sell at " , last_price ," | lot = ", lot ," | SL at " , sl , " | TP at " , tp);
      return;
   }
   
   
   if(signal == 1  )
   {
      double last_price = SymbolInfoDouble(symbol, SYMBOL_ASK);         
      trade.Buy(lot,symbol , 0  , sl , tp) ;
      Print("buy at " , last_price ," | lot = ", lot ," | SL at " , sl, " | TP at " , tp);
      
   }
   else if(signal == -1  )
   {
      double last_price = SymbolInfoDouble(symbol, SYMBOL_BID);    
      trade.Sell(lot,symbol , 0 , sl) ;      
      Print("sell at " , last_price ," | lot = ", lot ," | SL at " , sl , " | TP at " , tp);           
      
   }
   else if(signal == 500  )
   {
      double last_price = SymbolInfoDouble(symbol, SYMBOL_ASK);         
      Print("buy at " , last_price ," | lot = ", lot ," | SL at " , sl, " | TP at " , tp);
      
   }
   else if(signal == -500 )
   {
      double last_price = SymbolInfoDouble(symbol, SYMBOL_BID);    
      Print("sell at " , last_price ," | lot = ", lot ," | SL at " , sl , " | TP at " , tp);           
      
   }
  

}            
 


int getTPPipsFromUniqueNumber(int uniq)
{
   if(uniq >= DOUBLE_TOP_CODE && uniq <= DOUBLE_TOP_CODE+500) return 30 ;
   else if(uniq >= DOUBLE_BOTTOM_CODE && uniq <= DOUBLE_BOTTOM_CODE+500) return 30 ;
   else if(uniq >= BUY_LONG_RANGE_CODE && uniq <= BUY_LONG_RANGE_CODE+500) return 30 ;
   else if(uniq >= SELL_LONG_RANGE_CODE && uniq <= SELL_LONG_RANGE_CODE+500) return 30 ;
   else if(uniq >= BUG_BUY_CODE && uniq <= BUG_BUY_CODE+500) return 15 ;
   else if(uniq >= BUG_SELL_CODE && uniq <= BUG_SELL_CODE+500) return 15 ;
   else if(uniq >= 500000) return 10 ;
   
   return -1;

}


bool haveHighImpactNewsEvent()
{
   bool isNews = false;
   int totalNews = 0;
   
   MqlCalendarValue values[];
   datetime startTime = TimeTradeServer() - PeriodSeconds(PERIOD_M1)*minuteBeforeCurrent ;
   datetime endTime = TimeTradeServer() + PeriodSeconds(PERIOD_M1)*minuteAfterCurrent ;
   int valuesTotal = CalendarValueHistory(values,startTime,endTime);
   
   Print("FURTHEST TIME LOOK BACK = ",startTime," >>> CURRENT = ",TimeTradeServer());
   Print("FURTHEST TIME LOOK FORE = ",endTime," >>> CURRENT = ",TimeTradeServer());
   
   for (int i=0; i < valuesTotal; i++)
   {
      MqlCalendarEvent event;
      CalendarEventById(values[i].event_id,event);
      
      MqlCalendarCountry country;
      CalendarCountryById(event.country_id,country);
      
      if (event.importance == CALENDAR_IMPORTANCE_HIGH && 
         (country.currency == currencyPair1 || country.currency == currencyPair2) &&
          TimeTradeServer() >= startTime && TimeTradeServer() <= endTime )
      {
         totalNews++;
      }     
 
   }
   
    if (totalNews > 0)
   {
      isNews = true;
      Print(" >>>>>>>> (FOUND NEWS) TOTAL NEWS = ",totalNews,"/",ArraySize(values));
   }
   else if (totalNews <= 0)
   {
         isNews = false;
         Print(" >>>>>>>> (NOT FOUND NEWS) TOTAL NEWS = ",totalNews,"/",ArraySize(values));
   }
   
   return (isNews);
   
   
}




double PointValue( string symbol ) {

   double tickSize      = TickSize( symbol );
   double tickValue     = TickValue( symbol );
   double point         = Point( symbol );
   double ticksPerPoint = tickSize / point;
   double pointValue    = tickValue / ticksPerPoint;

   PrintFormat( "tickSize=%f, tickValue=%f, point=%f, ticksPerPoint=%f, pointValue=%f",
                tickSize, tickValue, point, ticksPerPoint, pointValue );

   return ( pointValue );
}

