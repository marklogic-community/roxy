xquery version "1.0-ml";

module namespace c = "http://marklogic.com/roxy/controller/tester";

(: The request library provides awesome helper methods to abstract get-request-field :)
import module namespace req = "http://marklogic.com/roxy/request" at "/roxy/lib/request.xqy";

(: the controller helper library provides methods to control which view and template get rendered :)
import module namespace ch = "http://marklogic.com/roxy/controller-helper" at "/roxy/lib/controller-helper.xqy";

import module namespace search = "http://marklogic.com/appservices/search" at "/MarkLogic/appservices/search/search.xqy";

declare namespace html = "http://www.w3.org/1999/xhtml";

declare option xdmp:mapping "false";

declare function c:main() as item()*
{
  ch:add-value("message", "test message: main"),
  ch:add-value("title", "main"),
  ch:use-layout("test-layout", "html"),
  ch:use-layout((), "xml")
};

declare function c:missing-layout()
{
  ch:add-value("message", "test message: missing-layout"),
  ch:use-layout("i-dont-exist")
};

declare function c:no-layout()
{
  ch:add-value("message", "test message: no-layout"),
  ch:use-layout(())
};

declare function c:no-view()
{
  ch:add-value("message", "test message: no-view"),
  ch:use-view(()),
  ch:use-layout("test-layout")
};

declare function c:no-view-or-layout()
{
  ch:add-value("message", <x>test message: no-view-or-layout</x>),
  ch:use-view(()),
  ch:use-layout(())
};

declare function c:different-view()
{
  ch:add-value("title", "different-view"),
  ch:add-value("message", "test message: different-view"),
  ch:use-view("tester/main"),
  ch:use-layout("test-layout")
};

declare function c:different-layout()
{
  ch:add-value("title", "different-layout"),
  ch:add-value("message", "test message: different-layout"),
  ch:use-layout("different-layout")
};

declare function c:different-view-xml-only()
{
  ch:add-value("title", "different-view"),
  ch:add-value("message", "test message: different-view"),
  ch:use-view("tester/main", "xml"),
  ch:use-layout("test-layout", "html"),
  ch:use-layout((), "xml")
};

declare function c:missing-variable()
{
  ch:add-value("title", "missing-variable"),
  ch:use-layout("test-layout")
};

declare function c:missing-view()
{
  ch:add-value("title", "missing-view"),
  ch:use-layout("test-layout")
};

declare function c:view-that-returns-the-input()
{
  ch:add-value("title", "view-that-returns-the-input"),
  ch:use-layout("test-layout")
};

declare function c:update()
{
  xdmp:document-insert("/test-insert.xml", <test/>),
  ch:use-layout(()),
  ch:use-view(()),
  ch:add-value("test", "done")
};

declare function c:update2()
{
  xdmp:document-insert("/test-insert2.xml", <test/>),
  ch:use-layout(()),
  ch:use-view(()),
  ch:add-value("test", "done")
};

declare function c:delete()
{
  xdmp:document-delete(req:get("uri")),
  ch:use-layout(()),
  ch:use-view(())
};

declare function c:layout-with-bad-import()
{
  ch:use-layout("layout-with-bad-import"),
  ch:use-view(())
};

declare function c:view-with-bad-import()
{
  ch:use-layout(()),
  ch:use-view("tester/view-with-bad-import")
};