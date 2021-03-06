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

module temple.output_stream;

private {
	import std.range;
	import std.stdio;
}

// Wraps any generic output stream/sink
struct TempleOutputStream {
private:
	//void delegate(string) scope_sink;
	void delegate(string) sink;

public:
	this(T)(ref T os)
	if(isOutputRange!(T, string)) {
		this.sink = delegate(str) {
			os.put(str);
		};
	}

	this(ref File f) {
		this.sink = delegate(str) {
			f.write(str);
		};
	}

	this(void delegate(string) s) {
		this.sink = s;
	}

	this(void function(string) s) {
		this.sink = delegate(str) {
			s(str);
		};
	}

	void put(string s) {
		this.sink(s);
	}

	// for vibe.d's html escape
	void put(dchar d) {
		import std.conv;
		this.sink(d.to!string);
	}

	invariant() {
		assert(this.sink !is null);
	}
}

// newtype struct
struct TempleInputStream {
	// when called, 'into' pipes its output into OutputStream
	void delegate(ref TempleOutputStream os) into;

	invariant() {
		assert(this.into !is null);
	}
}
