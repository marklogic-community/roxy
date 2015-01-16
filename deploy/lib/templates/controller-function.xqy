
declare function c:#function-name() as item()*
{
  ()
(:
  ch:add-value("message", "This is a test message."),
  ch:add-value("title", "This is a test page title"),
  ch:use-view((), "xml"),
  ch:use-layout((), "xml")
:)
};
