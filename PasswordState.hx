package states;

import flixel.*;
import flixel.ui.FlxButton;
import flixel.addons.ui.FlxUIInputText;
import flixel.util.*;
import flixel.text.FlxText;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.display.FlxBackdrop;
import sys.io.File;
import haxe.crypto.Aes;
import haxe.crypto.Base64;
import haxe.crypto.Sha256;
import backend.Song;

using StringTools;

typedef Passwords = { password:String, ?song:String; }

class PasswordState extends MusicBeatState {
    var source:Array<Passwords>;
    var inputKey:FlxUIInputText;
    var failedAttempts:Int = 0;
    var maxAttempts:Int = 5;
    var secretKey:String = "SuperSecretKey123"; // Hardcoded Key (Change this)

    override function create() {
        Paths.clearStoredMemory();
        Paths.clearUnusedMemory();

        transIn = FlxTransitionableState.defaultTransIn;
        transOut = FlxTransitionableState.defaultTransOut;

        var bg = new FlxSprite().makeGraphic(1280, 720, FlxColor.WHITE);
        bg.screenCenter();
        add(bg);

        if (!sys.FileSystem.exists(Paths.json('passwords'))) {
            saveEncryptedJSON([{password: Sha256.encode("default"), song: "tutorial"}]);
        }

        source = loadEncryptedJSON();

        var check = new FlxBackdrop(Paths.image('checkered'), XY);
        check.scrollFactor.set(0.3, 0.3);
        check.velocity.set(-10, 0);
        add(check);

        var background = new FlxSprite(10, 50).loadGraphic(Paths.image("bars"));
        background.setGraphicSize(Std.int(background.width));
        background.screenCenter();
        add(background);

        inputKey = new FlxUIInputText(850, 30, 400, "Enter Password", 24, 0xFF000000, 0xFF1A6AC5);
        inputKey.screenCenter(XY);
        add(inputKey);

        var buttonKey = new FlxButton(850, 450, "Enter", onButtonKey);
        buttonKey.screenCenter(X);
        buttonKey.scale.set(3, 3);
        add(buttonKey);

        FlxG.mouse.visible = true;
        super.create();
    }

    override function update(elapsed:Float) {
        super.update(elapsed);

        if (FlxG.keys.justPressed.ESCAPE) {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            MusicBeatState.switchState(new MainMenuState());
            FlxG.mouse.visible = false;
        }

        if (FlxG.keys.justPressed.SEVEN) {
            MusicBeatState.switchState(new PasswordDebugMenuState());
        }
    }

    function onButtonKey() {
        if (failedAttempts >= maxAttempts) {
            trace("Too many failed attempts!");
            return;
        }

        var enteredPassword = Sha256.encode(inputKey.text);
        for (p in source) {
            if (enteredPassword == p.password) {
                FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
                trace("Password correct!");
                failedAttempts = 0;
                FlxG.camera.flash(FlxColor.WHITE, 0.4);
                FlxG.mouse.visible = false;

                new FlxTimer().start(0.85, function(_) {
                    loadSong(p.song);
                });
                return;
            }
        }

        failedAttempts++;
        FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
        trace("Incorrect password. Attempts: " + failedAttempts);
    }

    function loadSong(song:String) {
        var songPath = Paths.formatToSongPath(song);
        PlayState.SONG = Song.loadFromJson(songPath + "-hard", songPath);
        PlayState.isStoryMode = false;
        PlayState.seenCutscene = false;
        LoadingState.loadAndSwitchState(new PlayState());
    }

    function encryptData(data:String):String {
        return Base64.encode(new Aes(secretKey).encrypt(data));
    }

    function decryptData(data:String):String {
        return new Aes(secretKey).decrypt(Base64.decode(data));
    }

    function generateHMAC(data:String):String {
        return Sha256.encode(secretKey + data);
    }

    function saveEncryptedJSON(data:Array<Passwords>) {
        var jsonData = haxe.Json.stringify(data);
        var encryptedData = encryptData(jsonData);
        File.saveContent(Paths.json('passwords'), encryptedData);
        File.saveContent(Paths.json('passwords_hmac'), generateHMAC(encryptedData));
    }

    function loadEncryptedJSON():Array<Passwords> {
        if (!sys.FileSystem.exists(Paths.json('passwords')) || !sys.FileSystem.exists(Paths.json('passwords_hmac'))) {
            return [];
        }

        var encryptedData = File.getContent(Paths.json('passwords'));
        if (generateHMAC(encryptedData) != File.getContent(Paths.json('passwords_hmac'))) {
            trace("WARNING: passwords.json was modified!");
            return [];
        }

        return haxe.Json.parse(decryptData(encryptedData));
    }
}
class PasswordDebugMenuState extends MusicBeatState {
    var passwordInput:FlxUIInputText;
    var songInput:FlxUIInputText;
    var source:Array<Passwords>;
    var statusText:FlxText;
    var secretKey:String = "SuperSecretKey123"; // Same key as PasswordState

    override function create():Void {
        source = loadEncryptedJSON();

        passwordInput = new FlxUIInputText(850, 30, 400, "Make Password", 24);
        songInput = new FlxUIInputText(850, 80, 400, "Make Song", 24);

        var buttonKey = new FlxButton(850, 500, "Save", tryEncodeJson);
        buttonKey.screenCenter(X);
        buttonKey.scale.set(3, 3);
        add(buttonKey);

        passwordInput.screenCenter(XY);
        songInput.screenCenter(XY);
        songInput.y = passwordInput.y + 50;

        add(passwordInput);
        add(songInput);

        statusText = new FlxText(850, 620, "Enter password and song name", 20);
        statusText.screenCenter(X);
        add(statusText);

        super.create();
    }

    override function update(elapsed:Float):Void {
        if (FlxG.keys.justPressed.ESCAPE) {
            MusicBeatState.switchState(new PasswordState());
        }
        super.update(elapsed);
    }

    function tryEncodeJson():Void {
        try {
            var hashedPassword = Sha256.encode(passwordInput.text);
            var newPassword:Passwords = {password: hashedPassword, song: songInput.text};
            source.push(newPassword);
            saveEncryptedJSON(source);

            passwordInput.text = "";
            songInput.text = "";
            statusText.text = "Password and song saved!";
        } catch (error:Dynamic) {
            statusText.text = "Error saving password: " + error;
        }
    }

    function encryptData(data:String):String {
        return Base64.encode(new Aes(secretKey).encrypt(data));
    }

    function decryptData(data:String):String {
        return new Aes(secretKey).decrypt(Base64.decode(data));
    }

    function generateHMAC(data:String):String {
        return Sha256.encode(secretKey + data);
    }

    function saveEncryptedJSON(data:Array<Passwords>) {
        var jsonData = haxe.Json.stringify(data);
        var encryptedData = encryptData(jsonData);
        File.saveContent(Paths.json('passwords'), encryptedData);
        File.saveContent(Paths.json('passwords_hmac'), generateHMAC(encryptedData));
    }

    function loadEncryptedJSON():Array<Passwords> {
        if (!sys.FileSystem.exists(Paths.json('passwords')) || !sys.FileSystem.exists(Paths.json('passwords_hmac'))) {
            return [];
        }

        var encryptedData = File.getContent(Paths.json('passwords'));
        if (generateHMAC(encryptedData) != File.getContent(Paths.json('passwords_hmac'))) {
            trace("WARNING: passwords.json was modified!");
            return [];
        }

        return haxe.Json.parse(decryptData(encryptedData));
    }
}