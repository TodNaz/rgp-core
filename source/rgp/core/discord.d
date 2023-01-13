module rgp.core.discord;

version (feature_discord)  : import discord_rpc;
import discord_register;

extern (C) nothrow @nogc
{
    void onReady(const(DiscordUser)* request)
    {

    }

    void onDissconnect(int errorCode, const(char)* message)
    {

    }

    void onError(int errorCode, const(char)* message)
    {

    }
}

void initDiscord() @trusted
{
    DiscordEventHandlers handlers;
    handlers.ready = &onReady;
    handlers.disconnected = &onDissconnect;
    handlers.errored = &onError;

    Discord_Initialize("951884842382020648", &handlers, 1, null);
    Discord_Register("951884842382020648", "RGP");

    DiscordRichPresence rich = DiscordRichPresence("Idle in menu", null, 0, 0,
            "rgp", "RGP", null, null);
    Discord_UpdatePresence(&rich);
}

void updatePresence(string state, string details, string icon = "rgp", string largeText = "RGP") @trusted
{
    import std.string : toStringz;

    DiscordRichPresence rich = DiscordRichPresence(state.toStringz,
            details.toStringz, 0, 0, icon.toStringz, largeText.toStringz, null, null);
    Discord_UpdatePresence(&rich);
}
