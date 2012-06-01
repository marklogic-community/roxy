xquery version "1.0-ml";

(: Why, you might ask, do we have this module sitting here doing absolutely 
 : nothing? I'll tell you. In the rewriter, you can call 
 : xdmp:redirect-response(), but you still have to return the URI of a main 
 : module, which will actually get run. For Roxy's rewriting, we want to 
 : support redirects, but we need a module to call that doesn't do anything.
 : And here it is. :)

()
