module meta.numberSeq;

template NumberSeq(ulong L) {
	import std.meta : AliasSeq;
	string gen() {
		import std.algorithm : map;
		import std.range : iota, join;
		import std.conv : to;
		return "AliasSeq!("~iota(L).map!(n => n.to!string).join(',')~")";
	}
	alias NumberSeq = AliasSeq!(mixin(gen()));
}

unittest {
	alias seq = NumberSeq!23;
	import std.algorithm : sum;
	pragma(msg, seq);
	assert([seq].sum == 253);
}
