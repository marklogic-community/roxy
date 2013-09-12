/**
* Copyright 2012 MarkLogic Corporation
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
var queue = [];

var runTest = null;

function disableParent(item, parentClass) {
  var li = $(item).parents(parentClass);
  if ($(item).is(":checked")) {
    li.removeClass("disabled");
  }
  else {
    li.addClass("disabled");
  }

}

function runNextTest() {
  if (queue.length > 0) {
    runTest(queue.pop());
  }
  else {
    // compute total pass/fails
    var totalFails = 0;
    $('td.failures').each(function(){
      var fails = parseInt($(this).text(), 10);

      if (isNaN(fails)) {
        fails = 0;
      }
      totalFails += fails;
    });

    var totalErrors = 0;
    $('td.errors').each(function(){
      var errors = parseInt($(this).text(), 10);

      if (isNaN(errors)) {
        errors = 0;
      }
      totalErrors += errors;
    });

    var totalPasses = 0;
    $('td.successes').each(function() {
      var passes = parseInt($(this).text(), 10);
      if (isNaN(passes)) {
        passes = 0;
      }
      totalPasses += passes;
    });

    $(".canceltests").hide();
    $(".runtests").show();

    var txt = "";
    if (totalPasses > 0 || totalFails > 0 || totalErrors > 0) {
      txt = '<span class="success"><span class="count">' + totalPasses + '</span> successes</span><span class="failed"><span class="count">' + totalFails + '</span> failures</span><span class="error"><span class="count">' + totalErrors + '</span> errors</span>';
    }
    else {
      txt = '<span class="failed">NO TESTS RUN</span>';
    }
    $('#test-results').html(txt);
    $.gritter.add({
      title: 'Tests finished',
      text: txt,
      sticky: false,
      time: ''
    });

  }
}

function renderError(name, error) {
  var failure = error.find("[nodeName = 'error:code']").text() === "TEST-FAIL" ? 'FAILURE' : 'ERROR';
  var result =
    '<div class="failure">' +
    '<div class="test-name">' + name + ' ' + failure + '</div>' +
    '<div class="test-data">';

  if (typeof(error[0]) === 'string') {
    result += '<p>' + error + '</p>';
  }
  else {
    var formatString = error.find("[nodeName = 'error:code']").text() + ': (' + error.find("[nodeName = 'error:name']").first().text() + ') ' + error.find("[nodeName = 'error:expr']").text();
    if (error.find("[nodeName = 'error:code']").text() !== error.find("[nodeName = 'error:message']").text()) {
      formatString += ' -- ' + error.find("[nodeName = 'error:message']").text();
    }


    var datum = error.find("[nodeName = 'error:datum']").children();
    if (datum.length <= 0) {
      datum = '';
    }

    if (formatString && formatString.length > 0) {
      result += '<p>' + formatString.replace(/</g, "&lt;").replace(/>/, "&gt;") + '</p>';
    }

    result +=
      '<div>' + datum + '</div>' +
      '<div class="call-stack-container">' +
      '<span>Call Stack:</span>' +
      '<img class="plus" src="img/icon-plus.png"/>' +
      '<img class="minus" src="img/icon-minus.png" style="display:none"/>' +
      '<div class="stack" style="display:none">';

    error.find("[nodeName = 'error:frame']").each(function() {
      var uri = $(this).find("[nodeName = 'error:uri']").text();
      var line = $(this).find("[nodeName = 'error:line']").text();
      var operation = $(this).find("[nodeName = 'error:operation']").text();
      var variables = $(this).find("[nodeName = 'error:variable']");
      result +=
        '<div class="frame"><p class="bold">in ' + uri + ' on line ' + line + ',</p>' +
        '<p>in ' + operation.replace(/</g, "&lt;").replace(/>/g, "&gt;") + '</p>';

      if (variables.length > 0) {
        result += '<ul class="variables"><u>variables:</u>';

        variables.each(function() {
          var name = $(this).find("[nodeName = 'error:name']").text();
          var value = $(this).find("[nodeName = 'error:value']").text();
          result += '<li>' + name + ' = ' + value.replace(/</g, "&lt;").replace(/>/g, "&gt;") + '</li>';
        });
      }
      result +=
        '</ul>' +
        '</div>';
    });

    result +=
      '</div>' +
      '</div>';
  }

  result +=
    '</div>' +
    '</div>';

  return $(result);
}

function testSuccess(parent, xml) {
  var i;
  var test = $("[nodeName='t:test']", xml);
  var assertions = parseInt(test.attr('assertions'), 10);
  var successes = parseInt(test.attr('successes'), 10);
  var failures = parseInt(test.attr('failures'), 10);
  var errors = parseInt(test.attr('errors'), 10);

  test.find("[nodeName = 't:assertion'],[nodeName = 't:error']").each(function() {
    var assertion = $(this);
    var name = assertion.attr("name");
    var type = assertion.attr("type") || this.localName;

    var error = assertion.children();
    if (error.length <= 0) {
      error = assertion.text();
    }

    var span = null;

    if (name === "setup" || name === "teardown") {
      var row = parent.next().find('.' + name);
      if (row.length > 0) {
        row.show();
        span = row.find('span.outcome');
      }
    }
    else {
      span = parent.next().find('input[value = "' + name + '"]').next('span.outcome');
    }

    if (span) {
      span.text(type === "success" ? "Passed" : "Failed");
      span.removeClass("success");
      span.removeClass("fail");
      span.addClass(type);

      if (type !== "success") {
        span.after(renderError(name, error));
        span.next().find("img.plus").click(function(event) {
          $(this).hide();
          $(this).next("img.minus").show();
          $(this).nextAll("div.stack").show();
        });

        span.next().find("img.minus").click(function(event) {
          $(this).hide();
          $(this).prev("img.plus").show();
          $(this).nextAll("div.stack").hide();
        });
      }
    }
  });
  parent.removeClass('running');

  parent.find("td.tests-run").text(assertions);
  parent.find("td.assertions").text(assertions);
  parent.find("td.successes").text(successes);
  parent.find("td.failures").text(failures > 0 ? failures : '');
  parent.find("td.errors").text(errors > 0 ? errors : '');

  var spinner = parent.find("span.spinner");
  spinner.hide();

  runNextTest();
}

function testFailure(parent, data) {
  parent.after($(data).find("dl"));
  var spinner = parent.find("span.spinner");
  spinner.hide();

  runNextTest();
}

runTest = function(suite) {
  var check = $("input:checked[value='" + suite + "']");
  var parent = check.parents("tr");
  var assertions = [];
  parent.next().find("input.test-cb:checked").each(function() {
    assertions.push($(this).val());
  });

  parent.addClass('running');

  var suiteTearDown = $("#runsuiteteardown").prop("checked");
  var tearDown = $("#runteardown").prop("checked");
  var spinner = parent.find("span.spinner");
  spinner.show();

  $.ajax({
    url: "run",
    cache: false,
    data: {
      test: suite,
      assertions: assertions.join(","),
      runteardown: tearDown
    },
    dataType: "xml",
    success: function(data) {
      testSuccess(parent, data);
    },
    error: function(data) {
      testFailure(parent, data);
    }
  });
};

function run() {
  $('tr.result').remove();
  $('span.outcome').text("");
  $('#test-results').text("");
  $('.setup').hide();
  $('.teardown').hide();
  $("td.failures").text("-");
  $("td.errors").text("-");
  $("td.successes").text("-");
  $('div.failure').remove();

  queue = [];
  $("input.cb:checked").each(function(){
    queue.push(this.value);
  });

  if (queue.length > 0) {
    $("#test-results").text("Running...");
    $(".runtests").hide();
    $(".canceltests").show();
    queue.reverse();
    runTest(queue.pop());
  }
}

function cancel() {
  queue.length = 0;
  $("#test-results").text("Stopping tests...");
  $(".canceltests").hide();
}

$(document).ready(function(){

  $.extend($.gritter.options, {
    position: 'top-right', // possibilities: bottom-left, bottom-right, top-left, top-right
    fade_in_speed: 500, // how fast notifications fade in (string or int)
    fade_out_speed: 300, // how fast the notices fade out
    time: 3000 // hang on the screen for...
  });

  // handler for clicking the run tests button
  $(".runtests").click(function(event){
    run();
  });

  // handle for clicking the cancel button
  $(".canceltests").click(function(event){
    cancel();
  });

  // handler for toggling the select all checkbox
  $("#checkall").click(function(event){
    $("#tests tbody").find("input.cb").each(function(){
      $(this).attr("checked", $("#checkall").is(":checked"));
      disableParent(this, "tr");
    });
  });

  $("input.cb").each(function() {
    if (this.id !== "checkall") {
      $(this).click(function(event) {

        disableParent(this, "tr");

        var totalBoxes = $("input.cb").length;
        var checkedBoxes = $("input.cb:checked").length;
        if (totalBoxes === checkedBoxes) {
          $("#checkall").attr("checked", true);
        }
        else {
          $("#checkall").attr("checked", false);
        }
      });
    }
  });

  $("input.check-all-tests").click(function(event){
    var parentCheck = $(this);
    parentCheck.parent().next("ul.tests").find("input.test-cb").each(function() {
      $(this).attr("checked", parentCheck.is(":checked"));
      disableParent(this, "li");
    });
    parentCheck.parents("tr").prev("tr").find("input.cb").attr("checked", parentCheck.is(":checked"));
  });

  $("input.test-cb").each(function() {
    $(this).click(function(event) {
      disableParent(this, "li");

      var checkAll = $(this).parents("div.tests").find("input.check-all-tests");
      var runTest = $(this).parents("tr").prev("tr").find("input.cb");
      var totalBoxes = $(this).parents("ul.tests").find("input.test-cb").length;
      var checkedBoxes = $(this).parents("ul.tests").find("input.test-cb:checked").length;
      if (totalBoxes === checkedBoxes) {
        checkAll.attr("checked", true);
      }
      else {
        checkAll.attr("checked", false);
      }

      runTest.attr("checked", checkedBoxes > 0);
      disableParent(runTest, "tr");
    });
  });

  $("div.test-name").click(function(event) {
    // $(this).toggle();
    $(this).find("img.tests-toggle-minus").toggle();
    $(this).find("img.tests-toggle-plus").toggle();
    $(this).parents("tr").next().find("div.tests").toggle();
  });

  $(".runtests").focus();

  $(window).keypress(function(event) {
    if (event.keyCode === 13 && event.metaKey) {
      run();
      event.preventDefault();
      return false;
    }
    else if (event.keyCode === 27) {
      cancel();
      event.preventDefault();
      return false;
    }
  });
});

