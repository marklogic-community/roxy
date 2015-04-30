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

module namespace form = "http://marklogic.com/roxy/form-lib";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare function form:text-input(
  $label as xs:string,
  $name as xs:string,
  $class as xs:string)
{
  <div class="{$class}">
    <label>{$label}</label>
    <input type="text" name="{$name}" value=""/>
  </div>
};

declare function form:text-input(
  $label as xs:string,
  $name as xs:string,
  $class as xs:string,
  $value as xs:string)
{
  <div class="{$class}">
    <label>{$label}</label>
    <input type="text" name="{$name}" value="{$value}"/>
  </div>
};

declare function form:password-input(
  $label as xs:string,
  $name as xs:string,
  $class as xs:string)
{
  <div class="{$class}">
    <label>{$label}</label>
    <input type="password" name="{$name}" value=""/>
  </div>
};

declare function form:text-area(
  $label as xs:string,
  $name as xs:string,
  $class as xs:string)
{
  <div class="{$class}">
    <label>{$label}</label>
    <textarea name="{$name}"/>
  </div>
};

declare function form:text-area(
  $label as xs:string,
  $name as xs:string,
  $class as xs:string,
  $value as xs:string)
{
  <div class="{$class}">
    <label>{$label}</label>
    <textarea name="{$name}">{$value}</textarea>
  </div>
};

declare function form:checkbox(
  $label as xs:string,
  $name as xs:string,
  $checked as xs:boolean,
  $class as xs:string,
  $id as xs:string)
{
  <div class="{$class}">
    <label for="{$id}">{$label}</label>
    {
      element input {
        attribute type { "checkbox" },
        attribute name { $name },
        attribute id { $id },
        if ($checked) then attribute checked { "checked" } else ()
      }
    }
  </div>
};

declare function form:radio(
  $label as xs:string,
  $name as xs:string,
  $selected as xs:boolean,
  $class as xs:string,
  $id as xs:string)
{
  <div class="{$class}">
    <label for="{$id}">{$label}</label>
    {
      element input {
        attribute type { "radio" },
        attribute name { $name },
        attribute id { $id },
        if ($selected) then attribute checked { "checked" } else ()
      }
    }
  </div>
};
