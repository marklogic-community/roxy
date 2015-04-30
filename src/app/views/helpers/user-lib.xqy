(:
Copyright 2012-2015 MarkLogic Corporation

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
xquery version "1.0-ml";

module namespace uv = "http://www.marklogic.com/roxy/user-view";

import module namespace form = "http://marklogic.com/roxy/form-lib" at "/app/views/helpers/form-lib.xqy";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare option xdmp:mapping "false";

declare function uv:build-user($username, $profile-link, $login-link, $register-link, $logout-link)
{
  if ($username) then
    uv:welcome($username, $profile-link, $logout-link)
  else
    uv:build-login($login-link, $register-link)
};

declare function uv:welcome($username, $profile-link, $logout-link)
{
  <div class="user">
    <div class="welcome">Welcome,<a href="{$profile-link}">{$username}</a>&nbsp;</div>
    <a href="{$logout-link}" class="logout">logout</a>
  </div>
};

declare function uv:build-login($login-link, $register-link)
{
  <div class="user">
    <form action="{$login-link}" method="POST">
      {
        form:text-input("Username:", "username", "username"),
        form:password-input("Password:", "password", "password")
      }
      <input type="submit" value="Login"/>
    </form>
    <a href="{$register-link}">register</a>
  </div>
};
