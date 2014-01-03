Temple [![Build Status](https://travis-ci.org/dymk/temple.png?branch=master)](https://travis-ci.org/dymk/temple)
======
Surprisingly Flexable, Compile Time, Zero Overhead, Embedded Template Engine for D

About
-----
Temple is a templating engine written in D, allowing D code to be embedded and
executed in text files. The engine converts text to code at compile time, so there
is zero overhead interpreting templates at runtime, allowing for very fast template
rendering.

Temple supports passing any number of variables to templates, as well as rendering
nested templates within each other, capturing blocks of template code, and optional
fine-grain filtering of generated text (e.g for escaping generated strings).

[Vibe.d](http://vibed.org/) compatible! `OutputStream` is implemented by vibe.d's
connections, so just pass your `TCPConnection` or `HTTPServerResponse` where the
following examples pass an `AppenderOutputStream`. Temple's OutputStream will
automatically subclass the appropriate class if vibe.d is present.

Temple works with DMD 2.064 and later, and LDC on the `~merge-2.064` branch at
commit `a24b8b69` (~December 29th) or later.

Table of Contents
-----------------

 - [Usage](#usage)
 - [Template Syntax](#template-syntax)
 - [Contexts](#contexts)
 - [The `Temple` Template](#the-temple-template)
 - [The `TempleFile` Template](#the-templefile-template)
 - [Nested Templates](#nested-templates)
 - [Yielding, Layouts, and Partials](#yielding-layouts-and-partials)
 - [Capture Blocks](#capture-blocks)
 - [Helpers](#helpers-a-la-rails-view-helpers)
 - [Filter Policies](#filter-policies)
 - [Compile Time Compile Time Templates](#compile-time-compile-time-templates)
 - [Example: Simple Webpages](#example-simple-webpages)

Usage
-----
Include `temple` in your `package.json`, or all of the files in
`src/temple` in your build process.

The main API exposed by Temple consists of a few templates, and a struct:
 - `template Temple(string template_string)`
 - `template TempleFile(string file_name)`
 - `template TempleLayout(string layout_string)`
 - `template TempleLayoutFile(string layout_file)`
 - `struct TempleContext` (Jump to [Template Contexts](#template-contexts))
 - `interface OutputStream`

As well as versions that take an optional `FilterPolicy` (Jump to [Filter Policies](#filter-policies)):
 - `template Temple(FilterPolicy, string template_string)`
 - `template TempleFile(FilterPolicy, string file_name)`
 - `template TempleLayout(FilterPolicy, string layout_string)`
 - `template TempleLayoutFile(FilterPolicy, string layout_file)`


The functions generated by Temple(Layout)(File) take an `OutputStream` and an optional `TempleContext`.
TempleLayout(File)s take an `OutputStream`, a Temple(File) function pointer (the
partial rendered in the layout), and an optional `TempleContext`.

Template Syntax
---------------
The template syntax is based off of that of [eRuby](https://en.wikipedia.org/wiki/ERuby).
D statements go between `<% %>` delimers. If you wish to capture the result of a D
expression, place it between `<%= %>` delimers, and it will be converted to a `string` using std.conv's `to`.

Shorthand delimers are also supported: A line beginning with `%` is executed; a line beginning with `%=` is executed and the result is written to the output stream.

> Note that expressions within `<%= %>` and `%=` can't end with a semicolon, while statements within `<% %>` and `%` should.

####Quick Reference:

| Input | Output |
| ----- | ------ |
| `foo` | `foo`  |
| `<% "foo"; %>`  | `<no output>` |
| `<%= "foo" %>` | `foo`  |
| `%= "foo" ~ " " ~ "bar"` | `foo bar` |
| `% "foo";` | `<no output>` |

###### Foreach
```d
% foreach(i; 0..3) {
	Index: <%= i %>
% }
```
```
Index: 0
Index: 1
Index: 2
```

###### Foreach, alt
```d
% import std.conv;
<% foreach(i; 0..3) { %>
	%= "Index: " ~ to!string(i)
<% } %>
```
```
Index: 0
Index: 1
Index: 2
```

###### If/else if/else statements
```d
% auto a = "bar";
% if(a == "foo") {
	Foo!
% } else if(a == "bar") {
	Bar!
% } else {
	Baz!
% }
```
```
Bar!
```

Contexts
-----------------
The `TempleContext` type is used to pass variables to templates. The struct responds to
`opDispatch`, and returns variables in the `Variant` type. Use `Variant#get` to
convert the variable to its intended type. `TemplateContext#var(string)` is used
to retrieve variables in the context, and can be called direty with `var` in the
template:

```d
auto context = new TempleContext();
context.name = "dymk";
context.should_bort = true;
```
Passed to:
```d
<% /* Variant can be converted to a string automatically */ %>
Hello, <%= var("name") %>

<% /* Conversion of a Variant to a bool */ %>
% if(var("should_bort").get!bool) {
	Yep, gonna bort
% } else {
	Nope, not gonna bort
% }

<% /* Variants are returned by reference, and can be (re)assigned */ %>
<% var("written_in") = "D" %>
Temple is written in: <%= var("written_in") %>
}
```

Results in:
```
Hello, dymk
Yep, gonna bort
Temple is written in: D
```

Variables can also be accessed directly via the dot operator, much like
setting them.

```d
auto context = new TempleContext();
context.foo = "Foo!";
context.bar = 10;
```

```erb
<%= var.foo %>
<%= var.bar %>

<% var.baz = true; %>
<%= var.baz %>
}
```

Prints:
```
Foo!
10
true
```

For more information, see the Variant documentation on [the dlang website](http://dlang.org/phobos/std_variant.html)

The Temple Template
-------------------
`Template!"template string"` evaluates to a function that takes an `OutputStream`,
and an optional `TemplateContext`. The easiest way to render the template into a
string is to pass it to the `templeToString` function, which sets up a temporary
`AppenderOutputStream`, renders the template into that, and returns the result:

```d
import
  temple.temple,
  std.stdio,
  std.string;

void main()
{
	alias render = Temple!"foo, bar, baz";
	writeln(templeToString(&render)); // Prints "foo, bar, baz"
}
```

Here's an example passing a `TempleContext`, and manually setting up an `AppenderOuputStream`:

```d
void main()
{
	const templ_str = q{
		Hello, <%= var("name") %>
	};
	alias render = Temple!templ_str;
	auto accum = new AppenderOutputStream;

	auto context = new TempleContext();
	context.name = "dymk";

	render(accum, context);
	writeln(accum.data); // Prints "Hello, dymk"
}

```


The TempleFile Template
-----------------------
`template TempleFile(string file_name)` is the same as `Temple`, but
takes a file name to read as a template instead of the template string directly.
Temple template files end with the extension `.emd`, for "embedded d".

`template.emd`:
```d
It's <%= var("hour") %> o'clock.
```

`main.d`:
```d
import
  templ.templ,
  std.stdio;

void main() {
	alias render = TempleFile!"template.emd";

	auto context = new TempleContext();
	context.hour = 5;

	auto accum = new AppenderOutputStream;
	render(accum);

	writeln(accum.data);
}
```

```
It's 5 o'clock
```

Nested Templates
----------------

`TemplateContext#render` is used for rendering nested templates. By default,
the current context is passed to the nested template, but a different context can
be passed explicitly by calling `TemplateContext#renderWith(TemplateContext)` instead.

`a.emd`
```erb
<html>
	<body>
		<p>Hello, from the 'a' template!</p>
		<%= render!"b.emd"() %>
	<body>
</html>
```

`b.emd`
```erb
<p>And this is the 'b' template!</p>
```

Rendering `a.emd` would result in:
```html
<html>
	<body>
		<p>Hello, from the 'a' template!</p>
		<p>And this is the 'b' template!</p>
	<body>
</html>
```

Yielding, Layouts, and Partials
-------------------------------

A `TemplateContext`'s `partial` field can be assigned to a Temple function. If
`yield` is called inside of a template, then the TemplateContext's partial will be
rendered and inserted in place of the `yield` call. If no `partial` is present
in the context, then an empty string will be inserted instead.

```d
void main()
{
	alias render = Temple!"before <%= yield %> after";
	alias inner  = Temple!"between";
	auto accum = new AppenderOutputStream();
	auto context = new TempleContext();

	context.partial = &inner;

	render(accum, context);
	writeln(accum.data);
}
```
```
before between after
```

TempleLayout provides a shortcut to setting up a `TempleContext` with a partial
An optional context can be passed to layout, which will also be passed to any
nested partials.

```d
void main()
{
	alias layout = TempleLayout!`before <%= yield %> after`;
	alias partial = Temple!`between`;
	auto accum = new AppenderOutputStream();

	layout(accum, &partial);
	writeln(accum.data);
}
```
```
before between after
```

And, for completeness, `TempleLayoutFile` exists for loading a template directly
from a file.

Capture Blocks
--------------

Blocks of template can be captured into a variable, by wrapping the desired
code inside of a delegate, and passing that to `capture`. Capture blocks
can be nested. Example:

```d
<% auto outer = capture(() { %>
	Outer, first
	<% auto inner = capture(() { %>
		Inner, first
	<% }); %>
	Outer, second

	<%= inner %>
<% }); %>

<%= outer %>
```
```
Outer, first
Outer, second
	Inner, first
```

Capture blocks can also be rendered directly (although there isn't a direct reason
to do so, this is useful for implementing helpers; see the Helpers section of the README):
```d
<%= capture(() { %>
	directly printed

	<% auto a = capture(() { %>
		a, captured
	<% }); %>
	<% auto b = capture(() { %>
		b, captured
	<% }); %>

	<%= a %>
	<%= capture(() { %>
		directly printed from a nested capture
	<% }); %>
	<%= b %>

<% }); %>
```
```
directly printed
	a, captured
	directly printed from a nested capture
	b, captured
```

Planned for capture blocks: Named capture groups, a-la Rails' `content_for` helper.
Note: This can now be implemented in version v0.4.0.

Helpers (A-la Rails View Helpers)
---------------------------------

Helpers can be implemented in templates by wrapping parts of the template in a
function literal, and passing it to a user defined function that in turn calls capture.

Here's a partial implementation of Rails' `form_for` helper:

```d
<%
import std.string;
struct FormHelper
{
	string model_name;

	auto field_for(string field_name, string type="text")
	{
		if(model_name != "")
		{
			field_name = "%s[%s]".format(model_name, field_name);
		}

		return `<input type="%s" name="%s" />`.format(type, field_name);
	}

	auto submit(string value = "Submit")
	{
		return `<input type="button" value="%s" />`.format(value);
	}
}

auto form_for(
	string action,
	string name,
	void delegate(FormHelper) block)
{
	auto form_body = capture(block, FormHelper(name));
	return `
		<form action="%s" method="POST">
			%s
		</form>`.format(action, form_body);
}
%>

<%= form_for("/shorten", "", (f) { %>
	Shorten a URL:
	<%= f.field_for("url") %>
	<%= f.submit("Shorten URL") %>
<% }); %>

<%= form_for("/person", "person", (f) { %>
	Name: <%= f.field_for("name") %>
	Age: <%= f.field_for("age") %>
	DOB: <%= f.field_for("date_of_birth", "date") %>
	<%= f.submit %>
<% }); %>
```

Renders:
```html
<form action="/shorten" method="POST">
	Shorten a URL:
	<input type="text" name="url" />
	<input type="button" value="Shorten URL" />
</form>

<form action="/person" method="POST">
	Name: <input type="text" name="person[name]" />
	Age: <input type="text" name="person[age]" />
	DOB: <input type="date" name="person[date_of_birth]" />
	<input type="button" value="Submit" />
</form>
```

Filter Policies
---------------

Filter Policies are a way to filter and transform parts of the template, before
it is written to the output buffer.
A filter policy takes the form of a `struct` or `class` that defines the static
method `templeFilter`, and overloads of that. The return value of `templeFitler`
must be string, and it must take one parameter.

Example, wrapping evaluated text in quotes:

```d
struct QuoteFilter
{
	static string templeFilter(string raw)
	{
		return `"` ~ raw ~ `"`;
	}

	static string templeFilter(T)(T raw)
	{
		return templeFilter(to!string(raw));
	}
}

alias render = Temple!(QuoteFilter, q{
	Won't be quoted
	<%= "Will be quoted" %>
	<%= 10 %>
});
writeln(templeToString(&render));
```
```
Won't be quoted
"Will be quoted"
"10"
```

Filter policies can define any number of helpers, assuming they don't clash
with the methods that `TempleContext` defines. Any members on a Filter will be
be brought into the root scope of the template.

Example, implementing safe/unsafe strings for conditional escaping of input:

```d
struct SafeStringFP
{
	static struct TaintedString
	{
		string value;
		bool clean = false;
	}

	static string templeFilter(TaintedString ts)
	{
		if(ts.clean)
		{
			return ts.value;
		}
		else
		{
			return "!" ~ ts.value ~ "!";
		}
	}

	static string templeFilter(string str)
	{
		return templeFilter(TaintedString(str));
	}

	static TaintedString safe(string str)
	{
		return TaintedString(str, true);
	}
}

alias render = Temple!(SafeStringFP, q{
	foo (filtered):   <%= "mark me" %>
	foo (unfiltered): <%= safe("don't mark me") %>
});

writeln(templeToString(&render));
```
```
foo (filtered):   !mark me!
foo (unfiltered): don't mark me
```

Filter policies are propogated to nested templates:

`a.emd`:
```d
<%= safe("foo1") %>
<%= "foo2" %>
foo3
<%= render!"b.emd" %>
foo4
```

`b.emd`
```d
<%= safe("bar1") %>
<%= "bar2" %>
bar3
```

`a.emd` rendered with the `SafeStringFP`:
```
foo1
!foo2!
foo3
bar1
!bar2!
bar3
foo4
```

Compile Time Compile Time Templates
-----------------------------------

Some templates can be further evaluated into static strings at compile time if
they contain code that is, itself, CTFE compatible. This, unfortunaly, does
not include templates that take a TemplateContext, due to std.variant.Variant
being incompatible with CTFE. This restriction may be lifted in the future.

For now, templates such as this can be CTFE'd into static strings. `templeToString` is
provided as a shortcut for allocating an `AppenderOutputStream`, rendering the template with it, and
returning the appender's buffer:

```d
unittest
{
	alias render = Temple!q{
		<% if(true) { %>
			Bort
		<% } else { %>
			No bort!
		<% } %>

		<% auto a = capture(() { %>
			inside a capture block
		<% }); %>

		Before capture
		<%= a %>
		After capture
	};

	const string result = templeToString(&render);

	// Note static assert; result was computed at compile time
	static assert(isSameRender(result, `
		Bort
		Before capture
		inside a capture block
		After capture
	`));
}
```

Example: Simple Webpages
------------------------

Here's a slightly more complex example, demonstrating how to use the library
to render HTML templates inside of a common layout.

```d
void main()
{
	alias layout = TempleLayoutFile!"layout.html.emd";
	alias partial = TempleFile!"_partial.html.emd";
	auto accum = new AppenderOutputStream();

	layout(accum, &partial);
	writeln(accum.data);
}
```

`layout.html.emd`
```d
<html>
	<head>
		<title>dymk's awesome website</title>
	</head>
	<body>
		%= render!"common/_sidebar.html.emd"()
		%= yield
		%= render!"common/_footer.html.emd"()
	</body>
</html>
```

`common/_sidebar.html.emd`
```html
<ul>
	<li><a href="/">Home</a></li>
	<li><a href="/about">About</a></li>
	<li><a href="/contact">Contact</a></li>
</ul>
```

`common/_footer.html.emd`
```html
<footer>
	2013 (C) dymk .: built with Temple :.
</footer>
```

`_partial.html.emd`
```html
<section>
	TODO: Write a website
</section>
```

Output:
```html
<html>
	<head>
		<title>dymk's awesome website</title>
	</head>
	<body>
		<ul>
			<li><a href="/">Home</a></li>
			<li><a href="/about">About</a></li>
			<li><a href="/contact">Contact</a></li>
		</ul>
		<section>
			TODO: Write a website
		</section>
		<footer>
			2013 (C) dymk .: built with Temple :.
		</footer>
	</body>
</html>
```

Notes
-----
The D compiler must be told which directories are okay to import text from.
Use the `-J<folder>` compiler switch or `stringImportPaths` in Dub to include your template
directory so Temple can access them.

For more examples, take a look at`src/temple/temple.d`'s unittests; they provide
very good coverage of the library's abilities.

License
-------
*Temple* is distributed under the [Boost Software License](http://www.boost.org/LICENSE_1_0.txt).
