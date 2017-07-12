module meta.deepChain;

import std.typecons;
import std.traits;
import std.algorithm;
import std.range;
import meta.numberSeq : NumberSeq;

auto deepChain(T)(T a) {
	import std.traits;
	import std.range : chain;
	import std.conv : to;
	import std.array;
	import std.meta;

	template fieldTypes(string b, string[] f, ulong i, N...)
	{
		enum string fieldTypes = buildArgs!(b~"."~f[i], N[i]);
	}

	template indexTypes(string b, T, ulong i)
	{
		enum string indexTypes = buildArgs!(b~"["~i.to!string~"]", T);
	}

	string buildArgs(string b, N)() {
		static if (isStaticArray!N) {
			//pragma(msg, "array:", N);
			alias indices = NumberSeq!(N.length);
			//pragma(msg,indices);
			enum x = [staticMap!(ApplyLeft!(indexTypes, b, ForeachType!N), indices)];
			//pragma(msg,x);
			return x.join(',');
		}
		else static if (is(N == struct)) {
			//pragma(msg,"struct:");
			alias indices = NumberSeq!(Fields!N.length);
			//pragma(msg,indices);
			enum names = [FieldNameTuple!N];
			//pragma(msg,names);
			alias types = Fields!N;
			//pragma(msg,types);
			enum access = [staticMap!(ApplyRight!(ApplyLeft!(fieldTypes, b, names), types), indices)];
			//pragma(msg,access);
			return access.join(',');
		}
		else {
			return b;
		}
	}
	pragma(msg,"chain("~buildArgs!("a",T)~")");
	return mixin("chain("~buildArgs!("a",T)~")");
}

unittest {
	struct State {
		int[] stack;
		int[][3] back;
	}

	enum State s = { [1,2], [[3,4], [5,6], []] };
	enum s2 = deepChain(s).sum;
	assert(s2 == 21);
}
