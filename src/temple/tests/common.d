module temple.tests.common;

version(unittest):
public import std.stdio, std.file : readText;
public import
	temple.util,
	temple.temple,
	temple.output_stream;

bool isSameRender(in TempleRenderer t, TempleContext tc, string r2) {
	return isSameRender(t, r2, tc);
}
bool isSameRender(in TempleRenderer t, string r2, TempleContext tc = null) {
	return isSameRender(t.toString(tc), r2);
}
bool isSameRender(string r1, string r2)
{
	auto ret = r1.stripWs == r2.stripWs;

	if(ret == false)
	{
		writeln("Renders differ: ");
		writeln("Got: -------------------------");
		writeln(r1);
		writeln("Expected: --------------------");
		writeln(r2);
		writeln("------------------------------");
	}

	return ret;
}

string templeToString(TempleRenderer function() getr, TempleContext tc = null) {
	return getr().toString(tc);
}

unittest
{
	auto render = Temple!"";
	assert(render.toString() == "");
}

unittest
{
	//Test to!string of eval delimers
	alias render = Temple!`<%= "foo" %>`;
	assert(templeToString(&render) == "foo");
}

unittest
{
	// Test delimer parsing
	alias render = Temple!("<% if(true) { %>foo<% } %>");
	assert(templeToString(&render) == "foo");
}
unittest
{
	//Test raw text with no delimers
	alias render = Temple!(`foo`);
	assert(templeToString(&render) == "foo");
}

unittest
{
	//Test looping
	const templ = `<% foreach(i; 0..3) { %>foo<% } %>`;
	alias render = Temple!templ;
	assert(templeToString(&render) == "foofoofoo");
}

unittest
{
	//Test looping
	const templ = `<% foreach(i; 0..3) { %><%= i %><% } %>`;
	alias render = Temple!templ;
	assert(templeToString(&render) == "012");
}

unittest
{
	//Test escaping of "
	const templ = `"`;
	alias render = Temple!templ;
	assert(templeToString(&render) == `"`);
}

unittest
{
	//Test escaping of '
	const templ = `'`;
	alias render = Temple!templ;
	assert(templeToString(&render) == `'`);
}

unittest
{
	alias render = Temple!`"%"`;
	assert(templeToString(&render) == `"%"`);
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
	assert(isSameRender(templeToString(&render), "Hello!"));
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
	//static assert(false);
	assert(isSameRender(templeToString(&render), "foo"));
}
unittest
{
	// Test shorthand only after newline
	const templ = `foo%bar`;
	alias render = Temple!(templ);
	assert(templeToString(&render) == "foo%bar");
}

unittest
{
	// Ditto
	alias render = Temple!`<%= "foo%bar" %>`;
	assert(templeToString(&render) == "foo%bar");
}

unittest
{
	auto context = new TempleContext();
	context.foo = 123;
	context.bar = "test";

	alias render = Temple!`<%= var("foo") %> <%= var("bar") %>`;
	assert(templeToString(&render, context) == "123 test");
}

unittest
{
	// Loading templates from a file
	alias render = TempleFile!"test1.emd";
	auto compare = readText("test/test1.emd.txt");
	assert(isSameRender(templeToString(&render), compare));
}

unittest
{
	alias render = TempleFile!"test2.emd";
	auto compare = readText("test/test2.emd.txt");

	auto ctx = new TempleContext();
	ctx.name = "dymk";
	ctx.will_work = true;

	assert(isSameRender(templeToString(&render, ctx), compare));
}

unittest
{
	alias render = TempleFile!"test3_nester.emd";
	auto compare = readText("test/test3.emd.txt");
	assert(isSameRender(templeToString(&render), compare));
}

unittest
{
	alias render = TempleFile!"test4_root.emd";
	auto compare = readText("test/test4.emd.txt");

	auto ctx = new TempleContext();
	ctx.var1 = "this_is_var1";

	assert(isSameRender(templeToString(&render, ctx), compare));
}

unittest
{
	auto parent = Temple!"before <%= yield %> after";
	auto partial = Temple!"between";

	assert(isSameRender(parent.layout(&partial), "before between after"));
}

unittest
{
	auto parent = Temple!"before <%= yield %> after";
	auto partial = Temple!"between";

	assert(isSameRender(parent.layout(&partial), "before between after"));
}

unittest
{
	auto parent   = TempleFile!"test5_layout.emd";
	auto partial1 = TempleFile!"test5_partial1.emd";
	auto partial2 = TempleFile!"test5_partial2.emd";

	auto p1 = parent.layout(&partial1);
	auto p2 = parent.layout(&partial2);

	assert(isSameRender(p1, readText("test/test5_partial1.emd.txt")));
	assert(isSameRender(p2, readText("test/test5_partial2.emd.txt")));
}

// Layouts and contexts
unittest
{
	auto parent  = TempleFile!"test6_layout.emd";
	auto partial = TempleFile!"test6_partial.emd";

	auto context = new TempleContext();
	context.name = "dymk";
	context.uni = "UCSD";
	context.age = 19;

	assert(isSameRender(parent.layout(&partial), context, readText("test/test6_partial.emd.txt")));
}

// opDispatch variable getting
unittest
{
	auto render = Temple!"<%= var.foo %>";

	auto context = new TempleContext();
	context.foo = "Hello, world";

	assert(isSameRender(render, context, "Hello, world"));
}

unittest
{
	// 22 Nov, 2014: Disabled this bit, because DMD now ICEs when
	// evaluating the erronious template (but not before spitting out
	// a lot of errors). This will have to do for finding out that a templtae
	// has a lot of errors in it.
	// Uncomment to view the line numbers inserted into the template
	//auto render = TempleFile!"test7_error.emd";
	 //TODO:
	//assert(!__traits(compiles, {
	//	auto t = TempleFile!"test7_error.emd";
	//}));
}

unittest
{
	import temple.func_string_gen;
	// Test returning early from templates
	//auto str = `
	alias render = Temple!`
		one
		% auto blah = true;
		% if(blah) {
			two
			%	return;
		% }
		three
	`;

	//writeln(__temple_gen_temple_func_string(str, "Inline"));
	assert(isSameRender(templeToString(&render),
		`one
		two`));
}
