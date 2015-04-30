/**
* Copyright 2012-2015 MarkLogic Corporation
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*    http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
**/
$(document).ready(function() {
  $('.category h4').click(function(e){
    $(this).next().animate({
        height: 'toggle'
      }, 1000, function() {
        // Animation complete.
      });
  });

  $('.list-toggle').click(function(e){
    $(this).prev().animate({
        height: 'toggle'
      }, 1000, function() {
        // Animation complete.
      });
      var text = $(this).text() == "...More" ? "...Fewer" : "...More";
      $(this).text(text);
  });
});