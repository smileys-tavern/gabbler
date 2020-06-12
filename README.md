# Gabbler

Gabbler is a customizable phoenix project for creating Reddit-Like websites without writing any javascript beyond the LiveView Hook. It's currently in experimentation phase and tidying up key features.

Demo Site - [https://smileys.pub](https://smileys.pub)

It is based on Phoenix and LiveView and provides the UI+Biz Logic to create and maintain Rooms (/r/..), sign up users and post content in a variety of ways. Most functionality and notifications are presented real time. Also provided is a basic service that tracks trends much like Twitter by keeping a sorted list of content organized by the Tags they were posted with.

Previously, Gabbler was a project called Smileys Pub, used to learn the Elixir ecosystem. This is a near complete refactor with new goals such as exploring OTP and LiveView to find good practices for (somewhat) complex sites. As new ideas are explored, the codebase will adapt with a priority on setting good standards. It will also adapt quickly as LiveView evolves toward it's official release. There is in fact zero javascript beyond the hook to run LiveView and it will stay that way for the foreseeable future (or at least ensure extra js is optional).

Feedback & suggestions quite appreciated. If you like the idea of practicing Elixir on a community based site leave a note or dive right in.

# For Developers

Gabbler is going in the direction of a generic Reddit-like phoenix site where the querying backend (and later search indexing) can be swapped out and as many aspects of the site configurable as possible. That being said it is for a technical consumer.

## Up and Running

The default dev setting is to have the Repo project alongside Gabbler Web. Everything else is pretty standard for a Phoenix project.

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

You should be able to navigate to http://localhost:4000 now


## Update Translations/Gettext

```
> mix gettext.extract
> mix gettext.merge priv/gettext
```

## Deployment

1. Ensure .deliver/config and rel/config.exs are up to date for your env and define a build server (see distillery and eDeliver docs)

2. Make sure Git repo is up to date

3. mix edeliver build release --mix-env=prod

4. mix edeliver deploy release prod --start-deploy

## Plans

Here are some project goals upcoming.

- Create best moderation tools in class

- Improve caching layer until postgres is only utilized by necessity

- Create timing based tools for posts and user notifications

- Re-implement image uploading once it's standard in LiveView based forms

- Improve posting tools (including collaborative editing)
