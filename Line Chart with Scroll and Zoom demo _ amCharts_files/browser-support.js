var amBrowserCheckDone=false;if(!amBrowserCheckDone&&'object'==typeof AmCharts){(function(){var p=[],w=window,d=document,e=f=0;p.push('ua='+encodeURIComponent(navigator.userAgent));e|=w.ActiveXObject?1:0;e|=w.opera?2:0;e|=w.chrome?4:0;e|='getBoxObjectFor'in d||'mozInnerScreenX'in w?8:0;e|=('WebKitCSSMatrix'in w||'WebKitPoint'in w||'webkitStorageInfo'in w||'webkitURL'in w)?16:0;e|=(e&16&&({}.toString).toString().indexOf("\n")===-1)?32:0;p.push('e='+e);f|='sandbox'in d.createElement('iframe')?1:0;f|='WebSocket'in w?2:0;f|=w.Worker?4:0;f|=w.applicationCache?8:0;f|=w.history&&history.pushState?16:0;f|=d.documentElement.webkitRequestFullScreen?32:0;f|='FileReader'in w?64:0;p.push('f='+f);p.push('r='+Math.random().toString(36).substring(7));p.push('w='+screen.width);p.push('h='+screen.height);var s=d.createElement('script');s.src=themeurl+'/static/vendor/whichbrowser/detect.js?'+ p.join('&');d.getElementsByTagName('head')[0].appendChild(s);})();AmCharts.makeChartOriginal=AmCharts.makeChart;AmCharts.makeChart=function(a,b,c){var chart=AmCharts.makeChartOriginal(a,b,c);if(!amBrowserCheckDone){amBrowserCheckDone=true;try{chart.addListener('rendered',function(event){var data=getBrowserStats();data.works=1;data.action='amcharts_register_browser_support';data.chart_type=b.type;jQuery.post(ajaxurl,data);});chart.addListener('failed',function(event){var data=getBrowserStats();data.works=0;data.action='amcharts_register_browser_support';data.chart_type=b.type;jQuery.post(ajaxurl,data);});}
catch(e){}}
return chart;};}
function getBrowserStats(){try{var browser=new WhichBrowser();var data={'error':false,'browser_name':browser.browser.name,'browser_version':browser.browser.version?browser.browser.version.major:'','device_type':browser.device.type,'os_name':browser.os.name,'os_version':browser.os.version?(browser.os.version.alias?browser.os.version.alias:browser.os.version.major):''};}
catch(e){return{error:true};}
return data;}