package states;

import flixel.*;
import flixel.ui.FlxButton;
import flixel.addons.ui.FlxUIInputText;
import flixel.util.*;
import flixel.text.FlxText;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.display.FlxBackdrop;
import sys.io.File;
import tjson.TJSON;
import haxe.crypto.Sha256;
import backend.Song;

using StringTools;

typedef Passwords =
{
	password:String,
	?song:String
}

/*Made and Programmed by HeroEyad, Credit me if this is used
	Otherwise I will get Saul Goodman to sue you!
	that's how you do it and you can setup a background or whatever lol!
 */
/* Honestly just make a json file in the data folder then press 7 where it can take you to the debug
	after that go ahead then make a password and what song you'll use
	MUST be on hard difficulty (might make a difficulty choice)
	make sure you have TJSON

	https://github.com/JWambaugh/TJSON

	you want to add some changes? sure do it but as long as you credit me for my original work.
	Last update guys (ok this is final now LOL.)

	Farewell.

	-- HeroEyad
*/
class PasswordState extends MusicBeatState
{
    var source:Array<Passwords>;
    var inputKey:FlxUIInputText;

    override function create()
    {
        Paths.clearStoredMemory();
        Paths.clearUnusedMemory();

        transIn = FlxTransitionableState.defaultTransIn;
        transOut = FlxTransitionableState.defaultTransOut;

        var bg:FlxSprite = new FlxSprite().makeGraphic(1280, 720, FlxColor.WHITE);
        bg.screenCenter();
        add(bg);

        if (!sys.FileSystem.exists(Paths.json('passwords')))
        {
            var hashedPassword:String = Sha256.encode("default");
            var encodedSong:String = "tutorial";
            
            var defaultPasswords:Array<Passwords> = [{password: hashedPassword, song: encodedSong}];
            var defaultJson:String = haxe.Json.stringify(defaultPasswords); 
            File.saveContent(Paths.json('passwords'), haxe.io.Bytes.ofString(defaultJson).toString());
        }
            
        var jsonData:String = File.getContent(Paths.json('passwords')).toString();
        var parsedPasswords:Array<Dynamic> = haxe.Json.parse(jsonData);
        source = [];
            

        for (p in parsedPasswords)
        {
            source.push({
                password: p.password,
                song: p.song != null ? p.song : null
            });
        }

        var check:FlxBackdrop = new FlxBackdrop(Paths.image('checkered'), XY, FlxG.random.int(0, 0), FlxG.random.int(0, 0));
        check.scrollFactor.set(0.3, 0.3);
        check.velocity.set(-10, 0);
        add(check);

        var background:FlxSprite = new FlxSprite(10, 50).loadGraphic(Paths.image("bars"));
        background.setGraphicSize(Std.int(background.width * 1));
        background.screenCenter();
        add(background);

        inputKey = new FlxUIInputText(850, 30, 400, "Enter Password", 24, 0xFF000000, 0xFF1A6AC5);
        inputKey.screenCenter(XY);
        inputKey.visible = true;
        add(inputKey);

        var buttonKey = new FlxButton(850, 450, "Enter", onButtonKey);
        buttonKey.screenCenter(X);
        buttonKey.scale.set(3, 3);
        add(buttonKey);

        FlxG.mouse.visible = true;

        super.create();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (FlxG.keys.justPressed.ESCAPE)
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            MusicBeatState.switchState(new MainMenuState());
            FlxG.mouse.visible = false;
        }

        if (FlxG.keys.justPressed.SEVEN)
        {
            MusicBeatState.switchState(new PasswordDebugMenuState());
        }
    }

    function onButtonKey()
    {
        var enteredPassword:String = inputKey.text;
        var hashedEnteredPassword:String = Sha256.encode(enteredPassword);

        for (passwords in source)
        {
            if (hashedEnteredPassword == passwords.password)
            {
                FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
                trace('Password correct (' + enteredPassword + ')');
                FlxG.camera.flash(FlxColor.WHITE, 0.4);
                FlxG.mouse.visible = false;
                new FlxTimer().start(0.85, function(tmr:FlxTimer)
                {
                    var song:String = passwords.song;
                    loadSong(song);
                });
                return;
            }
        }

        FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
        trace('Incorrect password (' + enteredPassword + ')');
    }

    function loadSong(song:String)
    {
        var songLowercase:String = Paths.formatToSongPath(song);
        PlayState.SONG = Song.loadFromJson(songLowercase + "-hard", songLowercase);

        PlayState.isStoryMode = false;
        PlayState.seenCutscene = false;
        LoadingState.loadAndSwitchState(new PlayState());
    }
}

class PasswordDebugMenuState extends MusicBeatState
{
    var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.CYAN);

    var passwordInput:FlxUIInputText;
    var songInput:FlxUIInputText;

    var source:Array<Passwords>;
    var statusText:FlxText;

    override function create():Void
    {
        source = cast TJSON.parse(File.getContent(Paths.json('passwords')));

        passwordInput = new FlxUIInputText(850, 30, 400, "Make Password", 24, 0xFF000000, 0xFFFFFFFF);
        songInput = new FlxUIInputText(850, 30, 400, "Make Song", 24, 0xFF000000, 0xFFFFFFFF);

        var buttonKey = new FlxButton(850, 500, "Save", tryEncodeJson);
        buttonKey.screenCenter(X);
        buttonKey.scale.set(3, 3);
        add(buttonKey);

        passwordInput.screenCenter(XY);
        songInput.screenCenter(XY);
        songInput.y = passwordInput.y + 50;

        passwordInput.visible = true;
        songInput.visible = true;

        add(passwordInput);
        add(songInput);

        statusText = new FlxText(850, 620, "Enter password and song name", 20);
        statusText.scrollFactor.set();
        statusText.screenCenter(X);
        add(statusText);

        super.create();
    }

    override function update(elapsed:Float):Void
    {
        if (FlxG.keys.justPressed.ESCAPE)
        {
            MusicBeatState.switchState(new PasswordState());
        }

        super.update(elapsed);
    }

    function tryEncodeJson():Void
        {
            try
            {
                var hashedPassword:String = Sha256.encode(passwordInput.text);
                var song:String = songInput.text;
                var newPassword:Passwords = {password: hashedPassword, song: song};
                source.push(newPassword);
        
                var jsonData = TJSON.encode(source);
                File.saveContent(Paths.json('passwords'), haxe.io.Bytes.ofString(jsonData).toString());
        
                passwordInput.text = "";
                songInput.text = "";
                statusText.text = "Password and song saved!";
            }
            catch (error:Dynamic)
            {
                statusText.text = "Error saving password: " + error;
            }
        }
         
}
