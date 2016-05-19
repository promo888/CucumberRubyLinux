if(!Array.prototype.indexOf)
{Array.prototype.indexOf=function(elt)
{var len=this.length>>>0;var from=Number(arguments[1])||0;from=(from<0)?Math.ceil(from):Math.floor(from);if(from<0)
from+=len;for(;from<len;from++)
{if(from in this&&this[from]===elt)
return from;}
return-1;};}
jQuery(document).ready(function(){if(jQuery('.amcharts-tooltip').length&&jQuery().tooltip!==undefined){jQuery('.amcharts-tooltip').tooltip();}
jQuery('.m-nav-opener').click(function(event){event.preventDefault();jQuery('.app').toggleClass('m-nav-open');return false;});jQuery('.app-body').click(function(){if(jQuery('.app').hasClass('m-nav-open'))
jQuery('.app').removeClass('m-nav-open');});jQuery('.track-event').click(function(){var data=jQuery(this).data();_gaq.push(['_trackEvent',data.category,data.action,data.label]);});jQuery.extend(jQuery.easing,{easeOutExpo:function(a,b,c,d,e){return(b==e)?c+ d:d*(- Math.pow(2,-10*b/e)+ 1)+ c;}});jQuery(".app-customers").each(function(){setTimeout(function(){var $bl=jQuery(".app-customers .slider-wrapper"),$th=jQuery(".app-customers .slider-container"),blW=$bl.outerWidth(),blSW=$bl[0].scrollWidth,wDiff=(blSW/blW)-1,mPadd=60,damp=20,mX=0,mX2=0,posX=0,mmAA=blW-(mPadd*2),mmAAr=(blW/mmAA);$bl.unbind().bind('mousemove',function(e){mX=e.pageX- this.offsetLeft;mX2=Math.min(Math.max(0,mX-mPadd),mmAA)*mmAAr;});setInterval(function(){posX+=(mX2- posX)/ damp; // zeno's paradox equation "catching delay"
				$th.css({left: -posX*wDiff });
			}, 10);
		},1000);
	});
	
	/*
	** BIND REGISTER
	*/
	jQuery('.btn-register').on('click',function() {
		_gaq.push(['_trackPageview', '/registration']);
	});

	/*
	** EVAL TEXTAREAS
	*/
	jQuery(".evaltextarea").each(function(){
		eval(this.value);
	});

	// Change back to original
	if ( 'undefined' != typeof AmCharts && AmCharts.lazyLoadMakeChart ) {
		AmCharts.makeChart = AmCharts.lazyLoadMakeChart;
	}
});

function amScrollTo (hash) {
  jQuery('html, body').animate({
    scrollTop: jQuery(hash).offset().top
  }, 800, function(){
    window.location.hash = hash;
  });
}

function amLoadModal ( ajax ) {
  if (jQuery('.app-modal').length) {
    var modal = jQuery('.app-modal');
    modal.find('.tab_pane_content').html('<div class="loading"><span class="icon-loading"></span> Loading...</div>');
  }
  else {
    var modal = jQuery('<div class="app-modal" id="am-modal"><a class="btn-close" href="#"></a><div class="tab_pane_content"><div class="loading"><span class="icon-loading"></span> Loading...</div></div></div>').hide().appendTo('body');
    jQuery('#am-modal .btn-close').click(function () {
      jQuery('#am-modal').fadeOut(function () {
        jQuery(this).remove();
      });
    });
  }

  var css = {
    width: jQuery(window).width() * 0.8,
    height: jQuery(window).height() * 0.8
  };
  if ( css.width > 1000 ) {
    css.width = 1000;
  }
  css.marginLeft = css.width / 2 * -1;
  css.marginTop = css.height / 2 * -1;
  modal.css(css).fadeIn();
	jQuery.post(ajaxurl, ajax, function(response) {
		jQuery('.app-modal .tab_pane_content').html(response);
	});
}



/*
** AM SLIDER
*/
jQuery(document).ready(function() {
	if ( jQuery(".amslider").length ) {
		var current            = 1;
		var timer              = {
			resize: 0,
			scroll: 0
		};
		var scrollWidth        = 0;
		var scrollAnchorWidth  = 0;
		var scrollAnchorHeight = 0;
		var scrollAnchor       = [];
		var scrollIndicators   = [];
		var scrollItems        = jQuery(".amslider-items-list li.item");
		var scrollOffset       = 0;

		// Scroll to
		function scrollToSlide(id) {
		    jQuery(".amslider-items-list").animate({
		      scrollLeft: scrollAnchor[id] - scrollOffset
		    },{
		      speed: 250,
		      easing: "easeOutExpo",
		      queue: false
		    });
		}

		// Refresh dimensions
		function scrollResize() {
			scrollWidth        = jQuery(".amslider-items-list").width();
			scrollAnchorWidth  = jQuery(".amslider-items-list li.item").width();
			scrollAnchorHeight = jQuery(".amslider-items-list li.item").height();
			scrollAnchor       = jQuery(".amslider-items-list li.item").map(function() {
				return this.offsetLeft;
			});
			scrollAnchor.push(scrollAnchor[scrollAnchor.length-1] + scrollAnchor[scrollAnchor.length-1]);

			scrollOffset = (jQuery(window).width() - scrollAnchorWidth) / 2;

		    jQuery(".amslider-items").css({
		    	height: scrollAnchorHeight
		    });

		    scrollToSlide(current);
		}
		jQuery(".amslider-items-list li.item img").last().on("load",function() {
		  clearTimeout(timer.resize);
		  timer.resize = setTimeout(scrollResize,100);
		});
		clearTimeout(timer.resize);
		timer.resize = setTimeout(scrollResize,100);

		// Refresh on resize
		jQuery(window).on("resize",function() {
		  clearTimeout(timer.resize);
		  timer.resize = setTimeout(scrollResize,100);
		});

		// Add; observe indicators
		scrollItems.each(function(id) {
		  var li         = jQuery("<li>").appendTo(".amslider-indicators-list");
		  var link       = jQuery("<a>").appendTo(li);

		  li.addClass(id==0?"active":"");
		  link.attr({
		    href: "#amslider-" + id
		  }).on("click",function(e) {
		    e.preventDefault();
		    scrollToSlide(id);
		  });

		  scrollIndicators.push(li[0]);
		});

		// Observe scrolling
		jQuery(".amslider-items-list").on("scroll",function() {
		  var scrollLeft = this.scrollLeft;
		  scrollAnchor.each(function(id) {
		    if ( scrollLeft + ( scrollWidth / 2 ) < this ) {
		      if ( current != id - 1) {
		        current = id - 1;
		        current = current<0?0:current;

		        jQuery(scrollItems).removeClass("active");
		        jQuery(scrollItems[current]).addClass("active");
		        jQuery(scrollIndicators).removeClass("active");
		        jQuery(scrollIndicators[current]).addClass("active");
		      }

		      // Auto slide to index
		      clearTimeout(timer.scroll);
		      timer.scroll = setTimeout(function() {
		        scrollToSlide(current);
		      },500);
		      return false;
		    } 
		  });
		});

		jQuery(".amslider-controls-next").on("click",function(e) {
		  var next = current+1;
		  scrollToSlide(next>scrollIndicators.length-1?0:next);
		  e.preventDefault();
		});
		jQuery(".amslider-controls-prev").on("click",function(e) {
		  var next = current-1;
		  scrollToSlide(next<0?scrollIndicators.length-1:next);
		  e.preventDefault();
		});
	}
});