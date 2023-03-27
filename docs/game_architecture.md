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

data Special = Plus2 { color: Color } | Plus4 | Reverse { color: Color } | PickColor
```

> These data definitions each create a new type. The types are so-called sum
> types. We have chosen the valid range of values each can take. So for
> example, only the four colors written down are valid `Color`s. "Purple" would
> not work and the game would not be valid.

Let's do game startup:

```cgelang
data GameZone = DeckZone | DiscardPile | PlayerHand { id: PlayerId }

impl Zone for GameZone

data SimpleCard = SimpleCard { color: Color, number: Number }

impl Object for SimpleCard

data Plus2Card = Plus2Card { color: Color }

impl Object for Plus2Card

data ReverseCard = ReverseCard { color: Color }

impl Object for ReverseCard

data Plus4Card = Plus4Card

impl Object for Plus4Card

data PickColorCard = PickColorCard

impl Object for PickColor Card

func setupGame() {
    let cards = []
    for color in [Red, Blue, Green, Yellow] do
        for number in 0..10 do
            cards.push(SimpleCard { color, number });
            cards.push(SimpleCard { color, number });
        end

        cards.push(Plus2Card { color });
        cards.push(Plus2Card { color });
        cards.push(ReverseCard { color });
        cards.push(ReverseCard { color });
    end

    for _ in 0..4 do
        cards.push(Plus4Card);
        cards.push(PickColorCard);
    end

    let deck = createZone(DeckZone, cards)

    deck.shuffle()

    createZone(DiscardPile, [])

    for player in getAllPlayers() do
        let startingHand = deck.takeFront(7);

        createZone(PlayerHand(player), startingHand) 
    end
}

Game.registerEvent(GameSetup, setupGame)
```

A few things happen here:

- We create cards in every combination, as well as the special cards.
- Using `func <name>(<args...>) -> <return> do ... end` we create a function
  that we can then use to create the game objects.


Now, let's start defining the beginning of the game:

```cgelang
func startGame() {
    let deck = getZone(DeckZone)
    let discardPile = getZone(DiscardPile)

    discardPile.push(deck.takeFront(1))
}

Game.registerEvent(StartGame, startGame);
```

Now, it _could_ be that the first card is a special card. In which case it will
directly have effect on the current player! Here is how we detect this case:


```cgelang
func onPlayPlus2(fromZone, toZone: DiscardPile, obj: Plus2Card) {
    let deck = getZone(Deck)

    let hand = getZone(PlayerHand { player: currentPlayer })

    hand.push(deck.takeFront(2))
}

Game.registerEvent(ObjectMoveTo { toZone: DiscardPile, object: Plus2Card, .. }, onPlayPlus2);
```


Currently players can't really do anything, this is because we have not _allowed_ them to do so!
An important aspect in CGE is that players can allow do actions you have explicitely allowed.

Here's how we define that players can play a single card from their hand:


```cgelang
data PlayCard = PlayCard { card: Object }

impl Input for PlayCard

data DrawCard = DrawCard

impl Input for DrawCard

data ActivePlayer = ActivePlayer { player: PlayerId }

func startGameWithActivePlayer() {
    let players = getAllPlayers();

    let startPlayer = players.takeRandom();

    Game.setValue(ActivePlayer { player: startPlayer });
}

Game.registerEvent(GameStart, startGameWithActivePlayer);

data Phase = PlayCardOrDraw

func allowCurrentPlayerToDrawOrPlayCard() {
    let activePlayer: ActivePlayer = Game.getValue();
    Game.allowInputFrom(activePlayer.player, DrawCard);
    Game.allowInputFrom(activePlayer.player, PlayCard);
}

Game.registerFact(PlayCardOrDraw, allowCurrentPlayerToDrawOrPlayCard)
```

It is important to note that these inputs are recalculated _everytime_ the engine 'steps forward'
