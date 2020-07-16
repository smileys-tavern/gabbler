# Gabbler

Gabbler is a customizable Phoenix 1.5+/LiveView project for creating a Reddit-Like website. It remains true to a promise of writing no javascript (the only JS is the LiveView hook). The goal of this project is to provide a real time experience with every feature, maintain good 'bones' and create the best tooling for moderation and such that Elixir ecosystem does such a great job providing.

- ***Demo Site [https://smileys.pub](https://smileys.pub)***

# Features

- Create Rooms:
  - Public: Anyone can post / comment
  - Protected: Only allowed users can post original content, all can comment
  - Private: Only allowed users can view the room and post/comment
- Room View Modes:
  - Live: see new comment trees built in real time
  - Hot: see most upvoted content first
  - New: static view of new content
  - Chat: chat room for each post
- Post Content:
  - Markdown compatible for formatting
  - See post preview in real time as it's created
  - (Coming soon) Collaborative post editing
  - (Coming soon) upload images
  - Embed video from several sources
  - Tag your content with search helpers
- Moderation:
  - Give temporary user timeouts, ban for life or delete from near anywhere you see a post
  - Add/Remove moderators
  - View all moderated room content in real time for efficient banning
- Tag Tracking:
  - Tag tracker room allows to see posts by any tag arrive in real time
  - Tracks top 500 or so trending tags
- Authentication
  - Phoenix standard auth used for creating account
  - Subscriptions: users can subscribe to rooms to easily come back to content
  - Be notified on replies / mod requests etc

# For Developers

Gabbler tries to adhere to OTP principles and create easy to maintain a [LiveViews](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html) centric client. The basic architecture pattern:

![Gabbler Architecture](https://res.cloudinary.com/smileys/image/upload/v1594734890/gabbler_architecture_xboelg.jpg "Gabbler Architecture")

## Up and Running

The default dev setting is to have the Repo project alongside Gabbler Web. Everything else is pretty standard for a Phoenix project. To run a site configuration file is required. To deploy distillery and edeliver file are necessary (not included in repository).

```
> cd project_dir
> git clone https://github.com/smileys-tavern/gabbler
> git clone https://github.com/smileys-tavern/gabbler_data.git
> cd gabbler
> mix deps.get
> cd assets && npm install && node node_modules/webpack/bin/webpack.js --mode development
> mix ecto.migrate
> mix phx.server
```

Assuming config is setup you should be able to navigate to http://localhost:4000 now


## Update Translations/Gettext

All site text is setup for internationalization via pot files

```
> mix gettext.extract
> mix gettext.merge priv/gettext
```

## Deployment

1. Ensure .deliver/config and rel/config.exs are up to date for your env and define a build server if necessary (see distillery and eDeliver docs)

2. Make sure Git repo/fork is up to date

3. mix edeliver build release --mix-env=prod

4. mix edeliver deploy release prod --start-deploy

## Plans

Features being deliberated:

- Collaborative editing
- Image Uploads for posts
- Optional email subscriptions
