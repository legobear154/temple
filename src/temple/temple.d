/**
 * Temple (C) Dylan Knutson, 2013, distributed under the:
 * Boost Software License - Version 1.0 - August 17th, 2003
 *
 * Permission is hereby granted, free of charge, to any person or organization
 * obtaining a copy of the software and accompanying documentation covered by
 * this license (the "Software") to use, reproduce, display, distribute,
 * execute, and transmit the Software, and to prepare derivative works of the
 * Software, and to permit third-parties to whom the Software is furnished to
 * do so, all subject to the following:
 *
 * The copyright notices in the Software and this entire statement, including
 * the above license grant, this restriction and the following disclaimer,
 * must be included in all copies of the Software, in whole or in part, and
 * all derivative works of the Software, unless such copies or derivative
 * works are solely in the form of machine-executable object code generated by
 * a source language processor.
 */

module temple.temple;
private import
  temple.util,
  temple.delims;

public import
	temple.temple,
	temple.temple_context,
	temple.output_stream;

import
  std.array,
  std.exception,
  std.range;

string gen_temple_func_string(string temple_str)
{

	auto function_str = "";
	auto indent_level = 0;

	void push_line(string[] stmts...)
	{
		foreach(i; 0..indent_level)
		{
			function_str ~= '\t';
		}
		foreach(stmt; stmts)
		{
			function_str ~= stmt;
		}
		function_str ~= '\n';
	}

	void indent()  { indent_level++; }
	void outdent() { indent_level--; }

	push_line(`void Temple(OutputStream __buff, TempleContext __context = null) {`);
	//push_line(`{`);
	indent();
	push_line(
	q{
		if(__context is null)
		{
			__context = new TempleContext();
		}

		import std.conv : to;
		__buff.put("");
	});

	push_line(`with(__context) {`);
	indent();

	auto safeswitch = 0;

	string prevTempl = "";

	while(!temple_str.empty) {
		if(safeswitch++ > 100) {
			assert(false, "nesting level too deep; throwing saftey switch: \n" ~ temple_str);
		}

		DelimPos!(OpenDelim)* oDelimPos = temple_str.nextDelim(OpenDelims);

		if(oDelimPos is null)
		{
			//No more delims; append the rest as a string
			push_line(`__buff.put("` ~ temple_str.escapeQuotes() ~ `");`);
			prevTempl.munchHeadOf(temple_str, temple_str.length);
		}
		else
		{
			immutable OpenDelim  oDelim = oDelimPos.delim;
			immutable CloseDelim cDelim = OpenToClose[oDelim];

			if(oDelimPos.pos == 0)
			{
				// Delim is at the start of temple_str
				if(oDelim.isShort()) {
					if(!prevTempl.validBeforeShort())
					{
						// Chars before % were invalid, assume it's part of a
						// string literal.
						push_line(`__buff.put("` ~ temple_str[0..oDelim.toString().length] ~ `");`);
						prevTempl.munchHeadOf(temple_str, oDelim.toString().length);
						continue;
					}
				}

				// If we made it this far, we've got valid open/close delims
				auto cDelimPos = temple_str.nextDelim([cDelim]);
				if(cDelimPos is null)
				{
					if(oDelim.isShort())
					{
						// don't require a short close delim at the end of the template
						temple_str ~= cDelim.toString();
						cDelimPos = enforce(temple_str.nextDelim([cDelim]));
					}
					else
					{
						assert(false, "Missing close delimer: " ~ cDelim.toString());
					}
				}

				// Made it this far, we've got the position of the close delimer.
				auto inbetween_delims = temple_str[oDelim.toString().length .. cDelimPos.pos];
				if(oDelim.isStr())
				{
					push_line(`__buff.put(to!string((` ~ inbetween_delims ~ `)));`);
					if(cDelim == CloseDelim.CloseShort)
					{
						push_line(`__buff.put("\n");`);
					}
				}
				else
				{
					push_line(inbetween_delims);
				}
				prevTempl.munchHeadOf(
					temple_str,
					cDelimPos.pos + cDelim.toString().length);
			}
			else
			{
				//Delim is somewhere in the string
				push_line(`__buff.put("` ~ temple_str[0..oDelimPos.pos] ~ `");`);
				prevTempl.munchHeadOf(temple_str, oDelimPos.pos);
			}
		}

	}

	outdent();
	push_line("}");
	outdent();
	push_line("}");

	return function_str;
}

template Temple(string template_string)
{
	#line 1 "Temple"
	mixin(gen_temple_func_string(template_string));
	#line 166 "src/temple/temple.d"
	static assert(__LINE__ == 166);
}

package alias TempleFunc = typeof(Temple!"");

template TempleFile(string template_file)
{
	pragma(msg, "Compiling ", template_file, "...");
	alias TempleFile = Temple!(import(template_file));
}

template TempleLayout(string template_string)
{
	alias layout_renderer = Temple!template_string;
	alias TempleLayout = TempleLayoutImpl!layout_renderer;
}

template TempleLayoutFile(string template_file)
{
	alias layout_renderer = TempleFile!template_file;
	alias TempleLayoutFile = TempleLayoutImpl!layout_renderer;
}

void TempleLayoutImpl(alias layout_renderer)(
	OutputStream buff,
	TempleFunc* temple_func,
	TempleContext context = null)
{
	if(context is null)
	{
		context = new TempleContext();
	}

	auto old_partial = context.partial;
	context.partial = temple_func;
	scope(exit)
	{
		context.partial = old_partial;
	}

	layout_renderer(buff, context);
}

version(unittest)
{
	private import std.string, std.stdio, std.file : readText;

	bool isSameRender(string r1, string r2)
	{
		auto ret = r1.stripWs == r2.stripWs;

		if(ret == false)
		{
			writeln("Renders differ: ");
			writeln("------------------------------");
			writeln(r1);
			writeln("------------------------------");
			writeln(r2);
			writeln("------------------------------");
		}

		return ret;
	}
}

unittest
{
	alias render = Temple!"";
	auto accum = new AppenderOutputStream();

	render(accum);
	assert(accum.data == "");
}


unittest
{
	//Test to!string of eval delimers
	alias render = Temple!(`<%= "foo" %>`);
	auto accum = new AppenderOutputStream();
	render(accum);
	assert(accum.data == "foo");
}

unittest
{
	// Test delimer parsing
	alias render = Temple!("<% if(true) { %>foo<% } %>");
	auto accum = new AppenderOutputStream();
	render(accum);
	assert(accum.data == "foo");
}
unittest
{
	//Test raw text with no delimers
	alias render = Temple!(`foo`);
	auto accum = new AppenderOutputStream();
	render(accum);
	assert(accum.data == "foo");
}

unittest
{
	//Test looping
	const templ = `<% foreach(i; 0..3) { %>foo<% } %>`;
	alias render = Temple!templ;
	auto accum = new AppenderOutputStream();
	render(accum);
	assert(accum.data == "foofoofoo");
}

unittest
{
	//Test looping
	const templ = `<% foreach(i; 0..3) { %><%= i %><% } %>`;
	alias render = Temple!templ;
	auto accum = new AppenderOutputStream();
	render(accum);
	assert(accum.data == "012");
}

unittest
{
	//Test escaping of "
	const templ = `"`;
	alias render = Temple!templ;
	auto accum = new AppenderOutputStream();
	render(accum);
	assert(accum.data == `"`);
}

unittest
{
	//Test escaping of '
	const templ = `'`;
	alias render = Temple!templ;
	auto accum = new AppenderOutputStream();
	render(accum);
	assert(accum.data == `'`);
}

unittest
{
	// Test shorthand
	const templ = `
		% if(true) {
			Hello!
		% }
	`;
	alias render = Temple!(templ);
	auto accum = new AppenderOutputStream();
	render(accum);
	assert(isSameRender(accum.data, "Hello!"));
}

unittest
{
	// Test shorthand string eval
	const templ = `
		% if(true) {
			%= "foo"
		% }
	`;
	alias render = Temple!(templ);
	auto accum = new AppenderOutputStream();
	render(accum);
	assert(isSameRender(accum.data, "foo"));
}
unittest
{
	// Test shorthand only after newline
	const templ = `foo%bar`;
	alias render = Temple!(templ);
	auto accum = new AppenderOutputStream();
	render(accum);
	assert(accum.data == "foo%bar");
}

unittest
{
	// Ditto
	const templ = `<%= "foo%bar" %>`;
	alias render = Temple!(templ);
	auto accum = new AppenderOutputStream();

	render(accum);
	assert(accum.data == "foo%bar");
}

unittest
{
	auto params = new TempleContext();
	params.foo = 123;
	params.bar = "test";

	const templ = `<%= var("foo") %> <%= var("bar") %>`;
	alias render = Temple!templ;
	auto accum = new AppenderOutputStream();

	render(accum, params);
	assert(accum.data == "123 test");
}

unittest
{
	// Loading templates from a file
	alias render = TempleFile!"test1.emd";
	auto accum = new AppenderOutputStream();
	auto compare = readText("test/test1.emd.txt");

	render(accum);
	assert(isSameRender(accum.data, compare));
}

unittest
{
	alias render = TempleFile!"test2.emd";
	auto compare = readText("test/test2.emd.txt");
	auto accum = new AppenderOutputStream();

	auto ctx = new TempleContext();
	ctx.name = "dymk";
	ctx.will_work = true;

	render(accum, ctx);
	assert(isSameRender(accum.data, compare));
}

unittest
{
	alias render = TempleFile!"test3_nester.emd";
	auto compare = readText("test/test3.emd.txt");
	auto accum = new AppenderOutputStream();

	render(accum);
	assert(isSameRender(accum.data, compare));
}

unittest
{
	alias render = TempleFile!"test4_root.emd";
	auto compare = readText("test/test4.emd.txt");
	auto accum = new AppenderOutputStream();

	auto ctx = new TempleContext();
	ctx.var1 = "this_is_var1";

	render(accum, ctx);
	assert(isSameRender(accum.data, compare));
}

unittest
{
	alias render = Temple!"before <%= yield %> after";
	alias partial = Temple!"between";
	auto accum = new AppenderOutputStream();

	auto context = new TempleContext();
	context.partial = &partial;

	render(accum, context);
	assert(isSameRender(accum.data, "before between after"));
}

unittest
{
	alias layout = TempleLayout!"before <%= yield %> after";
	alias partial = Temple!"between";
	auto accum = new AppenderOutputStream();

	layout(accum, &partial);

	assert(isSameRender(accum.data, "before between after"));
}

unittest
{
	alias layout = TempleLayoutFile!"test5_layout.emd";
	alias partial1 = TempleFile!"test5_partial1.emd";
	alias partial2 = TempleFile!"test5_partial2.emd";

	auto accum = new AppenderOutputStream();

	layout(accum, &partial1);

	assert(isSameRender(accum.data, readText("test/test5_partial1.emd.txt")));

	accum.clear;
	layout(accum, &partial2);
	assert(isSameRender(accum.data, readText("test/test5_partial2.emd.txt")));
}

// Layouts and contexts
unittest
{
	alias layout = TempleLayoutFile!"test6_layout.emd";
	alias partial = TempleFile!"test6_partial.emd";
	auto accum = new AppenderOutputStream();
	auto context = new TempleContext();

	context.name = "dymk";
	context.uni = "UCSD";
	context.age = 18;

	layout(accum, &partial, context);
	assert(isSameRender(accum.data, readText("test/test6_partial.emd.txt")));
}

// opDispatch variable getting
unittest
{
	alias render = Temple!"<%= var.foo %>";
	auto accum = new AppenderOutputStream();
	auto context = new TempleContext();

	context.foo = "Hello, world";

	render(accum, context);
	assert(accum.data == "Hello, world");
}