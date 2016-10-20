var req = require("/roxy/lib/request.xqy");

module.exports = {

  main : function () {
    return '<html xmlns="http://www.w3.org/1999/xhtml">' +
      '  <title>main</title>' +
      '  <div id="message">test message: main</div>' +
      '</html>';
  },
  print : function () {
    return "<div>this is print</div>";
  }
};
