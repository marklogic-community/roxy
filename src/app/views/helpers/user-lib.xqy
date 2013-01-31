xquery version "1.0-ml";
(:
Copyright 2012-2013 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)

module namespace uv = "http://www.marklogic.com/roxy/user-view";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace c = "http://marklogic.com/roxy/config"
  at "/app/config/config.xqy";
import module namespace form = "http://marklogic.com/roxy/form-lib"
  at "/app/views/helpers/form-lib.xqy";

declare option xdmp:mapping "false";

declare variable $PROFILE-PATH := '/user/profile' ;
declare variable $REGISTER-PATH := '/user/register' ;
declare variable $LOGIN-PATH := '/user/login' ;
declare variable $LOGOUT-PATH := '/user/logout' ;
declare variable $USERNAME := xdmp:get-current-user() ;

declare function uv:is-logged-in()
as xs:boolean
{
  xdmp:has-privilege($c:LOGGED-IN-PRIVILEGE, 'execute')
};

declare function uv:build-user()
as element()+
{
  (: This privilege string must match up with deploy/ml-config.xml :)
  if (uv:is-logged-in()) then uv:welcome()
  else uv:login-link()
};

declare function uv:welcome()
as element()
{
  <div class="user">
    <div class="welcome">
      Welcome,
  {
    element a {
      attribute href { $PROFILE-PATH },
      $USERNAME }
  }

    </div>
    &#160;
    <a href="{$LOGOUT-PATH}" class="logout">(logout)</a>
  </div>
};

declare function uv:login-link()
as element()
{
  <div class="user">
    <a href="{$LOGIN-PATH}">log in</a>
    | <a href="{$REGISTER-PATH}">register</a>
  </div>
};

declare function uv:login-form()
as element()
{
  <form action="{$LOGIN-PATH}" method="POST">
  {
    form:text-input("Username:", "username", "username"),
    form:password-input("Password:", "password", "password"),
    <input type="submit" value="Log in"/>
  }
  </form>
};

(: user-lib.xqy :)
