# BattleBox

## The OpenSource Bot Battle Platform

## SETUP

0.) Setup a postgres database according to `dev.exs`
1.) Get your credentials in github and make a `dev.secret.exs` based on `dev.secret.exs.example` 
  * Use `http://localhost:4000/auth/github/callback` as your callback url
2.) `mix deps.get && mix ecto.setup`

## TODO

### V1

#### Bots
- Edit bots
- Add pagination to index
#### Lobbies
- Edit lobbies
- Add pagination to index
- Add details to lobby details page
- bot self play allowed toggle
- user self play allowed toggle
- add in server ais
- Matchmaker queue live
- set of default lobbies with interesting terrains and bots
#### Admin
- Show number of bots/lobbies/games by user
#### Games
- Historical Games Filtered/Paginated by [user, user + bot]
- Live Games that meet the same criteria
- Better test the Game controller
- Respect the new bot follow params in game visualizer
#### Clients
- BattleBox Elixir Client
- BattleBox Python Client
- WebSocket interface
- Update protocol to give the result of each move
#### Robot Game
- limit memory usage of game servers (they're currently at 2 mbs)
- Manual GC?
- Robot game give out random player ids / color coding based on player 
- Make sure user input can't cause a game to crash (maybe changesets)
- Procedural terrain generation?
- Robot Game Settings
  - Reorgainze the code
  - Add in team spawns
#### Static Site
- Wire protocol docs
- Robot game rules docs
#### Robot Game
- More efficent game visualizer
- Make the end turns the number of turns in the game
- Remove row-min/max from terrain, because everything must be 0 indexed
- Area conquer mode
#### ELO rankings
- Provide optional ELOs to lobbies
#### Client
- remake protocol from `lobby_name` => `lobby` `bot_name` => `bot` and make `bot` optional and default to `unnamed`
- have a `use BattleBoxClient.Bot, game_type: RobotGame` macro
  - MyBot.start(lobby, opts \\ %{})
    - opts
      - credential: "TOKEN"
      - uri: "battleboxs://app.botskrieg.com:4242"
  - Choose host / protocol
    `opt passed to start/2` `$BATTLE_BOX_SERVER_URI` `Application.get_env(:battle_box_client, :server_uri)` `battleboxs://app.botskrieg.com:4242` 
  - implicitly load one of (in order) `opt passed to start/2` `$BATTLE_BOX_CREDENTIALS`, `$BATTLE_BOX_CRENDENTIAL_FILE`, `.battle_box_crendentials` `throw error with helpful info`
    - {"localhost": { "token": "asdbasdafsdfas"}, "app.botskrieg.com": {"token": "asdasdfas"}} <- creds format
    - Load the credential for the host being connected to
#### General
- Upgrade phoenix/liveview
- Handle when connection is closed on trying to send from connection server
- Add footer on all pages
- Impersonation
- Concurrent connection limiter
- Favicon
- Vendor in the font
- Bread crumb helper functions to force consistency
  - "Not found" revaamp to perserve bread crumbs
- User self admin
  - provide a way to change username
  - provide avatars that are not from github
  - Have a way to have users not from github

### Nice to Haves

- Game Engine Stats Server/Interface (# Live Games, # Most Active Lobby, # Connections)?
- Build TicTacToe/Othello/ as proof of game engine extendability
- Pass timing info to the game so it can do move timing
- Make all tests async by passing the ecto sandbox to all of the game engine

### Useful SQL

Find number of game bots for a user
```
 select users.username, count(*) from game_bots join bots on bots.id = game_bots.bot_id join users on users.id = bots.user_id group by users.id order by count desc;
```

Number of bots per user
```
select username, count(*) from bots join users on bots.user_id = users.id group by users.id order by count desc;
```

Number of lobbies per user
```
select username, count(*) from lobbies join users on lobbies.user_id = users.id group by users.id order by count desc;
```

Number of games per lobby
```
select lobbies.name, count(*) from games join lobbies on games.lobby_id = lobbies.id group by lobbies.id order by count desc;
```
