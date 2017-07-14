module card;

struct Card {
	enum Symbol : ubyte { Clubs, Diamonds, Hearts, Spades }
	enum Rank : ubyte { Ace, Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten, Jack, Queen, King }

	enum SymbolCount = Symbol.max + 1;
	enum RankCount = Rank.max + 1;
	enum DeckCount = SymbolCount * RankCount;

private:
	Symbol m_symbol;
	Rank m_rank;

public:
	@property auto symbol() const { return m_symbol; }
	@property auto rank() const { return m_rank; }

	auto isBlack() const { return symbol == Symbol.Clubs || symbol == Symbol.Spades; }
	auto isRed() const { return !isBlack(); }

	auto id() const { return m_symbol * RankCount + m_rank; }

	static auto FromId(uint id) @safe {
		assert(id < DeckCount);
		return Card( 
			cast(Symbol)(id / RankCount),
			cast(Rank)(id % RankCount)
		);
	}

	@safe unittest {
		auto c = Card( Symbol.Clubs, Rank.Ace );
		assert(c.symbol == Symbol.Clubs);

		assert(c.isBlack);
		assert(!c.isRed);

		assert(c.id == 0);
		assert(c == FromId(0));
	}
}
