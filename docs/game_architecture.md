# Game Architecture

As games can be versatile and dynamic, the CGE needs to be able to support
various different 'archetypes' of games.

As such, it provides little enforcement on how a game _has_ to be structured,
and tries its best to provide the needed support to easily implement games with
it.

To see such an implementation in action, let us implement a game that is
similar to Uno with the CGE.


Let's see first what CGE has to offer as basic building blocks:

- Player objects
    - These represent, of course, the players of the game
    - As they are game objects, you can store information in them
    - They are special, as they serve as 'entry points' of interaction in the
      game
- Game Objects
    - Game Objects represent everything that can be interacted with in the
      game. For example cards, but also tokens, counters, etc...
- Game Zones
    - Game Zones are where Game Objects reside
    - You usually have zones for the hand of each player, a discard pile, a
      deck (shared or for each player), etc...

With these building blocks you can then start to build your game.

For a Uno kind of game, we will go with these rules:

- There are four colors of cards, each color has cards with values going from 0
  to 9
- There are special cards:
    - Four +2 cards, one of each color, that make the next player draw two
      cards and skip their turn
    - Two +4 cards, that make the next player draw four cards, skip their turn,
      and a new color is chosen for the discard pile
    - Four reverse card, one in each color, that reverses the turn order
    - Two color pick card, where the next color of the discard pile is chosen
- Each player starts the game with 7 cards in hand. Whoever goes down to 0
  first wins.
- Each turn a player has to either:
    - Draw a card and skip their turn
    - Play a single card that is allowed under the current color


So, let's see how such a game could be implemented using CGELang:


First, let's define the kind of cards that exist
```cgelang
data Color = Red | Blue | Green | Yellow

data Number = Zero | One | Two | Three | Four | Five | Six | Seven | Eight | Nine

data Special = Plus2 Color | Plus4 | Reverse Color | PickColor

data CardKind = NormalCard Color Number | SpecialCard Special
```

The important type here is `CardKind`, which we will use to specify what kind
of card exists in the game.

> These data definitions each create a new type. The types are so-called sum
> types. We have chosen the valid range of values each can take. So for
> example, only the four colors written down are valid `Color`s. "Purple" would
> not work and the game would not be valid.

Let's do game startup:

```cgelang

zoneid data Zone = DeckZone | DiscardPile | PlayerHand PlayerId

func createCard(CardKind kind) -> GameObject do
    let obj = GameObject()
    obj.set_value(kind)

    obj
end

on GameSetup do
    let cards = []
    for color in [Red, Blue, Green, Yellow] do
        for number in 0..10 do
            let newCard = NormalCard(color, number);
            cards.push(createCard(newCard))
        end

        cards.push(createCard(SpecialCard(Plus2(color))))
        cards.push(createCard(SpecialCard(Reverse(color))))
    end

    for _ in 0..2 do
        cards.push(createCard(SpecialCard(Plus4())))
        cards.push(createCard(SpecialCard(PickColor())))
    end

    cards.shuffle()

    let deck = createZone(DeckZone, cards)

    createZone(DiscardPile, [])

    for player in getAllPlayers() do
        let startingHand = deck.takeFront(7);

        createZone(PlayerHand(player), startingHand) 
    end
end
```

A few things happen here:

- `zoneid data` is an _annotated_ type definition. It signals to the CGE that
  this data type can be used for defining game zones. __There can only be a
  single `zoneid` type.__ This is to prevent bugs while writing the game.
- `on ... do` is a _triggered_ game rule. In this case, the trigger is the game
  being set up.
- We then create cards in every combination, as well as the special cards.
- Using `func <name>(<args...>) -> <return> do ... end` we create a function
  that we can then use to create the game objects.
- `GameObject.set_value` sets a value based on the _type_ of the value. This
  means that for each unique type, a game object can hold that value. Think
  like a hashmap, except the key _is the type itself_.


Now, let's start defining the beginning of the game:

```cgelang
on GameStart do
    let deck = getZone(DeckZone)
    let discardPile = getZone(DiscardPile)

    discardPile.push(deck.takeFront(1))
end
```

- Once again we see the `on ... do` syntax, here for the `GameStart` event

Now, it _could_ be that the first card is a special card. In which case it will
directly have effect on the current player! Here is how we detect this case:


```cgelang
on ObjectMoveTo(DiscardPile) do |fromZone, toZone, object|
    let cardKind: CardKind = object.get_value()

    let deck = getZone(Deck())

    match cardKind do
        NormalCard color number do
            // We do nothing
        end
        SpecialCard special do
            let currentPlayer = getCurrentPlayer()
            let hand = getZone(PlayerHand(currentPlayer))

            match special do
                Plus2 color do
                    hand.push(deck.takeFront(2))
                end
                Plus4 do
                    hand.push(deck.takeFront(4))
                    // TODO: What to do if its first card drawn?
                end
                Reverse color do
                    // TODO: Reverse player order
                end
                PickColor do
                    // TODO: What to do if its the first card?
                end
            end
        end
    end
end
```
