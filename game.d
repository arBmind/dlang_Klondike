module game;

import card : Card;
import std.array;
bool empty(const(Card[])* a) { return a.length == 0; }
bool empty(const(Card[]) a) { return a.length == 0; }

alias Pile = Card[];
struct TableauPile {
	Pile hidden;
	Pile visible;
}

class Game {
	enum TableauPiles = 7;
	enum FoundationPiles = Card.SymbolCount;

	struct State {
		Pile discard;
		Pile stock;
		TableauPile[TableauPiles] tableaus;
		Pile[FoundationPiles] foundations;
	}

	static bool isValid(ref const State s) {
		bool[Card.DeckCount] seen = false;
		import std.range : chain;
		import std.algorithm : all, any;
		import meta.deepChain : deepChain;
		if (!deepChain(s).all!((card) {
			const id = card.id();
			if (id < 0 || id >= seen.length) return false; // wrong card
			if (seen[id]) return false; // duplicate card
			seen[id] = true;
			return true;
		})) {
			return false;
		}
		if (!seen[].all) return false;

		// tableau visible cards conform
		if (!s.tableaus[].all!((t) {
			if (!t.hidden.empty && t.visible.empty) return false; // top hidden card not revealed
			if (t.visible.empty) return true; // nothing to check
			// we do not know if this is the last hidden card revealed !
			//if (t.hidden.empty && t.visible.front.rank != Card.Rank.King) return false;
			import std.range : zip;
			return t.visible[].zip(t.visible[1..$]).all!(p => p[0].isBlack != p[1].isBlack && p[0].rank == 1 + p[1].rank);
		})) {
			return false;
		}

		// foundation cards conform
		if (!s.foundations[].all!((const ref f){
			if (f.empty) return true;
			if (f.front.rank != Card.Rank.Ace) return false;
			import std.range : zip;
			return f[].zip(f[1..$]).all!(p => p[0].symbol == p[1].symbol && 1 + p[0].rank == p[1].rank);
		})) {
			return false;
		}

		return true;
	}

	enum Discard { One }
	enum Discard discard = Discard.One;

	enum Tableau { One, Two, Three, Four, Five, Six, Seven }
	enum Tableau[] tableau = [Tableau.One, Tableau.Two, Tableau.Three, Tableau.Four, Tableau.Five, Tableau.Six, Tableau.Seven];

	enum Foundation { One, Two, Three, Four }
	enum Foundation[] foundation = [ Foundation.One, Foundation.Two, Foundation.Three, Foundation.Four ];

	//! \returns valid game state with all cards in stock
	static auto CreateOrderedStockState() {
		State state;
		import std.range : iota;
		import std.algorithm : fill, map;
		import std.array;
		state.stock ~= iota(Card.DeckCount).map!(id => Card.FromId(id))().array;
		return state;
	}

	unittest {
		auto s = CreateOrderedStockState();
		assert(s.stock.length == Card.DeckCount);
		assert(s.stock[0] == Card.FromId(0));
		assert(s.stock[$-1] == Card.FromId(Card.DeckCount-1));

		assert(isValid(s));
	}

	static auto CreateRandomizedStockState() {
		auto state = CreateOrderedStockState();
		import std.random : randomShuffle;
		state.stock[].randomShuffle;
		return state;
	}

	private static auto transferCards(ref Pile from, ref Pile to, ulong n = 1) {
		if (n < 1) return;
		to ~= from[$-n..$];
		from.length -= n;
	}

	private static auto transferCard(ref Pile from, ref Pile to) {
		to ~= from[$-1];
		from.length -= 1;
	}

	static auto CreateRandomizedState() {
		auto state = CreateRandomizedStockState;
		// fill tableaus
		import std.range : enumerate, iota;
		import std.algorithm : each;
		state.tableaus[].each!((i, ref e) {
			transferCards(state.stock, e.hidden, i);
			transferCard(state.stock, e.visible);
		});
		return state;
	}

	unittest {
		auto s = CreateRandomizedState;
		assert(s.stock.length == Card.DeckCount - 28);

		assert(s.tableaus[0].hidden.empty);
		assert(s.tableaus[0].visible.length == 1);

		assert(s.tableaus[6].hidden.length == 6);
		assert(s.tableaus[6].visible.length == 1);

		assert(isValid(s));
	}


	static auto CreateRandomized() {
		return new Game(CreateRandomizedState);
	}

	this(State state) {
		m = state;
	}

	auto isValid() const { return isValid(m); }

	unittest {
		auto game = CreateRandomized();
		assert(game.isValid());
	}

	auto isWon() const { 
		import std.algorithm : map, sum;
		return m.foundations[].map!(f => f.length).sum == Card.DeckCount;
	}

	unittest {
		auto game = CreateRandomized;
		assert(!game.isWon());
	}

	import std.typecons;
	alias OptCard = Nullable!(const(Card));

	auto topCard(Discard) const {
		if (m.discard.empty) return OptCard.init;
		return m.discard.back.nullable;
	}

	auto isStockEmpty() const { return m.stock.empty; }

	auto topCard(Foundation f) const {
		const pile = &m.foundations[f];
		if (pile.empty) return OptCard.init;
		return (*pile).back.nullable;
	}

	auto visibleCards(Tableau t) const {
		return m.tableaus[t].visible;
	}

	auto hiddenCardCount(Tableau t) const {
		return m.tableaus[t].hidden.length;
	}

	// moves (return true if successfully executed, false if invalid)
	bool drawCard() {
		if (m.stock.empty) return false; // nothing to draw

		transferCard(m.stock, m.discard);
		return true;
	}

	unittest {
		auto state = CreateOrderedStockState;
		import std.algorithm : swap;
		swap(state.stock, state.discard);
		transferCard(state.discard, state.stock);
		auto game = new Game(state);

		assert(game.isValid);
		assert(!game.isStockEmpty);

		auto success = game.drawCard;
		assert(success);

		assert(game.isStockEmpty);

		assert(!game.topCard(discard).isNull);
		assert(game.topCard(discard) == state.stock.back);

		success = game.drawCard;
		assert(!success); // out of cards
	}

	bool turnDiscardPileToStock() {
		if (!m.stock.empty) return false; // stock still filled
		if (m.discard.empty) return false; // no cards

		import std.algorithm : swap, reverse;
		swap(m.discard, m.stock);
	    reverse(m.stock[]);
		return true;
	}

	unittest {
		auto state = CreateOrderedStockState;
		import std.algorithm : swap;
		swap(state.stock, state.discard);
		auto game = new Game(state);
		assert(game.isValid);

		assert(game.isStockEmpty);

		auto success = game.turnDiscardPileToStock;
		assert(success);

		assert(!game.isStockEmpty);
		assert(game.topCard(discard).isNull);
	}

	bool moveCard(Discard, Tableau t) {
		auto fromPile = &m.discard;
		if (fromPile.empty) return false; // nothing to take
		const card = (*fromPile).back;
		auto toPile = &m.tableaus[t].visible;
		if (!canAddToTableau(card, *toPile)) return false;

		transferCard(*fromPile, *toPile);
		return true;
	}

	unittest {
		auto state = CreateOrderedStockState;
		import std.algorithm : swap;
		swap(state.stock, state.discard); // move all cards to discard
		swap(state.discard[$-2], state.discard[$-15]); // get queen with other color
		auto game = new Game(state);
		assert(game.isValid);

		auto success = game.moveCard(discard, tableau[0]);
		assert(success); // spades king

		success = game.moveCard(discard, tableau[1]);
		assert(!success); // not a king

		success = game.moveCard(discard, tableau[0]);
		assert(success); // hearts queen

		success = game.moveCard(discard, tableau[0]);
		assert(success); // spades jack

		success = game.moveCard(discard, tableau[0]);
		assert(!success); // spades ten (not matching)
	}

	bool moveCard(Discard, Foundation f) {
		auto fromPile = &m.discard;
		if (fromPile.empty) return false; // nothing to take
		const card = (*fromPile).back;
		auto toPile = &m.foundations[f];
		if (!canAddToFoundation(card, *toPile)) return false;

		transferCard(*fromPile, *toPile);
		return true;
	}

	unittest {
		auto state = CreateOrderedStockState;
		import std.algorithm : swap, reverse;
		reverse(state.stock);
		swap(state.stock, state.discard); // move all cards to discard
		swap(state.discard[$-3], state.discard[$-16]); // get 3 with other color
		auto game = new Game(state);
		assert(game.isValid);

		auto success = game.moveCard(discard, foundation[0]);
		assert(success); // spades ace

		success = game.moveCard(discard, foundation[1]);
		assert(!success); // not an ace

		success = game.moveCard(discard, foundation[0]);
		assert(success); // spades 2

		success = game.moveCard(discard, foundation[0]);
		assert(!success); // hearts 3 (not matching)
	}

	bool moveCard(Tableau from, Foundation to) {
		auto fromTableau = &m.tableaus[from];
		auto fromPile = &fromTableau.visible;
		if (fromPile.empty) return false; // nothing to take
		const card = (*fromPile).back;
		auto toPile = &m.foundations[to];
		if (!canAddToFoundation(card, *toPile)) return false;

		transferCard(*fromPile, *toPile);
		revealNextHidden(*fromTableau);
		return true;
	}

	unittest {
		auto state = CreateOrderedStockState;
		import std.algorithm : reverse, remove;
		reverse(state.stock);
		state.tableaus[0].hidden ~= state.stock[13+10]; // pick hearts 3
		state.stock = remove(state.stock, 13+10);
		transferCard(state.stock, state.tableaus[0].visible); // clubs ace
		transferCard(state.stock, state.tableaus[1].visible); // clubs 2
		auto game = new Game(state);
		assert(game.isValid);

		assert(game.hiddenCardCount(tableau[0]) == 1);

		auto success = game.moveCard(tableau[0], foundation[0]);
		assert(success); // clubs ace

		// revealed the hidden card
		assert(game.hiddenCardCount(tableau[0]) == 0);
		assert(!game.visibleCards(tableau[0]).empty);

		success = game.moveCard(tableau[0], foundation[1]);
		assert(!success); // not an ace

		success = game.moveCard(tableau[1], foundation[0]);
		assert(success); // clubs 2

		success = game.moveCard(tableau[0], foundation[0]);
		assert(!success); // hearts 3 (not matching symbol)
	}

	bool moveCards(Tableau from, Tableau to, int n = 1) {
		if (n <= 0) return false; // move at least on card
		auto fromTableau = &m.tableaus[from];
		auto fromPile = &fromTableau.visible;
		if (fromPile.length < n) return false; // not enough to take
		const card = (*fromPile)[$-n];
		auto toPile = &m.tableaus[to].visible;
		if (!canAddToTableau(card, *toPile)) return false;

		transferCards(*fromPile, *toPile, n);
		revealNextHidden(*fromTableau);
		return true;
	}

	unittest {
		auto state = CreateOrderedStockState;
		import std.algorithm : reverse, remove;
		reverse(state.stock);
		state.tableaus[0].visible ~= state.stock[13+11]; // pick hearts 2
		state.stock = remove(state.stock, 13+11);
		transferCard(state.stock, state.tableaus[0].visible); // clubs ace
		transferCard(state.stock, state.tableaus[1].visible); // clubs 2
		transferCard(state.stock, state.tableaus[2].visible); // clubs 3
		auto game = new Game(state);
		assert(game.isValid);

		auto success = game.moveCards(tableau[0], tableau[2], 2);
		assert(success); // clubs 3 - hearts 2 - clubs ace
		assert(game.visibleCards(tableau[0]).empty);
		assert(game.visibleCards(tableau[2]).length == 3);
	}

	bool moveCard(Foundation from, Foundation to) {
		auto fromPile = &m.foundations[from];
		if (fromPile.empty) return false; // nothing to take
		auto toPile = &m.foundations[to];
		if (!toPile.empty) return false; // cannot match color

		import std.algorithm : swap;
		swap(*fromPile, *toPile);
		return true;
	}

	unittest {
		auto state = CreateOrderedStockState;
		import std.algorithm : reverse;
		reverse(state.stock);

		transferCard(state.stock, state.foundations[0]); // clubs ace
		auto game = new Game(state);
		assert(game.isValid);

		auto success = game.moveCard(foundation[0], foundation[1]);
		assert(success);
		assert(game.topCard(foundation[0]).isNull);
		assert(!game.topCard(foundation[1]).isNull);
	}

	private static auto revealNextHidden(ref TableauPile t) {
		if (t.visible.empty && !t.hidden.empty) {
			transferCard(t.hidden, t.visible);
		}
	}

	private static auto canAddToTableau(Card card, const ref Pile toPile) {
		if (toPile.empty) return card.rank == Card.Rank.King;
		const lastCard = toPile.back;
		return card.isBlack != lastCard.isBlack
			&& card.rank + 1 == lastCard.rank;
	}

	private static auto canAddToFoundation(Card card, const ref Pile toPile) {
		if (toPile.empty) return card.rank == Card.Rank.Ace;
		const lastCard = toPile.back;
		return card.symbol == lastCard.symbol
			&& card.rank == lastCard.rank + 1;
	}

private:
	State m;
}
