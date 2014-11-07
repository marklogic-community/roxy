xquery version "1.0-ml";

import module namespace vh = "http://marklogic.com/roxy/view-helper" at "/roxy/lib/view-helper.xqy";

declare variable $PAGELENGTH := vh:get("PAGELENGTH");
declare variable $GEO-ENABLED := vh:get("GEO-ENABLED");
declare variable $GOOGLEMAPS-API-KEY := vh:get("GOOGLEMAPS-API-KEY");
declare variable $DATE-RANGE-ENABLED := vh:get("DATE-RANGE-ENABLED");
declare variable $TIMESERIES-ENABLED := vh:get("TIMESERIES-ENABLED");
declare variable $SEARCH-NOT-OPERATOR := vh:get("SEARCH-NOT-OPERATOR");

xdmp:set-response-content-type("text/html"),
'<!DOCTYPE html>',
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8"/>
    <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <title>MarkLogic</title>

    <!-- Bootstrap -->
    <link href="../public/css/bootstrap.min.css" rel="stylesheet"/>
    <link href="../public/css/datepicker3.css" rel="stylesheet"/>
    <link href="../public/css/app.less" rel="stylesheet"/>
    <link href="../public/css/codemirror.css" rel="stylesheet"/>

    <!-- HTML5 Shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!-- WARNING: Respond.js doesn't work if you view the page via file:// -->
    <!--[if lt IE 9]>
    <script src="../public/js/lib/html5shiv.js"></script>
    <script src="../public/js/lib/respond.min.js"></script>
    <![endif]-->
  </head>
  <body>
    <nav class="navbar navbar-inverse navbar-static-top" role="navigation">
      <div class="container-fluid">
        <!-- Brand and toggle get grouped for better mobile display -->
        <div class="navbar-header">
          <button type="button" class="navbar-toggle" data-toggle="collapse" data-target="#bs-example-navbar-collapse-1">
            <span class="sr-only">Toggle navigation</span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="#">MarkLogic</a>
        </div>

          <!-- Collect the nav links, forms, and other content for toggling -->
        <div class="collapse navbar-collapse" id="main_tabs">
          <ul class="nav navbar-nav">
            <li class="active"><a href="#search" role="tab" data-toggle="tab"><span class="glyphicon glyphicon-search"></span>&nbsp;Search</a></li>
            <li><a href="#documents" role="tab" data-toggle="tab"><span class="glyphicon glyphicon-file"></span>&nbsp;Document Viewer</a></li>
          </ul>
        </div><!-- /.navbar-collapse -->
      </div><!-- /.container-fluid -->
    </nav>
    <div class="tab-content">
      <div id="search" class="tab-pane fade in active col-md-10 col-md-offset-1">
        <div id="search_container" class="row">
          <div id="facet_div" class="col-md-3">
          </div>
          <div id="search_div" class="col-md-9">
            <div id="quicksearch">
              <div class="input-group">
                <input type="text" class="form-control search_text" id="quicksearch_text" placeholder="search"/>
                <span class="input-group-btn">
                  <button id="search_button" class="btn btn-default search_button" type="button"><span class="search_button_text">Search</span><img src="../images/loadspinner.gif" style="display:none" class="search_button_image"/></button>
                </span>
              </div><!-- /input-group -->
            </div>
            <br/>
            <div>
            {
              if ($DATE-RANGE-ENABLED) then
                <div class="pull-right" id="date_constraint">
                  <form class="form-inline" role="form">
                    <div class="form-group">
                      <label class="sr-only" for="startDate">Start Date</label>
                      <input type="text" class="form-control date-input" id="startDate" placeholder="Start Date"/>
                    </div>
                    <div class="form-group">
                      <label class="sr-only" for="endDate">End Date</label>
                      <input type="text" class="form-control date-input" id="endDate" placeholder="End Date"/>
                    </div>
                  </form>
                </div>
              else
                ()
            }
            </div>
            <ul class="nav nav-tabs" role="tablist">
              <li class="active"><a href="#results_container" role="tab" data-toggle="tab">Results</a></li>
              {
                if ($TIMESERIES-ENABLED) then
                  <li><a href="#timeseries_container" role="tab" data-toggle="tab">Time Series</a></li>
                else
                  ()
              }
              {
                if ($GEO-ENABLED) then
                  <li><a href="#geo_container" role="tab" data-toggle="tab">Map</a></li>
                else
                  ()
              }
            </ul>
            <div class="tab-content">
              <div id="results_container" class="tab-pane fade in active">
                <br/>
                <div id="results_div">
                  
                </div>
                <div id="pager_div" class="hidden">
                  <div id="pager_text"></div>
                  <ul class="pagination">
                      <!--<li id="page_first"><a href="#" class="page_link">&laquo;</a></li>-->
                      <li id="page_prev"><a href="#" class="page_link">&lt;</a></li>
                      <li id="page_1"><a href="#" class="page_link">1</a></li>
                      <li id="page_2"><a href="#" class="page_link">2</a></li>
                      <li id="page_3"><a href="#" class="page_link">3</a></li>
                      <li id="page_4"><a href="#" class="page_link">4</a></li>
                      <li id="page_5"><a href="#" class="page_link">5</a></li>
                      <li id="page_next"><a href="#" class="page_link">&gt;</a></li>
                      <!--<li id="page_last"><a href="#" class="page_link">&raquo;</a></li>-->
                    </ul>
                  </div>
              </div>
              {
                if ($TIMESERIES-ENABLED) then
                  <div id="timeseries_container" class="tab-pane fade">
                    <div id="document_time_chart"></div>
                  </div>
                else
                  ()
              }
              {
                if ($GEO-ENABLED) then
                  <div id="geo_container" class="tab-pane fade">
                    <div id="map_container"></div>
                  </div>
                else
                  ()
              }
            </div>
          </div>
        </div>
      </div>
      <div id="documents" class="tab-pane fade">
        <div class="container col-md-10 col-md-offset-1">
          <input type="text" class="form-control" id="document_id_input"/>
          <iframe id="doc_viewer" frameborder="0"></iframe>
        </div>
      </div>
    </div>
    
    <input type="hidden" id="geoData" value=""/>
    <script id="results_tmpl" type="text/x-handlebars-template">
      {{{{#each this}}}}
      <div class="result">
          <h4 class="media-heading"><a class="document_link search_result" data-uri="{{{{uri}}}}" href="../content?uri={{{{uri}}}}" target="_blank">{{{{title}}}}</a></h4>
          {{{{{{snippets}}}}}}
      </div>
      <br/>
      {{{{/each}}}}
    </script>

    <script id="facets_tmpl" type="text/x-handlebars-template">
      {{{{#each this}}}}
      <div class="facet panel panel-default small">
        <div class="panel-heading"><h3 class="panel-title">{{{{key}}}}</h3></div>
          <div class="list-group">
            {{{{#each value}}}}
              <a href="#" class="list-group-item facet_link" data-value="{{{{../key}}}}:{{{{name}}}}"><span class="glyphicon glyphicon-minus-sign hidden">&nbsp;</span><span class="badge">{{{{count}}}}</span>{{{{name}}}}</a>
            {{{{/each}}}}
          </div>
      </div>
      {{{{/each}}}}
    </script>
    <input type="hidden" id="PAGELENGTH" value="{$PAGELENGTH}"/>
    <input type="hidden" id="DATE-RANGE-ENABLED" value="{$DATE-RANGE-ENABLED}"/>
    <input type="hidden" id="TIMESERIES-ENABLED" value="{$TIMESERIES-ENABLED}"/>
    <input type="hidden" id="SEARCH_NOT_OPERATOR" value="{$SEARCH-NOT-OPERATOR}"/>
    <script src="../js/lib/jquery-1.7.1.min.js" type="text/javascript"></script>
    <script src="../js/lib/less-1.3.0.min.js" type="text/javascript"></script>
    <script src="../js/lib/bootstrap.min.js" type="text/javascript"></script>
    <script src="../js/lib/bootstrap-datepicker.js" type="text/javascript"></script>
    <script src="../js/lib/handlebars-v2.0.0.js" type="text/javascript"></script>
    {
      if ($GEO-ENABLED) then
        (
          <script type="text/javascript" src="https://maps.googleapis.com/maps/api/js?key={$GOOGLEMAPS-API-KEY}&amp;libraries=drawing,visualization"></script>,
          <script src="../js/app-geo.js" type="text/javascript"></script>
        )
      else
        ()
    }
    {
      if ($TIMESERIES-ENABLED) then
        (
          <script src="../js/lib/highcharts.js" type="text/javascript"></script>,
          <script src="../js/lib/modules/drilldown.js" type="text/javascript"></script>,
          <script src="../js/app-timeseries.js" type="text/javascript"></script>
        )
      else
        ()
    }
    <script src="../js/app.js" type="text/javascript"></script>
  </body>
</html>